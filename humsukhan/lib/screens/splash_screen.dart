import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../l10n/app_strings.dart';
import '../widgets/modern_ui.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 2200);

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _navigationTimer;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: .92, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
    _navigationTimer = Timer(_duration, _completeOnce);
  }

  void _completeOnce() {
    if (_completed || !mounted) return;
    _completed = true;
    widget.onComplete();
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final s = AppStrings.of(context);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final content = Semantics(
      container: true,
      label: '${s.appName} startup',
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandLogo(size: 132, radius: AppTokens.radiusXl),
          const SizedBox(height: 28),
          Text(s.appName, style: theme.textTheme.displaySmall?.copyWith(color: colors.primary)),
          const SizedBox(height: 8),
          Text(
            s.appTagline,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          Semantics(
            label: s.loading,
            child: SizedBox(
              width: 88,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                child: const LinearProgressIndicator(minHeight: 4),
              ),
            ),
          ),
        ],
      ),
    );

    final animatedContent = reduceMotion
        ? content
        : FadeTransition(
            opacity: _fade,
            child: ScaleTransition(scale: _scale, child: content),
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: theme.brightness == Brightness.dark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [theme.scaffoldBackgroundColor, colors.primary.withValues(alpha: .08)],
            ),
          ),
          child: Center(child: animatedContent),
        ),
      ),
    );
  }
}
