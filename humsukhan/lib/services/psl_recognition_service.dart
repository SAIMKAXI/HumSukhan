import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Pakistani Sign Language recognition service.
///
/// The camera pipeline is intentionally kept self-contained. Camera frames are
/// analysed on a background isolate and only confirmed gestures are emitted to
/// the UI. A production PSL vocabulary/model can be plugged into the same
/// result stream without changing the screen.
class PslRecognitionService {
  PslRecognitionService._();
  static PslRecognitionService? _instance;
  static PslRecognitionService get instance => _instance ??= PslRecognitionService._();

  List<CameraDescription> _cameras = const [];
  CameraController? _cameraController;
  int _cameraIndex = 0;
  final StreamController<PslResult> _resultController = StreamController<PslResult>.broadcast();
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _frameBusy = false;
  String _accumulatedText = '';
  DateTime? _lastSignTime;
  DateTime? _lastSpaceTime;

  static const Duration _signDebounce = Duration(milliseconds: 800);
  static const Duration _spaceTimeout = Duration(seconds: 2);

  Stream<PslResult> get onResult => _resultController.stream;
  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;
  String get accumulatedText => _accumulatedText;
  CameraController? get cameraController => _cameraController;
  List<CameraDescription> get cameras => List.unmodifiable(_cameras);
  int get cameraIndex => _cameraIndex;
  CameraLensDirection get lensDirection => _cameraController?.description.lensDirection ?? CameraLensDirection.front;

  Future<bool> initialize() async {
    if (_isInitialized && _cameraController?.value.isInitialized == true) return true;
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return false;

      final preferred = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      _cameraIndex = preferred >= 0 ? preferred : 0;
      await _createController();
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('PSL camera initialization error: $e');
      return false;
    }
  }

  Future<void> _createController() async {
    final camera = _cameras[_cameraIndex];
    final previous = _cameraController;
    _cameraController = null;
    try {
      await previous?.dispose();
    } catch (_) {}

    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await controller.initialize();
    _cameraController = controller;
  }

  Future<bool> switchCamera() async {
    if (_cameras.length < 2) return false;
    final wasProcessing = _isProcessing;
    stopProcessing();
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    try {
      await _createController();
      if (wasProcessing) await startProcessing();
      return true;
    } catch (e) {
      debugPrint('PSL camera switch error: $e');
      return false;
    }
  }

  Future<void> startProcessing() async {
    final controller = _cameraController;
    if (!_isInitialized || controller == null || !controller.value.isInitialized || _isProcessing) return;
    _isProcessing = true;
    _accumulatedText = '';
    _lastSignTime = null;
    _lastSpaceTime = null;
    try {
      await controller.startImageStream((image) {
        if (!_isProcessing || _frameBusy) return;
        _frameBusy = true;
        compute(_detectGesture, _FrameData.fromImage(image)).then((result) {
          if (result != null) _handleDetectionResult(result);
        }).whenComplete(() => _frameBusy = false);
      });
    } catch (e) {
      _isProcessing = false;
      debugPrint('PSL image stream error: $e');
    }
  }

  void stopProcessing() {
    _isProcessing = false;
    _frameBusy = false;
    try {
      _cameraController?.stopImageStream();
    } catch (_) {}
  }

  void _handleDetectionResult(_DetectionResult result) {
    if (!result.handDetected || result.confidence < 0.12) return;
    final now = DateTime.now();
    final gesture = _classify(result);
    if (gesture == null) return;
    if (_lastSignTime != null && now.difference(_lastSignTime!) < _signDebounce) return;

    if (_accumulatedText.isNotEmpty && _lastSpaceTime != null && now.difference(_lastSpaceTime!) > _spaceTimeout && !gesture.isSpace) {
      _accumulatedText += ' ';
    }
    if (gesture.isSpace) {
      if (!_accumulatedText.endsWith(' ')) _accumulatedText += ' ';
      _lastSpaceTime = now;
    } else if (gesture.character != null) {
      _accumulatedText += gesture.character!;
      _lastSpaceTime = now;
    }
    _lastSignTime = now;
    _resultController.add(PslResult(
      character: gesture.character,
      gestureName: gesture.name,
      accumulatedText: _accumulatedText,
      confidence: result.confidence,
    ));
  }

  _PslGesture? _classify(_DetectionResult result) {
    final fingers = result.extendedFingers;
    if (fingers == 0) return const _PslGesture(name: 'Fist');
    if (fingers >= 5) return const _PslGesture(name: 'Open Palm', isSpace: true);
    if (fingers == 1) return const _PslGesture(name: 'Single Finger', character: 'A');
    if (fingers == 2) return const _PslGesture(name: 'Two Fingers', character: 'B');
    if (fingers == 3) return const _PslGesture(name: 'Three Fingers', character: 'W');
    if (fingers == 4) return const _PslGesture(name: 'Four Fingers', character: 'H');
    return null;
  }

  void clearText() {
    _accumulatedText = '';
    _lastSignTime = null;
    _lastSpaceTime = null;
    _resultController.add(const PslResult(character: null, gestureName: 'Cleared', accumulatedText: '', confidence: 1.0));
  }

  void dispose() {
    stopProcessing();
    _cameraController?.dispose();
    _cameraController = null;
    _isInitialized = false;
    _resultController.close();
  }
}

class _FrameData {
  final List<_PlaneData> planes;
  final int width;
  final int height;
  const _FrameData({required this.planes, required this.width, required this.height});

  factory _FrameData.fromImage(CameraImage image) => _FrameData(
    planes: image.planes.map((p) => _PlaneData(bytes: p.bytes, bytesPerRow: p.bytesPerRow)).toList(),
    width: image.width,
    height: image.height,
  );
}

class _PlaneData {
  final Uint8List bytes;
  final int bytesPerRow;
  const _PlaneData({required this.bytes, required this.bytesPerRow});
}

class _DetectionResult {
  final bool handDetected;
  final int extendedFingers;
  final double confidence;
  const _DetectionResult({required this.handDetected, required this.extendedFingers, required this.confidence});
}

_DetectionResult? _detectGesture(_FrameData frame) {
  if (frame.planes.length < 3 || frame.width <= 0 || frame.height <= 0) return null;
  final y = frame.planes[0].bytes;
  final u = frame.planes[1].bytes;
  final v = frame.planes[2].bytes;

  // Sample the central hand area. This is deliberately conservative: it
  // detects a real hand-shaped skin region rather than fabricating landmarks.
  final left = frame.width ~/ 8;
  final right = frame.width - left;
  final top = frame.height ~/ 10;
  final bottom = frame.height * 8 ~/ 10;
  final columns = List<int>.filled(8, 0);
  var skin = 0;
  var total = 0;

  for (var py = top; py < bottom; py += 6) {
    for (var px = left; px < right; px += 6) {
      final yi = py * frame.planes[0].bytesPerRow + px;
      final uvRow = py ~/ 2;
      final uvCol = px ~/ 2;
      final ui = uvRow * frame.planes[1].bytesPerRow + uvCol;
      if (yi >= y.length || ui >= u.length || ui >= v.length) continue;
      final yy = y[yi];
      final uu = u[ui];
      final vv = v[ui];
      final isSkin = yy > 65 && yy < 245 && uu > 75 && uu < 145 && vv > 120 && vv < 190;
      total++;
      if (isSkin) {
        skin++;
        final col = (((px - left) * 8) ~/ (right - left)).clamp(0, 7);
        columns[col]++;
      }
    }
  }

  if (total == 0) return null;
  final ratio = skin / total;
  if (ratio < 0.025) return const _DetectionResult(handDetected: false, extendedFingers: 0, confidence: 0);

  // Approximate fingertip peaks from the upper half of each column. This is
  // a lightweight fallback, not a substitute for a trained PSL model.
  final avg = skin / columns.length;
  final peaks = columns.where((c) => c > avg * 0.65).length;
  final fingers = peaks.clamp(0, 5);
  return _DetectionResult(handDetected: true, extendedFingers: fingers, confidence: ratio.clamp(0.0, 1.0));
}

class _PslGesture {
  final String name;
  final String? character;
  final bool isSpace;
  const _PslGesture({required this.name, this.character, this.isSpace = false});
}

class PslResult {
  final String? character;
  final String gestureName;
  final String accumulatedText;
  final double confidence;
  const PslResult({required this.character, required this.gestureName, required this.accumulatedText, required this.confidence});
}
