import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/reusable_widgets.dart';
import '../l10n/app_strings.dart';
import '../modules/environmental_alerts/models/environmental_sound.dart';

class EnvironmentalScreen extends StatelessWidget {
  const EnvironmentalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final env = context.watch<EnvironmentalProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final s = AppStrings.of(context);
    final isActive = env.monitoringEnabled;
    final errorText = env.failure?.displayMessage(urdu: s.isUrdu) ?? s.monitoringUnavailable;

    return Scaffold(
      appBar: AppBar(title: Text(s.environmentalTitle)),
      body: ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            color: (isActive ? colors.primary : colors.surfaceContainerHighest).withValues(alpha: .14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      env.isProcessing ? Icons.mic : (env.hasError ? Icons.mic_off : Icons.volume_off),
                      color: env.hasError ? colors.error : (isActive ? colors.primary : colors.onSurfaceVariant),
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            env.hasError
                                ? errorText
                                : (env.isStarting
                                    ? s.startingMonitoring
                                    : (isActive ? s.monitoringActive : s.monitoringOffTitle)),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: env.hasError ? colors.error : (isActive ? colors.primary : colors.onSurfaceVariant),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            env.hasError
                                ? s.monitoringFixAndRetry
                                : (env.isProcessing ? s.monitoringListeningLocally : s.monitoringIsOff),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: env.isStarting || env.isStopping ? null : env.toggleMonitoring,
                    icon: Icon(isActive ? Icons.stop : Icons.play_arrow),
                    label: Text(isActive ? s.stopMonitoring : s.startMonitoring),
                  ),
                ),
                if (env.hasError && env.needsSystemSettings) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: env.openMicrophoneSettings,
                      icon: const Icon(Icons.settings_outlined),
                      label: Text(s.openMicrophoneSettings),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (env.currentAlert != null)
            _ActiveAlertBanner(event: env.currentAlert!, onDismiss: env.dismissAlert, s: s),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    s.alertHistory,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                if (env.alertHistory.isNotEmpty)
                  TextButton(onPressed: env.clearHistory, child: Text(s.clearAll)),
              ],
            ),
          ),
          if (env.alertHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: EmptyState(
                icon: Icons.notifications_none,
                title: s.noAlertsYet,
                subtitle: s.noAlertsDesc,
              ),
            )
          else
            ...env.alertHistory.map(
              (event) => AlertCard(event: event, onDismiss: () => env.dismissAlert(event.id)),
            ),
        ],
      ),
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
    final description = EnvironmentalSound.byType(event.type)?.displayDescription(urdu: s.isUrdu) ?? s.soundDetected;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: severityColor.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: severityColor, width: 2),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notifications_active, color: severityColor, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${EnvironmentalSound.nameFor(event.type, urdu: s.isUrdu)} ${s.detected}', style: TextStyle(fontWeight: FontWeight.w700, color: severityColor)),
                    const SizedBox(height: 4),
                    Text(description),
                    const SizedBox(height: 4),
                    Text('${(event.confidence * 100).toInt()}% ${s.confidence}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDismiss,
              style: ElevatedButton.styleFrom(backgroundColor: severityColor, foregroundColor: Colors.white),
              child: Text(s.dismiss),
            ),
          ),
        ],
      ),
    );
  }
}
