import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/reusable_widgets.dart';
import '../navigation/app_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final professional = context.watch<ProfessionalProvider>();
    final environmental = context.watch<EnvironmentalProvider>();
    final profile = user.profile;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const SizedBox(height: AppTheme.spacingMD),
              Text(
                'HumSukhan',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                'Good ${_timeGreeting()}, ${profile?.name ?? 'there'}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                'Your accessibility companion',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),

              // Quick Actions
              Text(
                'QUICK ACTIONS',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),

              // Everyday Mode Card
              _QuickActionCard(
                title: 'Everyday Mode',
                subtitle: 'Start a Conversation',
                icon: Icons.chat_bubble_outline,
                color: AppTheme.primaryLight,
                onTap: () => Navigator.pushNamed(context, AppRouter.everyday),
              ),
              const SizedBox(height: AppTheme.spacingSM),

              // Professional Mode Card
              _QuickActionCard(
                title: 'Professional Mode',
                subtitle: 'Start a Meeting / Lecture',
                icon: Icons.work_outline,
                color: AppTheme.secondaryLight,
                onTap: () => Navigator.pushNamed(context, AppRouter.professional),
              ),
              const SizedBox(height: AppTheme.spacingSM),

              // Environmental Alerts Card
              _QuickActionCard(
                title: 'Environmental Alerts',
                subtitle: environmental.monitoringEnabled ? 'Monitoring active' : 'Monitoring off',
                icon: Icons.volume_up,
                color: environmental.monitoringEnabled ? AppTheme.successLight : Colors.grey,
                onTap: () => Navigator.pushNamed(context, AppRouter.environmental),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: environmental.monitoringEnabled
                        ? AppTheme.successLight.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    environmental.monitoringEnabled ? 'ON' : 'OFF',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: environmental.monitoringEnabled ? AppTheme.successLight : Colors.grey,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spacingXL),

              // Recent Sessions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RECENT SESSIONS',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      letterSpacing: 1.2,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, AppRouter.professional),
                    child: const Text('View all'),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingSM),

              if (professional.recentSessions.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.event_note, color: Colors.grey[400]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No recent sessions. Start a Professional session when you are ready.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...professional.recentSessions.map((session) =>
                  SessionCard(
                    session: session,
                    insight: professional.getInsightForSession(session.id),
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRouter.sessionDetail,
                      arguments: session.id,
                    ),
                  ),
                ),

              const SizedBox(height: AppTheme.spacingXL),

              // Privacy Note
              const PrivacyNotice(
                text: 'Listening begins only when you start. Audio is processed temporarily and released. Raw audio is never stored.',
              ),

              const SizedBox(height: AppTheme.spacingLG),
            ],
          ),
        ),
      ),
    );
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (trailing != null) trailing! else Icon(
                Icons.chevron_right,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
