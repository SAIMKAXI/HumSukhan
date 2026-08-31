import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../providers/speech_provider.dart';
import '../theme/app_theme.dart';
import '../services/psl_recognition_service.dart';

class PslScreen extends StatefulWidget {
  const PslScreen({super.key});
  @override
  State<PslScreen> createState() => _PslScreenState();
}

class _PslScreenState extends State<PslScreen> {
  final PslRecognitionService _psl = PslRecognitionService.instance;
  StreamSubscription? _subscription;
  bool _isInitializing = true;
  bool _cameraReady = false;
  bool _switchingCamera = false;
  String _currentGesture = '';
  String _detectedText = '';
  double _confidence = 0;

  @override
  void initState() {
    super.initState();
    _initializePsl();
  }

  Future<void> _initializePsl() async {
    try {
      final success = await _psl.initialize();
      if (!success || !mounted) {
        if (mounted) setState(() => _isInitializing = false);
        return;
      }
      setState(() {
        _isInitializing = false;
        _cameraReady = true;
      });
      await _psl.startProcessing();
      _subscription = _psl.onResult.listen((result) {
        if (!mounted) return;
        setState(() {
          _currentGesture = result.gestureName;
          _detectedText = result.accumulatedText;
          _confidence = result.confidence;
        });
      });
    } catch (e) {
      debugPrint('PSL screen init error: $e');
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _switchCamera() async {
    if (_switchingCamera || _psl.cameras.length < 2) return;
    setState(() => _switchingCamera = true);
    final ok = await _psl.switchCamera();
    if (mounted) {
      setState(() => _switchingCamera = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to switch camera.')));
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _psl.stopProcessing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraName = _psl.lensDirection == CameraLensDirection.front ? 'Front camera' : 'Back camera';
    return Scaffold(
      appBar: AppBar(
        title: const Text('PSL Recognition'),
        actions: [
          if (_psl.cameras.length > 1)
            IconButton(
              icon: _switchingCamera ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.flip_camera_android),
              onPressed: _switchingCamera ? null : _switchCamera,
              tooltip: 'Switch camera',
            ),
          if (_detectedText.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                _psl.clearText();
                setState(() {
                  _detectedText = '';
                  _currentGesture = '';
                });
              },
              tooltip: 'Clear text',
            ),
        ],
      ),
      body: Column(children: [
        Expanded(flex: 3, child: _buildCameraPreview(cameraName)),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppTokens.deepSage.withValues(alpha: 0.1),
          child: Row(children: [
            Icon(_cameraReady ? Icons.pan_tool : Icons.videocam_off, color: _cameraReady ? AppTokens.deepSage : AppTokens.warning, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(_currentGesture.isNotEmpty ? 'Detected: $_currentGesture' : (_cameraReady ? 'Show your hand · $cameraName' : 'Camera not available'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _cameraReady ? AppTokens.deepSage : AppTokens.warning))),
            if (_confidence > 0) Text('${(_confidence * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTokens.deepSage)),
          ]),
        ),
        Expanded(
          flex: 2,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DETECTED TEXT', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Expanded(child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(AppTokens.radiusMd), border: Border.all(color: AppTokens.borderSage.withValues(alpha: 0.5))),
                child: Text(_detectedText.isEmpty ? 'Recognized sign text will appear here...' : _detectedText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: _detectedText.isEmpty ? AppTokens.textMuted : AppTokens.textDeepForest)),
              )),
            ]),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)))),
          child: Row(children: [
            Expanded(child: Consumer<SpeechProvider>(builder: (_, speech, child) => ElevatedButton.icon(
              onPressed: _detectedText.isNotEmpty ? () => speech.speak(_detectedText) : null,
              icon: Icon(speech.isSpeaking ? Icons.stop : Icons.volume_up, color: Colors.white),
              label: Text(speech.isSpeaking ? 'Stop' : 'Speak', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: speech.isSpeaking ? AppTokens.error : AppTokens.deepSage, minimumSize: const Size(0, 52)),
            ))),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(
              onPressed: _detectedText.isNotEmpty ? () { _psl.clearText(); setState(() { _detectedText = ''; _currentGesture = ''; }); } : null,
              icon: const Icon(Icons.clear_all, color: AppTokens.deepSage),
              label: const Text('Clear', style: TextStyle(color: AppTokens.deepSage, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), side: const BorderSide(color: AppTokens.deepSage)),
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCameraPreview(String cameraName) {
    if (_isInitializing) return Container(color: Colors.black, child: const Center(child: CircularProgressIndicator(color: Colors.white)));
    if (!_cameraReady || _psl.cameraController == null) {
      return Container(color: Colors.black, child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.videocam_off, size: 64, color: Colors.white38), SizedBox(height: 16), Text('Camera not available', style: TextStyle(color: Colors.white70, fontSize: 16))])));
    }
    return Stack(fit: StackFit.expand, children: [
      CameraPreview(_psl.cameraController!),
      Positioned(top: 16, right: 16, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), child: Text(cameraName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)))),
      Center(child: Container(width: 200, height: 200, decoration: BoxDecoration(border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2), borderRadius: BorderRadius.circular(16)), child: const Center(child: Text('Show hand\nhere', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w500))))),
      Positioned(bottom: 16, left: 16, right: 16, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)), child: const Text('Center your hand in the guide. Switch between front and back cameras with the camera button.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)))),
    ]);
  }
}
