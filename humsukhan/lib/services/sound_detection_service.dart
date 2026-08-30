import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../models/models.dart';
import 'audio_model_manager.dart';
import 'sherpa_audio_tagger.dart';

/// Local environmental sound detector.
///
/// Microphone → 16 kHz mono PCM16 → RMS gate → 3 s window / 1 s hop →
/// sherpa-ONNX CED-Tiny INT8 → confidence → temporal confirmation → event.
///
/// No network call is made from this service. The model is loaded only while
/// monitoring is active and all native resources are released on stop.
class SoundDetectionService {
  SoundDetectionService._();
  static SoundDetectionService? _instance;
  static SoundDetectionService get instance => _instance ??= SoundDetectionService._();

  bool _initialized = false;
  bool _monitoring = false;
  AudioRecorder? _audioRecorder;
  StreamSubscription<Uint8List>? _audioSubscription;
  Function(SoundEvent)? onSoundDetected;

  final SherpaAudioTagger _tagger = SherpaAudioTagger();

  static const int _sampleRate = 16000;
  static const int _windowSamples = 3 * _sampleRate;
  static const int _hopSamples = 1 * _sampleRate;
  static const double _rmsGateThreshold = 200.0;
  static const Duration _cooldownDuration = Duration(seconds: 30);
  static const Duration _temporalWindow = Duration(seconds: 8);

  final Int16List _pcmBuffer = Int16List(_windowSamples);
  final Float32List _windowFloat = Float32List(_windowSamples);
  int _pcmWritePos = 0;
  int _totalSamplesCollected = 0;
  final Map<String, DateTime> _lastDetectionTime = {};
  final Map<String, List<DateTime>> _temporalBuffer = {};

  static const Map<String, List<String>> _labelMapping = {
    'Fire Alarm': ['smoke detector, smoke alarm', 'fire alarm'],
    'Siren': [
      'siren',
      'police car (siren)',
      'ambulance (siren)',
      'fire engine, fire truck (siren)',
      'civil defense siren',
      'emergency vehicle',
    ],
    'Doorbell': ['doorbell', 'chime'],
    'Knock': ['knock', 'tap'],
    'Phone': ['telephone', 'telephone bell ringing', 'ringtone', 'car alarm'],
    'Baby Cry': ['baby cry, infant cry', 'crying, sobbing', 'whimper'],
    'Alarm Clock': ['alarm clock', 'alarm', 'buzzer'],
    'Vehicle Horn': ['vehicle horn, car horn, honking', 'air horn, truck horn', 'honk'],
    'Glass Break': ['glass', 'shatter'],
    'Dog Bark': ['bark'],
    'Phone/Ringtone': ['ringtone', 'telephone bell ringing', 'telephone'],
  };

  static const Set<String> _criticalEvents = {'Fire Alarm', 'Siren'};
  static const double _criticalThreshold = 0.70;
  static const double _nonCriticalThreshold = 0.55;

  bool get isInitialized => _initialized;
  bool get isMonitoring => _monitoring;
  bool get isModelReady => _tagger.isInitialized;
  int get labelCount => _tagger.labels.length;
  List<String> get modelLabels => _tagger.labels;
  static List<String> get supportedEvents => _labelMapping.keys.toList();

  /// Prepare microphone resources and verify that the model is already local.
  /// This method never downloads a model.
  Future<bool> initialize({bool requestPermission = true}) async {
    if (_initialized) return _audioRecorder != null && await _hasPermission();
    try {
      if (requestPermission) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          debugPrint('SoundDetection: microphone permission denied');
          _initialized = true;
          return false;
        }
      } else if (!await _hasPermission()) {
        debugPrint('SoundDetection: microphone permission unavailable');
        _initialized = true;
        return false;
      }

      final modelReady = await AudioModelManager.instance.initialize();
      if (!modelReady) {
        debugPrint('SoundDetection: local environmental model is unavailable');
        _initialized = true;
        return false;
      }

      _audioRecorder ??= AudioRecorder();
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('SoundDetection init error: $e');
      _initialized = true;
      return false;
    }
  }

  Future<bool> _hasPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Start the actual local microphone + classifier pipeline.
  /// Set [permissionAlreadyGranted] when invoked by the Android foreground
  /// service after the native layer has verified RECORD_AUDIO.
  Future<bool> startMonitoring({bool permissionAlreadyGranted = false}) async {
    if (_monitoring) return true;
    if (!_initialized) {
      final ok = await initialize(requestPermission: !permissionAlreadyGranted);
      if (!ok) return false;
    }
    if (_audioRecorder == null) return false;

    try {
      if (!permissionAlreadyGranted && !await _audioRecorder!.hasPermission()) {
        debugPrint('SoundDetection: no recorder permission');
        return false;
      }

      if (!await AudioModelManager.instance.initialize()) {
        debugPrint('SoundDetection: refusing to start without local model');
        return false;
      }
      if (!await _tagger.initialize()) {
        debugPrint('SoundDetection: tagger initialization failed');
        return false;
      }

      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      );
      final stream = await _audioRecorder!.startStream(config);

      _pcmWritePos = 0;
      _totalSamplesCollected = 0;
      _clearTemporalBuffer();
      _audioSubscription = stream.listen(
        _onAudioData,
        onDone: () => debugPrint('SoundDetection: audio stream ended'),
        onError: (e) => debugPrint('SoundDetection: audio stream error: $e'),
      );
      _monitoring = true;
      debugPrint('SoundDetection: local monitoring active');
      return true;
    } catch (e) {
      debugPrint('SoundDetection start error: $e');
      _monitoring = false;
      _tagger.release();
      return false;
    }
  }

  void stopMonitoring() {
    _monitoring = false;
    _audioSubscription?.cancel();
    _audioSubscription = null;
    try { _audioRecorder?.stop(); } catch (_) {}
    try { _audioRecorder?.dispose(); } catch (_) {}
    _audioRecorder = null;
    _tagger.release();
    _pcmWritePos = 0;
    _totalSamplesCollected = 0;
    debugPrint('SoundDetection: stopped; microphone and model released');
  }

  void _onAudioData(Uint8List data) {
    if (!_monitoring || data.isEmpty || data.lengthInBytes < 2) return;
    final offset = data.offsetInBytes;
    final length = data.lengthInBytes - (data.lengthInBytes % 2);
    final samples = Int16List.view(data.buffer, offset, length ~/ 2);
    for (var i = 0; i < samples.length; i++) {
      _pcmBuffer[_pcmWritePos] = samples[i];
      _pcmWritePos = (_pcmWritePos + 1) % _windowSamples;
      _totalSamplesCollected++;
    }
    if (_totalSamplesCollected >= _windowSamples &&
        (_totalSamplesCollected - _windowSamples) % _hopSamples == 0) {
      _processWindow();
    }
  }

  void _processWindow() {
    if (!_tagger.isInitialized) return;
    var sumSq = 0.0;
    final start = (_pcmWritePos - _windowSamples + _windowSamples) % _windowSamples;
    for (var i = 0; i < _windowSamples; i++) {
      final s = _pcmBuffer[(start + i) % _windowSamples].toDouble();
      sumSq += s * s;
    }
    final rmsSq = sumSq / _windowSamples;
    if (rmsSq < _rmsGateThreshold * _rmsGateThreshold) return;

    for (var i = 0; i < _windowSamples; i++) {
      _windowFloat[i] = _pcmBuffer[(start + i) % _windowSamples] / 32768.0;
    }
    final results = _tagger.classify(samples: _windowFloat, topK: 10);
    for (final result in results) {
      _processDetection(result.label, result.probability);
    }
  }

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
    if (!_criticalEvents.contains(eventType) && !_passesTemporalConfirmation(eventType, now)) return;
    _emitEvent(eventType, confidence);
  }

  bool _passesTemporalConfirmation(String eventType, DateTime now) {
    _temporalBuffer[eventType] ??= <DateTime>[];
    final events = _temporalBuffer[eventType]!;
    events.removeWhere((t) => now.difference(t) > _temporalWindow);
    events.add(now);
    return events.length >= 2;
  }

  void _clearTemporalBuffer() {
    for (final list in _temporalBuffer.values) list.clear();
  }

  void _emitEvent(String eventType, double confidence) {
    final severity = _getSeverity(eventType);
    final event = SoundEvent(type: eventType, confidence: confidence, severity: severity);
    _lastDetectionTime[eventType] = DateTime.now();
    onSoundDetected?.call(event);
  }

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
      case 'Phone/Ringtone':
      case 'Baby Cry':
        return 'warning';
      default:
        return 'info';
    }
  }

  bool processClassification(String label, double confidence) {
    if (!_monitoring) return false;
    final eventType = _mapLabelToEvent(label);
    if (eventType == null) return false;
    final threshold = _criticalEvents.contains(eventType) ? _criticalThreshold : _nonCriticalThreshold;
    if (confidence < threshold) return false;
    final now = DateTime.now();
    final last = _lastDetectionTime[eventType];
    if (last != null && now.difference(last) < _cooldownDuration) return false;
    if (!_criticalEvents.contains(eventType) && !_passesTemporalConfirmation(eventType, now)) return false;
    _emitEvent(eventType, confidence);
    return true;
  }

  void dispose() {
    stopMonitoring();
    _lastDetectionTime.clear();
    _clearTemporalBuffer();
  }
}
