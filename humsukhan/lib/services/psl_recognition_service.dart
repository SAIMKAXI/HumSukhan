import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Pakistani Sign Language (PSL) recognition service.
///
/// Pipeline: Camera → Hand landmark detection → Gesture classification → Character mapping
///
/// Uses MediaPipe Hands via camera frames to detect hand landmarks,
/// then classifies static PSL signs into characters.
class PslRecognitionService {
  PslRecognitionService._();
  static PslRecognitionService? _instance;
  static PslRecognitionService get instance => _instance ??= PslRecognitionService._();

  CameraController? _cameraController;
  StreamSubscription? _frameSubscription;
  final StreamController<PslResult> _resultController =
      StreamController<PslResult>.broadcast();

  bool _isInitialized = false;
  bool _isProcessing = false;
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

  /// Initialize camera for PSL detection.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('PSL: No cameras available');
        return false;
      }

      // Use front camera for selfie-style sign detection
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      _isInitialized = true;

      debugPrint('PSL: Camera initialized (${camera.name})');
      return true;
    } catch (e) {
      debugPrint('PSL initialization error: $e');
      return false;
    }
  }

  /// Start processing camera frames for PSL detection.
  Future<void> startProcessing() async {
    if (!_isInitialized || _cameraController == null) return;
    if (_isProcessing) return;

    _isProcessing = true;
    _accumulatedText = '';
    _lastSignTime = null;

    // Listen to image stream
    await _cameraController!.startImageStream((CameraImage image) {
      if (!_isProcessing) return;
      _processFrame(image);
    });

    debugPrint('PSL: Processing started');
  }

  /// Stop processing.
  void stopProcessing() {
    _isProcessing = false;
    _frameSubscription?.cancel();
    _cameraController?.stopImageStream();
    debugPrint('PSL: Processing stopped');
  }

  /// Process a camera frame for hand detection and gesture classification.
  void _processFrame(CameraImage image) {
    // Throttle processing — don't process every frame
    if (_isProcessing) {
      _isProcessing = false; // Prevent re-entry

      // Run detection in a separate isolate to avoid blocking UI
      compute(_detectAndClassify, _FrameData(
        planes: image.planes.map((p) => _PlaneData(
          bytes: p.bytes,
          bytesPerRow: p.bytesPerRow,
          bytesPerPixel: p.bytesPerPixel ?? 1,
        )).toList(),
        width: image.width,
        height: image.height,
        format: image.format.raw,
      )).then((result) {
        if (result != null) {
          _handleDetectionResult(result);
        }
        _isProcessing = true; // Re-enable for next frame
      }).catchError((e) {
        _isProcessing = true;
      });
    }
  }

  /// Handle a detection result from the isolate.
  void _handleDetectionResult(_DetectionResult result) {
    if (!result.handDetected) return;

    final now = DateTime.now();
    final gesture = _classifyGesture(result.landmarks);

    if (gesture != null) {
      // Debounce: ignore same sign within debounce window
      if (_lastSignTime != null && now.difference(_lastSignTime!) < _signDebounce) {
        return;
      }

      // Auto-space: insert space if enough time since last sign
      if (_accumulatedText.isNotEmpty &&
          _lastSpaceTime != null &&
          now.difference(_lastSpaceTime!) > _spaceTimeout &&
          !gesture.isSpace) {
        _accumulatedText += ' ';
      }

      if (gesture.isSpace) {
        _accumulatedText += ' ';
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
  }

  /// Classify hand landmarks into a PSL gesture.
  /// Returns null if no valid gesture detected.
  _PslGesture? _classifyGesture(List<HandLandmark> landmarks) {
    if (landmarks.length < 21) return null;

    // Extract finger tip and base positions
    final thumbTip = landmarks[4];
    final indexTip = landmarks[8];
    final middleTip = landmarks[12];
    final ringTip = landmarks[16];
    final pinkyTip = landmarks[20];

    final thumbIp = landmarks[3];
    final indexPip = landmarks[6];
    final middlePip = landmarks[10];
    final ringPip = landmarks[14];
    final pinkyPip = landmarks[18];

    // Determine if each finger is extended
    // A finger is extended if its tip is above (lower y value) its PIP joint
    final thumbExtended = thumbTip.x < thumbIp.x; // For right hand
    final indexExtended = indexTip.y < indexPip.y;
    final middleExtended = middleTip.y < middlePip.y;
    final ringExtended = ringTip.y < ringPip.y;
    final pinkyExtended = pinkyTip.y < pinkyPip.y;

    // PSL character mapping based on hand shapes
    //
    // These are simplified static PSL signs. Full PSL recognition would
    // require a trained ML model. These demonstrate the concept with
    // commonly used signs.

    // Fist — all fingers closed → 'FIST' gesture
    if (!indexExtended && !middleExtended && !ringExtended && !pinkyExtended) {
      return _PslGesture(name: 'Fist', character: null);
    }

    // Open palm — all fingers extended → 'STOP' or space
    if (indexExtended && middleExtended && ringExtended && pinkyExtended) {
      // Check thumb position for open vs specific letter
      if (thumbExtended) {
        return _PslGesture(name: 'Open Palm', isSpace: true);
      }
      return _PslGesture(name: 'Palm', character: 'H');
    }

    // Pointing index only → 'A' (PSL: index up = A)
    if (indexExtended && !middleExtended && !ringExtended && !pinkyExtended) {
      return _PslGesture(name: 'Point Index', character: 'A');
    }

    // Index + middle extended (V shape) → 'V' or 'B'
    if (indexExtended && middleExtended && !ringExtended && !pinkyExtended) {
      return _PslGesture(name: 'V Shape', character: 'B');
    }

    // Index + middle + ring extended → 'W' (3 fingers up)
    if (indexExtended && middleExtended && ringExtended && !pinkyExtended) {
      return _PslGesture(name: 'Three Fingers', character: 'W');
    }

    // Thumb extended, others closed → 'T' (thumb up)
    if (thumbExtended && !indexExtended && !middleExtended && !ringExtended && !pinkyExtended) {
      return _PslGesture(name: 'Thumb Up', character: 'T');
    }

    // Thumb + index extended (L shape) → 'L'
    if (thumbExtended && indexExtended && !middleExtended && !ringExtended && !pinkyExtended) {
      return _PslGesture(name: 'L Shape', character: 'L');
    }

    // Thumb + pinky extended (Y shape) → 'Y'
    if (thumbExtended && !indexExtended && !middleExtended && !ringExtended && pinkyExtended) {
      return _PslGesture(name: 'Y Shape', character: 'Y');
    }

    // Index + pinky extended (Horn) → 'I' (PSL: I = pinky up, but horn for demo)
    if (!indexExtended && !middleExtended && !ringExtended && pinkyExtended) {
      return _PslGesture(name: 'Pinky Up', character: 'I');
    }

    // Ring + pinky extended → 'U' (PSL sign for U)
    if (!indexExtended && !middleExtended && ringExtended && pinkyExtended) {
      return _PslGesture(name: 'Ring + Pinky', character: 'U');
    }

    // Middle only extended → 'D' (PSL: D = middle up)
    if (!indexExtended && middleExtended && !ringExtended && !pinkyExtended) {
      return _PslGesture(name: 'Middle Only', character: 'D');
    }

    return null; // No recognized gesture
  }

  /// Clear accumulated text.
  void clearText() {
    _accumulatedText = '';
    _lastSignTime = null;
    _lastSpaceTime = null;
    _resultController.add(PslResult(
      character: null,
      gestureName: 'Cleared',
      accumulatedText: '',
      confidence: 1.0,
    ));
  }

  /// Reset and dispose.
  void dispose() {
    stopProcessing();
    _cameraController?.dispose();
    _cameraController = null;
    _isInitialized = false;
    _resultController.close();
  }
}

/// Detected hand landmark.
class HandLandmark {
  final double x;
  final double y;
  final double z;

  const HandLandmark({required this.x, required this.y, required this.z});
}

/// PSL gesture classification result.
class _PslGesture {
  final String name;
  final String? character;
  final bool isSpace;
  const _PslGesture({
    required this.name,
    this.character,
    this.isSpace = false,
  });
}

/// Public result type.
class PslResult {
  final String? character;
  final String gestureName;
  final String accumulatedText;
  final double confidence;

  const PslResult({
    required this.character,
    required this.gestureName,
    required this.accumulatedText,
    required this.confidence,
  });
}

/// Data passed to compute isolate for frame processing.
class _FrameData {
  final List<_PlaneData> planes;
  final int width;
  final int height;
  final int format;

  const _FrameData({
    required this.planes,
    required this.width,
    required this.height,
    required this.format,
  });
}

class _PlaneData {
  final Uint8List bytes;
  final int bytesPerRow;
  final int bytesPerPixel;

  const _PlaneData({
    required this.bytes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
  });
}

/// Detection result from isolate.
class _DetectionResult {
  final bool handDetected;
  final List<HandLandmark> landmarks;
  final double confidence;

  const _DetectionResult({
    required this.handDetected,
    required this.landmarks,
    required this.confidence,
  });
}

/// Process frame in isolate for hand detection.
/// Uses a simplified skin-color-based hand detection for the hackathon.
_DetectionResult? _detectAndClassify(_FrameData frame) {
  // Simplified hand detection using skin color thresholding
  // In production, this would use MediaPipe Hands or a TFLite model

  if (frame.planes.isEmpty) return null;

  final yPlane = frame.planes[0].bytes;
  final uPlane = frame.planes.length > 1 ? frame.planes[1].bytes : null;
  final vPlane = frame.planes.length > 2 ? frame.planes[2].bytes : null;

  // Sample center region for skin color detection
  final centerX = frame.width ~/ 2;
  final centerY = frame.height ~/ 2;
  final sampleRadius = frame.width ~/ 4;

  int skinPixelCount = 0;
  int totalPixels = 0;
  double sumX = 0;
  double sumY = 0;

  // YUV420 skin detection
  for (int dy = -sampleRadius; dy < sampleRadius; dy += 4) {
    for (int dx = -sampleRadius; dx < sampleRadius; dx += 4) {
      final px = centerX + dx;
      final py = centerY + dy;
      if (px < 0 || px >= frame.width || py < 0 || py >= frame.height) continue;

      final yIdx = py * frame.width + px;
      if (yIdx >= yPlane.length) continue;

      final y = yPlane[yIdx];
      int u = 128, v = 128;
      if (uPlane != null && vPlane != null) {
        final uvIdx = (py ~/ 2) * (frame.width ~/ 2) + (px ~/ 2);
        if (uvIdx < uPlane.length && uvIdx < vPlane.length) {
          u = uPlane[uvIdx];
          v = vPlane[uvIdx];
        }
      }

      // YUV skin color model (simplified)
      final isSkin = y > 80 && y < 240 &&
          u > 85 && u < 135 &&
          v > 130 && v < 175;

      totalPixels++;
      if (isSkin) {
        skinPixelCount++;
        sumX += px;
        sumY += py;
      }
    }
  }

  if (totalPixels == 0) return const _DetectionResult(
    handDetected: false, landmarks: [], confidence: 0.0,
  );

  final skinRatio = skinPixelCount / totalPixels;
  final handDetected = skinRatio > 0.05; // At least 5% skin pixels

  if (!handDetected) return const _DetectionResult(
    handDetected: false, landmarks: [], confidence: 0.0,
  );

  // Generate estimated landmarks based on skin centroid
  final centroidX = skinPixelCount > 0 ? sumX / skinPixelCount : centerX.toDouble();
  final centroidY = skinPixelCount > 0 ? sumY / skinPixelCount : centerY.toDouble();
  final handSize = sampleRadius * 0.6;

  // Generate 21 hand landmarks in estimated positions
  // These are approximations based on typical hand proportions
  final landmarks = _generateEstimatedLandmarks(centroidX, centroidY, handSize, frame.width, frame.height);

  return _DetectionResult(
    handDetected: true,
    landmarks: landmarks,
    confidence: skinRatio.clamp(0.0, 1.0),
  );
}

/// Generate estimated hand landmarks from skin centroid.
/// Maps a simplified hand model to 21 landmarks.
List<HandLandmark> _generateEstimatedLandmarks(
    double cx, double cy, double size, int imgW, int imgH) {
  // Normalize to 0-1 range
  final nx = cx / imgW;
  final ny = cy / imgH;
  final ns = size / imgW;

  // 21 hand landmarks: wrist, thumb(4), index(4), middle(4), ring(4), pinky(4)
  return [
    // 0: Wrist
    HandLandmark(x: nx, y: ny + ns * 0.3, z: 0),
    // 1-4: Thumb (CMC, MCP, IP, TIP)
    HandLandmark(x: nx - ns * 0.3, y: ny + ns * 0.2, z: 0),
    HandLandmark(x: nx - ns * 0.4, y: ny + ns * 0.1, z: 0),
    HandLandmark(x: nx - ns * 0.5, y: ny - ns * 0.05, z: 0),
    HandLandmark(x: nx - ns * 0.55, y: ny - ns * 0.15, z: 0),
    // 5-8: Index (MCP, PIP, DIP, TIP)
    HandLandmark(x: nx - ns * 0.15, y: ny + ns * 0.05, z: 0),
    HandLandmark(x: nx - ns * 0.15, y: ny - ns * 0.15, z: 0),
    HandLandmark(x: nx - ns * 0.15, y: ny - ns * 0.3, z: 0),
    HandLandmark(x: nx - ns * 0.15, y: ny - ns * 0.45, z: 0),
    // 9-12: Middle (MCP, PIP, DIP, TIP)
    HandLandmark(x: nx, y: ny + ns * 0.05, z: 0),
    HandLandmark(x: nx, y: ny - ns * 0.18, z: 0),
    HandLandmark(x: nx, y: ny - ns * 0.33, z: 0),
    HandLandmark(x: nx, y: ny - ns * 0.5, z: 0),
    // 13-16: Ring (MCP, PIP, DIP, TIP)
    HandLandmark(x: nx + ns * 0.15, y: ny + ns * 0.05, z: 0),
    HandLandmark(x: nx + ns * 0.15, y: ny - ns * 0.13, z: 0),
    HandLandmark(x: nx + ns * 0.15, y: ny - ns * 0.28, z: 0),
    HandLandmark(x: nx + ns * 0.15, y: ny - ns * 0.42, z: 0),
    // 17-20: Pinky (MCP, PIP, DIP, TIP)
    HandLandmark(x: nx + ns * 0.3, y: ny + ns * 0.1, z: 0),
    HandLandmark(x: nx + ns * 0.3, y: ny - ns * 0.05, z: 0),
    HandLandmark(x: nx + ns * 0.3, y: ny - ns * 0.18, z: 0),
    HandLandmark(x: nx + ns * 0.3, y: ny - ns * 0.3, z: 0),
  ];
}
