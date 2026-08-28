import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/reusable_widgets.dart';

class EnvironmentalScreen extends StatelessWidget {
  const EnvironmentalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final env = context.watch<EnvironmentalProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Environmental Alerts'),
      ),
      body: Column(
        children: [
          // Monitoring Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: env.monitoringEnabled
                ? AppTheme.successLight.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      env.monitoringEnabled ? Icons.volume_up : Icons.volume_off,
                      color: env.monitoringEnabled ? AppTheme.successLight : Colors.grey,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      env.monitoringEnabled ? 'Monitoring Active' : 'Monitoring Off',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: env.monitoringEnabled ? AppTheme.successLight : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => env.toggleMonitoring(),
                    icon: Icon(env.monitoringEnabled ? Icons.stop : Icons.play_arrow),
                    label: Text(env.monitoringEnabled ? 'Stop Monitoring' : 'Start Monitoring'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: env.monitoringEnabled ? AppTheme.errorLight : AppTheme.successLight,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Quick demo alerts
          if (env.monitoringEnabled) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DEMO ALERTS',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: EnvironmentalProvider.alertDescriptions.keys.map((type) =>
                      ActionChip(
                        avatar: Icon(_alertIcon(type), size: 16),
                        label: Text(type, style: const TextStyle(fontSize: 12)),
                        onPressed: () => env.simulateAlert(type),
                      ),
                    ).toList(),
                  ),
                ],
              ),
            ),
            const Divider(),
          ],

          // Active Alert Overlay
          if (env.currentAlert != null)
            _ActiveAlertBanner(event: env.currentAlert!, onDismiss: () => env.dismissAlert()),

          // Alert History Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ALERT HISTORY',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    letterSpacing: 1.2,
                  ),
                ),
                if (env.alertHistory.isNotEmpty)
                  TextButton(
                    onPressed: () => env.clearHistory(),
                    child: const Text('Clear All'),
                  ),
              ],
            ),
          ),

          // Alert History List
          Expanded(
            child: env.alertHistory.isEmpty
                ? const EmptyState(
                    icon: Icons.notifications_none,
                    title: 'No alerts yet',
                    subtitle: 'Alert history will appear here when sounds are detected.',
                  )
                : ListView.builder(
                    itemCount: env.alertHistory.length,
                    itemBuilder: (context, index) {
                      final event = env.alertHistory.reversed.toList()[index];
                      return AlertCard(
                        event: event,
                        onDismiss: () => env.dismissAlert(),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _alertIcon(String type) {
    switch (type) {
      case 'Fire Alarm':
      case 'Smoke Alarm':
        return Icons.local_fire_department;
      case 'Siren':
        return Icons.emergency;
      case 'Doorbell':
        return Icons.doorbell;
      case 'Knock':
        return Icons.back_hand;
      case 'Phone':
        return Icons.phone;
      case 'Alarm Clock':
        return Icons.alarm;
      case 'Baby Cry':
        return Icons.child_care;
      default:
        return Icons.volume_up;
    }
  }
}

class _ActiveAlertBanner extends StatelessWidget {
  final SoundEvent event;
  final VoidCallback onDismiss;

  const _ActiveAlertBanner({required this.event, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final severityColor = AppTheme.alertColor(event.severity);
    final description = EnvironmentalProvider.alertDescriptions[event.type] ?? 'Unknown sound detected.';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: severityColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: severityColor, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.volume_up, color: severityColor, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${event.type.toUpperCase()} DETECTED',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: severityColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(description, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${(event.confidence * 100).toInt()}% confidence',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: severityColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Dismiss'),
            ),
          ),
        ],
      ),
    );
  }
}
