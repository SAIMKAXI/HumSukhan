import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../models/models.dart';
import 'audio_model_manager.dart';
import 'sherpa_audio_tagger.dart';

/// Environmental sound detection service using sherpa-ONNX CED-Tiny INT8.
///
/// Optimised for minimum battery and RAM:
///   • RMS gate computed on raw Int16 PCM (no Float32 conversion for gating)
///   • Reusable Float32 window buffer (no per-inference allocation)
///   • Zero-copy Int16List.view for audio chunks from the record plugin
///   • Single CPU inference thread; model loaded only while monitoring
///   • All native resources freed immediately when monitoring stops
///
/// Architecture:
///   Microphone → 16 kHz mono PCM16 → circular Int16 buffer → RMS gate →
///   3 s window / 1 s hop → SherpaAudioTagger → label mapping →
///   temporal confirmation → cooldown → SoundEvent
class SoundDetectionService {
  SoundDetectionService._();
  static SoundDetectionService? _instance;
  static SoundDetectionService get instance =>
      _instance ?? SoundDetectionService._();

  // ── State ──────────────────────────────────────────────────────────────
  bool _initialized = false;
  bool _monitoring = false;
  AudioRecorder? _audioRecorder;
  StreamSubscription<Uint8List>? _audioSubscription;

  // ── Callback ───────────────────────────────────────────────────────────
  Function(SoundEvent)? onSoundDetected;

  // ── Delegated tagger ───────────────────────────────────────────────────
  final SherpaAudioTagger _tagger = SherpaAudioTagger();

  // ── Audio parameters ───────────────────────────────────────────────────
  static const int _sampleRate = 16000;
  static const int _windowSamples = 3 * _sampleRate; // 48 000 = 3 s
  static const int _hopSamples = 1 * _sampleRate; // 16 000 = 1 s hop

  // ── Circular Int16 PCM buffer (reused across windows) ──────────────────
  final Int16List _pcmBuffer = Int16List(_windowSamples);
  int _pcmWritePos = 0;
  int _totalSamplesCollected = 0;

  // ── Reusable Float32 window buffer (avoids 192 KB alloc per inference) ─
  final Float32List _windowFloat = Float32List(_windowSamples);

  // ── RMS energy gate ────────────────────────────────────────────────────
  // Computed on Int16 PCM directly — no Float32 conversion needed.
  // Threshold: RMS of raw PCM16 samples. 200 corresponds to ~0.006 full-scale.
  static const double _rmsGateThreshold = 200.0;

  // ── Cooldown (per-event, not global) ───────────────────────────────────
  static const Duration _cooldownDuration = Duration(seconds: 30);
  final Map<String, DateTime> _lastDetectionTime = {};

  // ── Temporal confirmation ──────────────────────────────────────────────
  static const Duration _temporalWindow = Duration(seconds: 8);
  final Map<String, List<DateTime>> _temporalBuffer = {};

  // ── Label → Event mapping (AudioSet labels → HumSukhan events) ─────────
  static const Map<String, List<String>> _labelMapping = {
    'Fire Alarm': [
      'smoke detector, smoke alarm',
      'fire alarm',
    ],
    'Siren': [
      'siren',
      'police car (siren)',
      'ambulance (siren)',
      'emergency vehicle',
    ],
    'Doorbell': [
      'doorbell',
      'chime',
      'bell',
    ],
    'Knock': [
      'knock',
      'tap',
    ],
    'Phone': [
      'telephone',
      'telephone bell ringing',
      'ringtone',
      'cell phone',
      'mobile phone',
    ],
    'Baby Cry': [
      'crying, sobbing',
      'baby cry, infant cry',
    ],
    'Alarm Clock': [
      'alarm clock',
      'alarm',
      'buzzer',
      'clock',
    ],
    'Vehicle Horn': [
      'car horn, honking',
      'vehicle horn, car horn, honking',
    ],
    'Glass Break': [
      'glass',
    ],
    'Dog Bark': [
      'dog',
      'bark',
    ],
  };

  static const Set<String> _criticalEvents = {'Fire Alarm', 'Siren'};
  static const double _criticalThreshold = 0.70;
  static const double _nonCriticalThreshold = 0.55;

  // ── Public getters ─────────────────────────────────────────────────────
  bool get isInitialized => _initialized;
  bool get isMonitoring => _monitoring;
  bool get isModelReady => _tagger.isInitialized;
  int get labelCount => _tagger.labels.length;
  List<String> get modelLabels => _tagger.labels;
  static List<String> get supportedEvents => _labelMapping.keys.toList();

  // ══════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ══════════════════════════════════════════════════════════════════════

  /// Initialize: request mic permission, ensure model is downloaded.
  /// Does NOT load the ONNX model — that happens in [startMonitoring].
  Future<bool> initialize() async {
    if (_initialized) return _tagger.isInitialized;

    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('SoundDetection: Microphone permission denied');
        _initialized = true;
        return false;
      }

      _audioRecorder = AudioRecorder();

      // Ensure the CED-Tiny model is downloaded (no RAM cost — just files)
      final mm = AudioModelManager.instance;
      if (!await mm.ensureModelAvailable()) {
        debugPrint('SoundDetection: Model not available after download attempt');
        _initialized = true;
        return false;
      }

      _initialized = true;
      debugPrint('SoundDetection: Initialized (model on disk, tagger deferred)');
      return true;
    } catch (e) {
      debugPrint('SoundDetection init error: $e');
      _initialized = true;
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // MONITORING START / STOP
  // ══════════════════════════════════════════════════════════════════════

  /// Start monitoring. Loads the ONNX model into RAM and opens the mic.
  Future<void> startMonitoring() async {
    if (!_initialized) await initialize();
    if (_monitoring) return;
    if (_audioRecorder == null) return;

    try {
      if (!await _audioRecorder!.hasPermission()) {
        debugPrint('SoundDetection: No recorder permission');
        return;
      }

      // Load ONNX model into memory (only while monitoring is active)
      if (!await _tagger.initialize()) {
        debugPrint('SoundDetection: Tagger init failed');
        return;
      }

      // Start 16 kHz mono PCM16 recording
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      );
      final stream = await _audioRecorder!.startStream(config);

      // Reset buffers (reuse existing allocations)
      _pcmWritePos = 0;
      _totalSamplesCollected = 0;
      _clearTemporalBuffer();

      _audioSubscription = stream.listen(
        _onAudioData,
        onDone: () => debugPrint('SoundDetection: Audio stream ended'),
        onError: (e) => debugPrint('SoundDetection: Audio stream error: $e'),
      );

      _monitoring = true;
      debugPrint('SoundDetection: Monitoring started');
    } catch (e) {
      debugPrint('SoundDetection start error: $e');
    }
  }

  /// Stop monitoring. Releases mic stream AND frees the ONNX model from RAM.
  void stopMonitoring() {
    _monitoring = false;

    // Cancel and null the audio subscription
    _audioSubscription?.cancel();
    _audioSubscription = null;

    // Stop the hardware recorder
    try {
      _audioRecorder?.stop();
    } catch (_) {}

    // Dispose the recorder to fully release native audio resources
    try {
      _audioRecorder?.dispose();
    } catch (_) {}
    _audioRecorder = null;

    // Free the ONNX model + native stream from RAM
    _tagger.release();

    // Reset circular buffer state (buffer memory is reused, not reallocated)
    _pcmWritePos = 0;
    _totalSamplesCollected = 0;
    debugPrint('SoundDetection: Monitoring stopped (mic + model released)');
  }

  // ══════════════════════════════════════════════════════════════════════
  // AUDIO PROCESSING  (hot path — allocations minimised)
  // ══════════════════════════════════════════════════════════════════════

  /// Called by the record plugin with raw PCM16 bytes (Uint8List).
  void _onAudioData(Uint8List data) {
    if (!_monitoring || data.isEmpty) return;

    // Zero-copy view: interpret bytes as Int16 samples
    final int16View = Int16List.view(data.buffer);

    for (int i = 0; i < int16View.length; i++) {
      _pcmBuffer[_pcmWritePos] = int16View[i];
      _pcmWritePos = (_pcmWritePos + 1) % _windowSamples;
      _totalSamplesCollected++;
    }

    // After the initial 3 s fill, trigger inference every _hopSamples
    if (_totalSamplesCollected >= _windowSamples &&
        (_totalSamplesCollected - _windowSamples) % _hopSamples == 0) {
      _processWindow();
    }
  }

  /// Extract 3-second window, apply RMS gate, run ONNX inference.
  void _processWindow() {
    if (!_tagger.isInitialized) return;

    // ── RMS gate on raw Int16 PCM (no Float32 conversion) ────────────
    // This avoids converting the entire window to Float32 just to
    // discover the audio is silent.  The Float32 conversion only
    // happens below if the gate passes.
    int sumSq = 0;
    final int start =
        (_pcmWritePos - _windowSamples + _windowSamples) % _windowSamples;
    for (int i = 0; i < _windowSamples; i++) {
      final s = _pcmBuffer[(start + i) % _windowSamples];
      sumSq += s * s;
    }
    // Integer RMS to avoid floating-point division; compare against threshold²
    final int rmsSq = sumSq ~/ _windowSamples;
    if (rmsSq < _rmsGateThreshold * _rmsGateThreshold) {
      return; // silent → skip ONNX inference entirely
    }

    // ── Convert Int16 → Float32 into the reusable buffer ─────────────
    for (int i = 0; i < _windowSamples; i++) {
      _windowFloat[i] = _pcmBuffer[(start + i) % _windowSamples] / 32768.0;
    }

    // ── Delegate to SherpaAudioTagger ────────────────────────────────
    final results = _tagger.classify(samples: _windowFloat, topK: 10);
    for (final r in results) {
      _processDetection(r.label, r.probability);
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // DETECTION PIPELINE
  // ══════════════════════════════════════════════════════════════════════

  void _processDetection(String label, double confidence) {
    if (!_monitoring) return;

    final eventType = _mapLabelToEvent(label);
    if (eventType == null) return;

    final threshold = _criticalEvents.contains(eventType)
        ? _criticalThreshold
        : _nonCriticalThreshold;
    if (confidence < threshold) return;

    final now = DateTime.now();
    final last = _lastDetectionTime[eventType];
    if (last != null && now.difference(last) < _cooldownDuration) return;

    if (!_criticalEvents.contains(eventType) &&
        !_passesTemporalConfirmation(eventType, now)) {
      return;
    }

    _emitEvent(eventType, confidence);
  }

  bool _passesTemporalConfirmation(String eventType, DateTime now) {
    _temporalBuffer[eventType] ??= [];
    _temporalBuffer[eventType]!
        .removeWhere((t) => now.difference(t) > _temporalWindow);
    _temporalBuffer[eventType]!.add(now);
    return _temporalBuffer[eventType]!.length >= 2;
  }

  void _clearTemporalBuffer() {
    for (final list in _temporalBuffer.values) {
      list.clear();
    }
  }

  void _emitEvent(String eventType, double confidence) {
    final severity = _getSeverity(eventType);
    final event = SoundEvent(
      type: eventType,
      confidence: confidence,
      severity: severity,
    );
    _lastDetectionTime[eventType] = DateTime.now();
    debugPrint('SoundDetection: $eventType ($confidence) [$severity]');
    onSoundDetected?.call(event);
  }

  // ══════════════════════════════════════════════════════════════════════
  // LABEL MAPPING
  // ══════════════════════════════════════════════════════════════════════

  String? _mapLabelToEvent(String label) {
    final lower = label.toLowerCase();
    for (final entry in _labelMapping.entries) {
      for (final pattern in entry.value) {
        if (lower.contains(pattern.toLowerCase())) return entry.key;
      }
    }
    return null;
  }

  String _getSeverity(String eventType) {
    switch (eventType) {
      case 'Fire Alarm':
      case 'Siren':
      case 'Glass Break':
        return 'critical';
      case 'Doorbell':
      case 'Knock':
      case 'Phone':
      case 'Baby Cry':
        return 'warning';
      default:
        return 'info';
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // EXTERNAL CLASSIFICATION API
  // ══════════════════════════════════════════════════════════════════════

  bool processClassification(String label, double confidence) {
    if (!_monitoring) return false;

    final eventType = _mapLabelToEvent(label);
    if (eventType == null) return false;

    final threshold = _criticalEvents.contains(eventType)
        ? _criticalThreshold
        : _nonCriticalThreshold;
    if (confidence < threshold) return false;

    final now = DateTime.now();
    final last = _lastDetectionTime[eventType];
    if (last != null && now.difference(last) < _cooldownDuration) return false;

    if (!_criticalEvents.contains(eventType) &&
        !_passesTemporalConfirmation(eventType, now)) {
      return false;
    }

    _emitEvent(eventType, confidence);
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════
  // CLEANUP
  // ══════════════════════════════════════════════════════════════════════

  void dispose() {
    stopMonitoring();
    _lastDetectionTime.clear();
    _clearTemporalBuffer();
  }
}
