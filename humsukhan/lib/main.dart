import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/providers.dart';
import 'theme/app_theme.dart';
import 'navigation/app_router.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/main_scaffold.dart';
import 'l10n/app_strings.dart';
import 'services/supabase_service.dart';
import 'services/sound_detection_service.dart';

@pragma('vm:entry-point')
Future<void> environmentalMonitoringBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.humsukhan/environmental_monitor');
  final detector = SoundDetectionService.instance;
  var pcmFlowSignaled = false;

  channel.setMethodCallHandler((call) async {
    if (call.method == 'stop') {
      pcmFlowSignaled = false;
      detector.stopMonitoring();
      await channel.invokeMethod('pipelineState', {'state': 'OFF'});
      return true;
    }
    if (call.method == 'audioData') {
      final raw = call.arguments;
      if (raw is Uint8List && raw.lengthInBytes >= 2) {
        detector.processExternalAudio(raw);
        if (!pcmFlowSignaled) {
          pcmFlowSignaled = true;
          await channel.invokeMethod('pipelineState', {
            'state': 'PCM_FLOWING',
            'bytes': raw.lengthInBytes,
          });
        }
      }
      return true;
    }
    return null;
  });

  detector.onSoundDetected = (event) {
    channel.invokeMethod('event', <String, dynamic>{
      'type': event.type,
      'confidence': event.confidence,
      'severity': event.severity,
      'timestamp': event.timestamp.toIso8601String(),
    });
  };

  final started = await detector.startExternalMonitoring(permissionAlreadyGranted: true);
  await channel.invokeMethod('pipelineState', {'state': started ? 'READY' : 'ERROR'});
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HumSukhanApp());
}

class HumSukhanApp extends StatefulWidget {
  const HumSukhanApp({super.key});
  @override
  State<HumSukhanApp> createState() => _HumSukhanAppState();
}

class _HumSukhanAppState extends State<HumSukhanApp> {
  late final AuthProvider _authProvider;
  bool _showSplash = true;
  String _lastLanguage = 'en';
  String? _lastSyncedSettingsUserId;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider()..addListener(_handleAuthChanged);
    unawaited(_initializeStartupServices());
  }

  Future<void> _initializeStartupServices() async {
    try {
      await SupabaseService.instance.initialize().timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Supabase startup initialization failed: $e');
    }

    if (!mounted) return;
    _authProvider.refresh();
  }

  void _handleAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _authProvider.removeListener(_handleAuthChanged);
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
      ],
      child: MaterialApp(
        title: 'HumSukhan',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppStrings.supportedLocales,
        home: _showSplash ? SplashScreen(onFinished: () => setState(() => _showSplash = false)) : const OnboardingScreen(),
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
