import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../models/models.dart';
import 'audio_model_manager.dart';

/// Real environmental sound detection service using sherpa-ONNX CED-mini INT8.
///
/// Architecture:
///   Microphone → 16kHz mono PCM16 → audio buffer → RMS gate →
///   3s window / 1s hop → sherpa-ONNX audio tagger → label mapping →
///   temporal confirmation → cooldown → SoundEvent
///
/// Battery optimization:
///   - RMS energy gate skips silent windows (no neural inference on silence)
///   - CPU provider with 1 thread
///   - Model loaded once per monitoring session, released when stopped
///   - Reused buffers to minimize allocations
///
/// Supported sound categories:
///   Fire Alarm, Siren, Doorbell, Knock, Phone, Baby Cry,
///   Alarm Clock, Vehicle Horn, Glass Break, Dog Bark
class SoundDetectionService {
  static SoundDetectionService? _instance;
  static SoundDetectionService get instance =>
      _instance ?? SoundDetectionService._();
  SoundDetectionService._();

  // ── State ──────────────────────────────────────────────────────────────
  bool _initialized = false;
  bool _monitoring = false;
  bool _modelLoaded = false;
  AudioRecorder? _audioRecorder;
  StreamSubscription<List<int>>? _audioSubscription;

  // ── Callback ───────────────────────────────────────────────────────────
  Function(SoundEvent)? onSoundDetected;

  // ── sherpa-ONNX objects ────────────────────────────────────────────────
  sherpa_onnx.AudioTagging? _tagger;
  sherpa_onnx.OfflineStream? _taggerStream;

  // ── Audio parameters ───────────────────────────────────────────────────
  static const int _sampleRate = 16000;
  static const int _windowSamples = 3 * _sampleRate; // 3 seconds
  static const int _hopSamples = 1 * _sampleRate; // 1 second hop

  // ── Circular audio buffer ──────────────────────────────────────────────
  // Holds up to _windowSamples of PCM16 samples (reused across windows)
  final Int16List _pcmBuffer = Int16List(_windowSamples);
  int _pcmWritePos = 0;
  int _totalSamplesCollected = 0;

  // ── RMS energy gate ────────────────────────────────────────────────────
  // Threshold below which we skip inference (quiet audio)
  static const double _rmsGateThreshold = 200.0;

  // ── Cooldown ───────────────────────────────────────────────────────────
  static const Duration _cooldownDuration = Duration(seconds: 30);
  final Map<String, DateTime> _lastDetectionTime = {};

  // ── Temporal confirmation ──────────────────────────────────────────────
  // Non-critical events require 2 compatible detections within 8 seconds
  static const Duration _temporalWindow = Duration(seconds: 8);
  final Map<String, List<DateTime>> _temporalBuffer = {};

  // ── Label → Event mapping ──────────────────────────────────────────────
  // Maps CED-mini AudioSet labels to HumSukhan event types.
  // Keys are lowercase for case-insensitive matching.
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

  // Critical events use higher confidence threshold and may fire on single detection
  static const Set<String> _criticalEvents = {'Fire Alarm', 'Siren'};
  static const double _criticalThreshold = 0.70;
  static const double _nonCriticalThreshold = 0.55;

  // ── Public state ───────────────────────────────────────────────────────
  bool get isInitialized => _initialized;
  bool get isMonitoring => _monitoring;
  bool get isModelReady => _modelLoaded;

  // ── Model labels loaded from CSV ───────────────────────────────────────
  List<String> _modelLabels = [];

  // ══════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ══════════════════════════════════════════════════════════════════════

  /// Initialize the service: request mic permission, ensure model is available.
  Future<bool> initialize() async {
    if (_initialized) return _modelLoaded;

    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('SoundDetection: Microphone permission denied');
        _initialized = true;
        return false;
      }

      // Initialize sherpa-onnx bindings
      sherpa_onnx.initBindings();

      // Initialize audio recorder
      _audioRecorder = AudioRecorder();

      // Ensure the CED-mini model is downloaded
      final modelManager = AudioModelManager.instance;
      final modelReady = await modelManager.ensureModelAvailable();

      if (!modelReady) {
        debugPrint('SoundDetection: Model not available after download attempt');
        _initialized = true;
        return false;
      }

      // Load labels from CSV
      _modelLabels = await _loadLabels(modelManager.labelsPath!);

      _initialized = true;
      debugPrint(
          'SoundDetection: Initialized. Model ready. ${_modelLabels.length} labels loaded.');
      return true;
    } catch (e) {
      debugPrint('SoundDetection init error: $e');
      _initialized = true;
      return false;
    }
  }

  /// Load label names from the class_labels_indices.csv file.
  /// CSV format: index,name (first line may be header)
  Future<List<String>> _loadLabels(String csvPath) async {
    try {
      final file = File(csvPath);
      final content = await file.readAsString();
      final lines = content.split('\n');
      final labels = <String>[];

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        // Skip header line if present
        if (trimmed.startsWith('index')) continue;

        final parts = trimmed.split(',');
        if (parts.length >= 2) {
          // The name is everything after the first comma (handles commas in names)
          final name = parts.sublist(1).join(',').trim();
          if (name.isNotEmpty) {
            labels.add(name);
          }
        }
      }

      debugPrint('SoundDetection: Loaded ${labels.length} labels from CSV');
      return labels;
    } catch (e) {
      debugPrint('SoundDetection: Error loading labels: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // MONITORING START / STOP
  // ══════════════════════════════════════════════════════════════════════

  /// Start monitoring for environmental sounds.
  Future<void> startMonitoring() async {
    if (!_initialized) await initialize();
    if (_monitoring) return;
    if (_audioRecorder == null) return;

    try {
      // Check recorder permission
      if (!await _audioRecorder!.hasPermission()) {
        debugPrint('SoundDetection: No recorder permission');
        return;
      }

      // Initialize the sherpa-ONNX audio tagger (CED-mini INT8)
      if (!await _initializeTagger()) {
        debugPrint('SoundDetection: Failed to initialize tagger');
        return;
      }

      // Start recording audio stream at 16kHz mono PCM16
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      );

      final stream = await _audioRecorder!.startStream(config);

      // Reset buffer state
      _pcmWritePos = 0;
      _totalSamplesCollected = 0;
      _clearTemporalBuffer();

      _audioSubscription = stream.listen(
        (data) {
          if (!_monitoring) return;
          _onAudioData(data);
        },
        onDone: () {
          debugPrint('SoundDetection: Audio stream stopped');
        },
        onError: (e) {
          debugPrint('SoundDetection: Audio stream error: $e');
        },
      );

      _monitoring = true;
      debugPrint('SoundDetection: Monitoring started');
    } catch (e) {
      debugPrint('SoundDetection start error: $e');
    }
  }

  /// Initialize the sherpa-ONNX AudioTagging with CED-mini INT8 model.
  Future<bool> _initializeTagger() async {
    try {
      final modelManager = AudioModelManager.instance;
      if (modelManager.modelPath == null || modelManager.labelsPath == null) {
        debugPrint('SoundDetection: Model paths not available');
        return false;
      }

      final config = sherpa_onnx.AudioTaggingConfig(
        model: sherpa_onnx.AudioTaggingModelConfig(
          ced: modelManager.modelPath!,
          numThreads: 1,
          provider: 'cpu',
          debug: false,
        ),
        labels: modelManager.labelsPath!,
      );

      _tagger = sherpa_onnx.AudioTagging(config: config);
      _taggerStream = _tagger!.createStream();
      _modelLoaded = true;

      debugPrint('SoundDetection: Tagger initialized with CED-mini INT8');
      return true;
    } catch (e) {
      debugPrint('SoundDetection: Tagger init error: $e');
      _modelLoaded = false;
      return false;
    }
  }

  /// Stop monitoring and release resources.
  void stopMonitoring() {
    _monitoring = false;
    _audioSubscription?.cancel();
    _audioSubscription = null;

    try {
      _audioRecorder?.stop();
    } catch (e) {
      debugPrint('SoundDetection: Error stopping recorder: $e');
    }

    // Release sherpa-ONNX resources
    _releaseTagger();

    // Clear audio buffer
    _pcmWritePos = 0;
    _totalSamplesCollected = 0;

    debugPrint('SoundDetection: Monitoring stopped');
  }

  /// Release the sherpa-ONNX tagger and stream.
  void _releaseTagger() {
    try {
      _taggerStream?.free();
      _taggerStream = null;
    } catch (e) {
      debugPrint('SoundDetection: Error freeing stream: $e');
    }

    try {
      _tagger?.free();
      _tagger = null;
    } catch (e) {
      debugPrint('SoundDetection: Error freeing tagger: $e');
    }

    _modelLoaded = false;
  }

  // ══════════════════════════════════════════════════════════════════════
  // AUDIO PROCESSING
  // ══════════════════════════════════════════════════════════════════════

  /// Called when raw PCM16 audio data arrives from the microphone.
  void _onAudioData(List<int> data) {
    if (!_monitoring || data.isEmpty) return;

    // Convert bytes to Int16 samples and add to circular buffer
    final int16Data = Int16List.fromList(data);

    for (int i = 0; i < int16Data.length; i++) {
      _pcmBuffer[_pcmWritePos] = int16Data[i];
      _pcmWritePos = (_pcmWritePos + 1) % _windowSamples;
      _totalSamplesCollected++;
    }

    // Process inference after the initial fill, then every _hopSamples
    if (_totalSamplesCollected >= _windowSamples &&
        (_totalSamplesCollected - _windowSamples) % _hopSamples == 0) {
      _processWindow();
    }
  }

  /// Extract a 3-second window from the circular buffer and process it.
  void _processWindow() {
    if (_tagger == null || _taggerStream == null) return;

    // Extract the most recent 3-second window from the circular buffer
    final window = Float32List(_windowSamples);
    final int windowStart =
        (_pcmWritePos - _windowSamples + _windowSamples) % _windowSamples;

    for (int i = 0; i < _windowSamples; i++) {
      final idx = (windowStart + i) % _windowSamples;
      // PCM16 to Float32: normalize to [-1.0, 1.0]
      window[i] = _pcmBuffer[idx] / 32768.0;
    }

    // ── RMS energy gate ──────────────────────────────────────────────
    // Skip neural inference on silent/near-silent audio
    double sumSquares = 0.0;
    for (int i = 0; i < _windowSamples; i++) {
      sumSquares += window[i] * window[i];
    }
    final rms = sqrt(sumSquares / _windowSamples);
    final rmsScaled = rms * 32768.0; // Scale back to PCM16 range for threshold

    if (rmsScaled < _rmsGateThreshold) {
      // Audio is too quiet, skip inference for battery saving
      return;
    }

    // ── Run sherpa-ONNX inference ────────────────────────────────────
    try {
      _taggerStream!.acceptWaveform(
        samples: window,
        sampleRate: _sampleRate,
      );

      final events = _tagger!.compute(stream: _taggerStream!, topK: 10);

      for (final event in events) {
        _processDetection(event.name, event.prob);
      }
    } catch (e) {
      debugPrint('SoundDetection: Inference error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // DETECTION PIPELINE
  // ══════════════════════════════════════════════════════════════════════

  /// Process a single detection from the classifier.
  void _processDetection(String label, double confidence) {
    if (!_monitoring) return;

    // Map model label to HumSukhan event type
    final eventType = _mapLabelToEvent(label);
    if (eventType == null) return;

    // Apply confidence threshold
    final threshold =
        _criticalEvents.contains(eventType) ? _criticalThreshold : _nonCriticalThreshold;
    if (confidence < threshold) return;

    // Check per-event cooldown
    final now = DateTime.now();
    final lastTime = _lastDetectionTime[eventType];
    if (lastTime != null && now.difference(lastTime) < _cooldownDuration) {
      return;
    }

    // Temporal confirmation for non-critical events
    if (!_criticalEvents.contains(eventType)) {
      if (!_passesTemporalConfirmation(eventType, now)) {
        return;
      }
    }

    // Emit the event
    _emitEvent(eventType, confidence);
  }

  /// Check if an event passes temporal confirmation.
  /// Non-critical events need 2 compatible detections within _temporalWindow.
  bool _passesTemporalConfirmation(String eventType, DateTime now) {
    _temporalBuffer[eventType] ??= [];

    // Remove old entries outside the temporal window
    _temporalBuffer[eventType]!.removeWhere(
        (t) => now.difference(t) > _temporalWindow);

    // Add current detection
    _temporalBuffer[eventType]!.add(now);

    // Need at least 2 detections within the window
    return _temporalBuffer[eventType]!.length >= 2;
  }

  /// Clear the temporal confirmation buffer.
  void _clearTemporalBuffer() {
    for (final key in _temporalBuffer.keys) {
      _temporalBuffer[key]!.clear();
    }
  }

  /// Emit a SoundEvent through the callback.
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

  /// Map a model label (from AudioSet) to a HumSukhan event type.
  /// Uses case-insensitive substring matching.
  String? _mapLabelToEvent(String label) {
    final lowerLabel = label.toLowerCase();

    for (final entry in _labelMapping.entries) {
      for (final pattern in entry.value) {
        if (lowerLabel.contains(pattern.toLowerCase())) {
          return entry.key;
        }
      }
    }

    return null;
  }

  /// Get severity level based on event type.
  String _getSeverity(String eventType) {
    switch (eventType) {
      case 'Fire Alarm':
        return 'critical';
      case 'Siren':
        return 'critical';
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

  /// Process a sound classification result from an external source.
  /// This is called when the audio classifier produces results externally.
  bool processClassification(String label, double confidence) {
    if (!_monitoring) return false;

    final eventType = _mapLabelToEvent(label);
    if (eventType == null) return false;

    final threshold =
        _criticalEvents.contains(eventType) ? _criticalThreshold : _nonCriticalThreshold;
    if (confidence < threshold) return false;

    // Check cooldown
    final now = DateTime.now();
    final lastTime = _lastDetectionTime[eventType];
    if (lastTime != null && now.difference(lastTime) < _cooldownDuration) {
      return false;
    }

    // Temporal confirmation for non-critical events
    if (!_criticalEvents.contains(eventType)) {
      if (!_passesTemporalConfirmation(eventType, now)) {
        return false;
      }
    }

    _emitEvent(eventType, confidence);
    return true;
  }

  /// Get the number of model labels loaded.
  int get labelCount => _modelLabels.length;

  /// Get the list of model labels.
  List<String> get modelLabels => List.unmodifiable(_modelLabels);

  /// Get the list of supported event types.
  static List<String> get supportedEvents =>
      _labelMapping.keys.toList();

  // ══════════════════════════════════════════════════════════════════════
  // CLEANUP
  // ══════════════════════════════════════════════════════════════════════

  /// Dispose all resources.
  void dispose() {
    stopMonitoring();
    _audioRecorder?.dispose();
    _audioRecorder = null;
    _modelLabels = [];
    _lastDetectionTime.clear();
    _clearTemporalBuffer();
  }
}
