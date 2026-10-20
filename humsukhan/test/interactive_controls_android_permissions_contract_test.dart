import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('onboarding completion shows a disabled control rather than a no-op button', () {
    final onboarding = File('lib/screens/onboarding_screen.dart').readAsStringSync();
    final widgets = File('lib/widgets/reusable_widgets.dart').readAsStringSync();

    expect(onboarding, contains('onPressed: null,'));
    expect(onboarding, isNot(contains('onPressed: () {},')));
    expect(widgets, contains('final VoidCallback? onPressed;'));
  });

  test('Everyday speech button can stop playback while the engine is busy', () {
    final everyday = File('lib/screens/everyday_screen.dart').readAsStringSync();

    expect(everyday, contains('onPressed: speech.isSpeaking'));
    expect(everyday, contains('? () => _speakOrStop(speech, typedResponse)'));
    expect(everyday, contains("tooltip: speech.isSpeaking ? 'Stop speaking' : 'Speak response'"));
  });

  test('Android declares microphone foreground-service and optional torch hardware permissions', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('android.permission.RECORD_AUDIO'));
    expect(manifest, contains('android.permission.FOREGROUND_SERVICE'));
    expect(manifest, contains('android.permission.FOREGROUND_SERVICE_MICROPHONE'));
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('android.permission.CAMERA'));
    expect(manifest, contains('android.hardware.camera.flash" android:required="false"'));
  });

  test('native torch channel checks camera permission and reports actual operation status', () {
    final activity = File('android/app/src/main/kotlin/com/humsukhan/humsukhan/MainActivity.kt').readAsStringSync();

    expect(activity, contains('checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED'));
    expect(activity, contains('result.error("CAMERA_PERMISSION"'));
    expect(activity, contains('if (turnOnTorch())'));
    expect(activity, contains('result.error("TORCH_UNAVAILABLE", "The flashlight could not be turned on", null)'));
    expect(activity, contains('if (turnOffTorch()) result.success(true)'));
    expect(activity, contains('private fun turnOnTorch(): Boolean'));
    expect(activity, contains('private fun turnOffTorch(): Boolean'));
    expect(activity, isNot(contains('"turnOn" -> { turnOnTorch(); result.success(true) }')));
  });

  test('flashlight preference requests permission and only enables on supported Android devices', () {
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();
    final alerts = File('lib/services/alert_service.dart').readAsStringSync();

    expect(settings, contains('Permission.camera.request()'));
    expect(settings, contains("invokeMethod<bool>('isAvailable')"));
    expect(settings, contains('defaultTargetPlatform == TargetPlatform.android'));
    expect(alerts, contains('if (!Platform.isAndroid) return;'));
    expect(alerts, contains('Permission.camera.status'));
    expect(alerts, contains("invokeMethod<bool>('turnOn')"));
  });
}
