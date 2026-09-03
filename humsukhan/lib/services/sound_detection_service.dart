import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../models/models.dart';
import 'audio_model_manager.dart';
import 'sherpa_audio_tagger.dart';

class SoundDetectionService {
  SoundDetectionService._();
  static SoundDetectionService? _instance;
  static SoundDetectionService get instance => _instance ??= SoundDetectionService._();
  static const Duration cooldownDuration = Duration(seconds: 30);

  bool _initialized = false;
  bool _monitoring = false;
  bool _microphoneReady = false;
  bool _modelReady = false;
  AudioRecorder? _audioRecorder;
  StreamSubscription<Uint8List>? _audioSubscription;
  Function(SoundEvent)? onSoundDetected;
  final SherpaAudioTagger _tagger = SherpaAudioTagger();
  static const int _sampleRate = 16000;
  static const int _windowSamples = 3 * _sampleRate;
  static const int _hopSamples = 1 * _sampleRate;
  static const double _rmsGateThreshold = 200.0;
  static const Duration _temporalWindow = Duration(seconds: 8);
  final Int16List _pcmBuffer = Int16List(_windowSamples);
  final Float32List _windowFloat = Float32List(_windowSamples);
  int _pcmWritePos = 0;
  int _totalSamplesCollected = 0;
  final Map<String, DateTime> _lastDetectionTime = {};
  final Map<String, List<DateTime>> _temporalBuffer = {};

  static const Map<String, List<String>> _labelMapping = {
    'Siren': ['siren', 'police car (siren)', 'ambulance (siren)', 'fire engine, fire truck (siren)', 'civil defense siren', 'emergency vehicle'],
    'Doorbell': ['doorbell', 'chime'],
    'Knock': ['knock', 'tap'],
    'Phone': ['telephone', 'telephone bell ringing', 'ringtone', 'car alarm'],
    'Baby Cry': ['baby cry, infant cry', 'crying, sobbing', 'whimper'],
    'Alarm Clock': ['alarm clock', 'alarm', 'buzzer'],
    'Vehicle Horn': ['vehicle horn, car horn, honking', 'air horn, truck horn', 'honk'],
    'Glass Break': ['glass', 'shatter'],
    'Dog Bark': ['bark'],
  };
  static const Set<String> _criticalEvents = {'Siren'};
  static const double _criticalThreshold = 0.70;
  static const double _nonCriticalThreshold = 0.55;

  bool get isInitialized => _initialized;
  bool get isMonitoring => _monitoring;
  bool get isMicrophoneReady => _microphoneReady;
  bool get isModelReady => _modelReady;
  int get labelCount => _tagger.labels.length;
  List<String> get modelLabels => _tagger.labels;
  static List<String> get supportedEvents => _labelMapping.keys.toList();

  Future<bool> initialize({bool requestPermission = true}) async {
    if (_initialized) return _microphoneReady;
    try {
      if (requestPermission) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          _initialized = true;
          return false;
        }
      } else if (!await _hasPermission()) {
        _initialized = true;
        return false;
      }

      _audioRecorder ??= AudioRecorder();
      _microphoneReady = await _audioRecorder!.hasPermission();
      _initialized = true;
      return _microphoneReady;
    } catch (e) {
      debugPrint('SoundDetection microphone init error: $e');
      _initialized = true;
      _microphoneReady = false;
      return false;
    }
  }

  Future<bool> _hasPermission() async => (await Permission.microphone.status).isGranted;

  Future<bool> startMonitoring({bool permissionAlreadyGranted = false}) async {
    if (_monitoring) return true;

    // The Android foreground service reaches this code through a secondary
    // Flutter engine. Permission has already been checked by MainActivity, so
    // do not depend on permission_handler's secondary-isolate state here.
    if (!_initialized) {
      if (permissionAlreadyGranted) {
        _audioRecorder ??= AudioRecorder();
        _microphoneReady = true;
        _initialized = true;
      } else if (!await initialize(requestPermission: true)) {
        return false;
      }
    }
    if (!_microphoneReady || _audioRecorder == null) return false;

    try {
      final manager = AudioModelManager.instance;
      _modelReady = await manager.initialize();
      if (!_modelReady) {
        _modelReady = await manager.downloadModel();
      }
      _modelReady = _modelReady && await _tagger.initialize();
      if (!_modelReady) {
        debugPrint('SoundDetection model is unavailable');
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
        onError: (e) => debugPrint('SoundDetection stream error: $e'),
      );
      _monitoring = true;
      return true;
    } catch (e) {
      debugPrint('SoundDetection start error: $e');
      _monitoring = false;
      return false;
    }
  }

  void stopMonitoring() {
    _monitoring = false;
    _audioSubscription?.cancel();
    _audioSubscription = null;
    try {
      _audioRecorder?.stop();
      _audioRecorder?.dispose();
    } catch (_) {}
    _audioRecorder = null;
    _microphoneReady = false;
    _modelReady = false;
    _tagger.release();
    _pcmWritePos = 0;
    _totalSamplesCollected = 0;
  }

  void _onAudioData(Uint8List data) {
    if (!_monitoring || data.lengthInBytes < 2) return;
    final length = data.lengthInBytes - (data.lengthInBytes % 2);
    final samples = Int16List.view(data.buffer, data.offsetInBytes, length ~/ 2);
    for (final sample in samples) {
      _pcmBuffer[_pcmWritePos] = sample;
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
    final start = _pcmWritePos;
    for (var i = 0; i < _windowSamples; i++) {
      final s = _pcmBuffer[(start + i) % _windowSamples].toDouble();
      sumSq += s * s;
    }
    if (sumSq / _windowSamples < _rmsGateThreshold * _rmsGateThreshold) return;
    for (var i = 0; i < _windowSamples; i++) {
      _windowFloat[i] = _pcmBuffer[(start + i) % _windowSamples] / 32768.0;
    }
    for (final result in _tagger.classify(samples: _windowFloat, topK: 10)) {
      _processDetection(result.label, result.probability);
    }
  }

  void _processDetection(String label, double confidence) {
    if (!_monitoring) return;
    final eventType = _mapLabelToEvent(label);
    if (eventType == null) return;
    final threshold = _criticalEvents.contains(eventType) ? _criticalThreshold : _nonCriticalThreshold;
    if (confidence < threshold) return;
    final now = DateTime.now();
    final last = _lastDetectionTime[eventType];
    if (last != null && now.difference(last) < cooldownDuration) return;
    if (!_criticalEvents.contains(eventType) && !_passesTemporalConfirmation(eventType, now)) return;
    _emitEvent(eventType, confidence);
  }

  bool _passesTemporalConfirmation(String eventType, DateTime now) {
    final events = _temporalBuffer.putIfAbsent(eventType, () => <DateTime>[]);
    events.removeWhere((t) => now.difference(t) > _temporalWindow);
    events.add(now);
    return events.length >= 2;
  }

  void _clearTemporalBuffer() {
    for (final list in _temporalBuffer.values) {
      list.clear();
    }
  }

  void _emitEvent(String eventType, double confidence) {
    final event = SoundEvent(type: eventType, confidence: confidence, severity: _getSeverity(eventType));
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
    if (eventType == 'Siren' || eventType == 'Glass Break') return 'critical';
    if (eventType == 'Doorbell' || eventType == 'Knock' || eventType == 'Phone' || eventType == 'Baby Cry') return 'warning';
    return 'info';
  }

  bool processClassification(String label, double confidence) {
    if (!_monitoring) return false;
    final eventType = _mapLabelToEvent(label);
    if (eventType == null) return false;
    final threshold = _criticalEvents.contains(eventType) ? _criticalThreshold : _nonCriticalThreshold;
    if (confidence < threshold) return false;
    final now = DateTime.now();
    final last = _lastDetectionTime[eventType];
    if (last != null && now.difference(last) < cooldownDuration) return false;
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
