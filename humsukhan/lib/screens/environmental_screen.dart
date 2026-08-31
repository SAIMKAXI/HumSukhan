import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/reusable_widgets.dart';
import '../l10n/app_strings.dart';

class EnvironmentalScreen extends StatelessWidget {
  const EnvironmentalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final env = context.watch<EnvironmentalProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final s = AppStrings.of(context);
    final isActive = env.monitoringEnabled;

    return Scaffold(
      appBar: AppBar(title: Text(s.environmentalTitle)),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: (isActive ? colors.primary : colors.surfaceContainerHighest).withValues(alpha: .14),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(env.isProcessing ? Icons.mic : (env.hasError ? Icons.mic_off : Icons.volume_off), color: env.hasError ? colors.error : (isActive ? colors.primary : colors.onSurfaceVariant), size: 32),
              const SizedBox(width: 12),
              Text(env.hasError ? 'Microphone unavailable' : (env.isStarting ? 'Starting monitoring…' : (isActive ? 'Monitoring active' : s.monitoringOffTitle)), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: env.hasError ? colors.error : (isActive ? colors.primary : colors.onSurfaceVariant))),
            ]),
            const SizedBox(height: 8),
            Text(env.hasError ? 'Allow microphone access and try again.' : (env.isProcessing ? 'HumSukhan is listening for supported environmental sounds.' : 'Environmental monitoring is off.'), textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: env.isStarting || env.isStopping ? null : env.toggleMonitoring, icon: Icon(isActive ? Icons.stop : Icons.play_arrow), label: Text(isActive ? s.stopMonitoring : s.startMonitoring))),
          ]),
        ),
        if (env.currentAlert != null) _ActiveAlertBanner(event: env.currentAlert!, onDismiss: env.dismissAlert, s: s),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(s.alertHistory, style: theme.textTheme.labelLarge?.copyWith(color: theme.textTheme.bodySmall?.color, letterSpacing: 1.2)),
          if (env.alertHistory.isNotEmpty) TextButton(onPressed: env.clearHistory, child: Text(s.clearAll)),
        ])),
        Expanded(child: env.alertHistory.isEmpty ? EmptyState(icon: Icons.notifications_none, title: s.noAlertsYet, subtitle: s.noAlertsDesc) : ListView.builder(itemCount: env.alertHistory.length, itemBuilder: (_, index) {
          final event = env.alertHistory.reversed.toList()[index];
          return AlertCard(event: event, onDismiss: env.dismissAlert);
        })),
      ]),
    );
  }
}

class _ActiveAlertBanner extends StatelessWidget {
  final SoundEvent event;
  final VoidCallback onDismiss;
  final AppStrings s;
  const _ActiveAlertBanner({required this.event, required this.onDismiss, required this.s});

  @override
  Widget build(BuildContext context) {
    final severityColor = AppTheme.alertColor(event.severity);
    final description = EnvironmentalProvider.alertDescriptions[event.type] ?? 'A sound was detected.';
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: severityColor.withValues(alpha: .1), borderRadius: BorderRadius.circular(AppTokens.radiusMd), border: Border.all(color: severityColor, width: 2)),
      child: Column(children: [
        Row(children: [Icon(Icons.notifications_active, color: severityColor, size: 30), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${event.type} ${s.detected}', style: TextStyle(fontWeight: FontWeight.w700, color: severityColor)), const SizedBox(height: 4), Text(description), const SizedBox(height: 4), Text('${(event.confidence * 100).toInt()}% ${s.confidence}', style: Theme.of(context).textTheme.bodySmall)]))]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onDismiss, style: ElevatedButton.styleFrom(backgroundColor: severityColor, foregroundColor: Colors.white), child: Text(s.dismiss))),
      ]),
    );
  }
}
