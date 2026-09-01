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
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1100), vsync: this);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: .88, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _navigationTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) widget.onComplete();
    });
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark),
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
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BrandLogo(size: 132, radius: AppTokens.radiusXl),
                      const SizedBox(height: 28),
                      Text('HumSukhan', style: theme.textTheme.displaySmall?.copyWith(color: colors.primary)),
                      const SizedBox(height: 8),
                      Text(AppStrings.of(context).appTagline, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
                      const SizedBox(height: 32),
                      SizedBox(width: 88, child: ClipRRect(borderRadius: BorderRadius.circular(AppTokens.radiusFull), child: const LinearProgressIndicator(minHeight: 4))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
