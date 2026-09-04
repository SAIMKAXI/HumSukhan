import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  final double radius;
  const BrandLogo({super.key, this.size = 56, this.radius = AppTokens.radiusLg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // The brand mark is a light shape on brand green, exactly like the
        // installed launcher icon. Filling with colorScheme.surface instead
        // dropped the green treatment and left the mark floating on white.
        color: AppTokens.brandIconBackground,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      // assets/icon_mark.png is the adaptive-icon foreground layer, so it
      // carries the 108dp-canvas safe-zone padding. Android shows only the
      // centre 72dp of that canvas, so scale by 108/72 to reproduce the
      // launcher icon's framing instead of a mark that looks too small.
      child: Transform.scale(
        scale: 1.5,
        child: Image.asset('assets/icon_mark.png', fit: BoxFit.contain),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  const StatusPill({super.key, required this.label, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final tone = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
        border: Border.all(color: tone.withValues(alpha: .14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tone),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: tone)),
        ],
      ),
    );
  }
}

class ModernSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const ModernSectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class ModernModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String eyebrow;
  final IconData icon;
  final VoidCallback onTap;
  final bool emphasized;
  final Widget? trailing;
  const ModernModeCard({super.key, required this.title, required this.subtitle, required this.eyebrow, required this.icon, required this.onTap, this.emphasized = false, this.trailing});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bg = emphasized ? colors.primary : colors.surface;
    final fg = emphasized ? colors.onPrimary : colors.onSurface;
    final muted = emphasized ? colors.onPrimary.withValues(alpha: .72) : colors.onSurfaceVariant;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppTokens.radiusXl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        child: Container(
          constraints: const BoxConstraints(minHeight: 136),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusXl),
            border: Border.all(color: emphasized ? colors.primary : colors.outline.withValues(alpha: .55)),
            boxShadow: emphasized ? [BoxShadow(color: colors.primary.withValues(alpha: .16), blurRadius: 24, offset: const Offset(0, 10))] : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: emphasized ? colors.onPrimary.withValues(alpha: .12) : colors.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                ),
                child: Icon(icon, color: emphasized ? fg : colors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eyebrow.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: muted, letterSpacing: 1.1)),
                    const SizedBox(height: 6),
                    Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: fg)),
                    const SizedBox(height: 6),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
                  ],
                ),
              ),
              trailing ?? Icon(Icons.arrow_forward_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

class PrivacyStrip extends StatelessWidget {
  final String text;
  const PrivacyStrip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: colors.primary.withValues(alpha: .14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, size: 18, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.45))),
        ],
      ),
    );
  }
}
