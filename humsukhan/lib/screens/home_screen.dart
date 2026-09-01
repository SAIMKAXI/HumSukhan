import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/reusable_widgets.dart';
import '../widgets/modern_ui.dart';
import '../l10n/app_strings.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final auth = context.watch<AuthProvider>();
    final professional = context.watch<ProfessionalProvider>();
    final environmental = context.watch<EnvironmentalProvider>();
    final connectivity = context.watch<ConnectivityProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final profile = user.profile;
    final profileName = profile?.name ?? auth.user?.userMetadata?['name']?.toString().trim() ?? 'there';
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            const BrandLogo(size: 40, radius: AppTokens.radiusMd),
            const SizedBox(width: 12),
            Expanded(child: Text(s.appName)),
            StatusPill(
              label: connectivity.statusLabel,
              icon: connectivity.isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: connectivity.isOnline ? colors.primary : colors.error,
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_timeGreeting(s)},', style: theme.textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(profileName, style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(s.yourCompanion, style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 28),

              Text(s.quickActions, style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 1.2)),
              const SizedBox(height: 12),
              ModernModeCard(
                eyebrow: 'Everyday',
                title: s.everydayMode,
                subtitle: s.startConversation,
                icon: Icons.forum_rounded,
                emphasized: true,
                onTap: () => Navigator.pushNamed(context, '/everyday'),
              ),
              const SizedBox(height: 12),
              ModernModeCard(
                eyebrow: 'Work & study',
                title: s.professionalMode,
                subtitle: s.startMeetingLecture,
                icon: Icons.work_rounded,
                onTap: () => Navigator.pushNamed(context, '/professional'),
              ),
              const SizedBox(height: 12),
              ModernModeCard(
                eyebrow: 'Always aware',
                title: s.environmentalAlerts,
                subtitle: environmental.monitoringEnabled ? s.monitoringActive : s.monitoringOff,
                icon: Icons.notifications_rounded,
                trailing: StatusPill(
                  label: environmental.monitoringEnabled ? 'ON' : 'OFF',
                  icon: environmental.monitoringEnabled ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                  color: environmental.monitoringEnabled ? colors.primary : colors.onSurfaceVariant,
                ),
                onTap: () => Navigator.pushNamed(context, '/environmental'),
              ),

              const SizedBox(height: 32),
              ModernSectionHeader(
                title: s.recentSessions,
                actionLabel: s.viewAll,
                onAction: () => Navigator.pushNamed(context, '/professional'),
              ),
              const SizedBox(height: 12),
              if (professional.recentSessions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppTokens.radiusXl),
                    border: Border.all(color: colors.outline.withValues(alpha: .55)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(color: colors.primary.withValues(alpha: .08), shape: BoxShape.circle),
                        child: Icon(Icons.auto_awesome_rounded, color: colors.primary, size: 28),
                      ),
                      const SizedBox(height: 16),
                      Text('Your workspace is ready', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(s.noRecentSessions, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                    ],
                  ),
                )
              else
                ...professional.recentSessions.map(
                  (session) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SessionCard(
                      session: session,
                      insight: professional.getInsightForSession(session.id),
                      onTap: () => Navigator.pushNamed(context, '/session/detail', arguments: session.id),
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              PrivacyStrip(text: s.privacyNote),
            ],
          ),
        ),
      ),
    );
  }

  String _timeGreeting(AppStrings s) {
    final hour = DateTime.now().hour;
    if (hour < 12) return s.goodMorning;
    if (hour < 17) return s.goodAfternoon;
    return s.goodEvening;
  }
}
