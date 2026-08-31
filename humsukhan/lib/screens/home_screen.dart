import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/reusable_widgets.dart';
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
    final profileName = profile?.name ??
        auth.user?.userMetadata?['name']?.toString().trim() ??
        'there';
    final s = AppStrings.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.scaffoldBackgroundColor, colors.surfaceContainerHighest],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTokens.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppTokens.lg),
                Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_timeGreeting(s)}, $profileName',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.yourCompanion,
                            style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: connectivity.isOnline
                            ? colors.primary.withValues(alpha: 0.1)
                            : colors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            connectivity.isOnline ? Icons.wifi : Icons.wifi_off,
                            size: 12,
                            color: connectivity.isOnline ? colors.primary : colors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            connectivity.statusLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: connectivity.isOnline ? colors.primary : colors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.xl),
                Text(
                  s.quickActions,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurfaceVariant,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: AppTokens.md),
                _ActionCard(
                  title: s.everydayMode,
                  subtitle: s.startConversation,
                  icon: Icons.chat_bubble_outline,
                  onTap: () => Navigator.pushNamed(context, '/everyday'),
                ),
                const SizedBox(height: AppTokens.sm),
                _ActionCard(
                  title: s.professionalMode,
                  subtitle: s.startMeetingLecture,
                  icon: Icons.work_outline,
                  onTap: () => Navigator.pushNamed(context, '/professional'),
                ),
                const SizedBox(height: AppTokens.sm),
                _ActionCard(
                  title: s.environmentalAlerts,
                  subtitle: environmental.monitoringEnabled ? s.monitoringActive : s.monitoringOff,
                  icon: Icons.volume_up,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: environmental.monitoringEnabled
                          ? colors.primary.withValues(alpha: 0.15)
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                    ),
                    child: Text(
                      environmental.monitoringEnabled ? 'ON' : 'OFF',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: environmental.monitoringEnabled
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  onTap: () => Navigator.pushNamed(context, '/environmental'),
                ),
                const SizedBox(height: AppTokens.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      s.recentSessions,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurfaceVariant,
                        letterSpacing: 1.5,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/professional'),
                      child: Text(s.viewAll),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.sm),
                if (professional.recentSessions.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.event_note, color: colors.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              s.noRecentSessions,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...professional.recentSessions.map(
                    (session) => SessionCard(
                      session: session,
                      insight: professional.getInsightForSession(session.id),
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/session/detail',
                        arguments: session.id,
                      ),
                    ),
                  ),
                const SizedBox(height: AppTokens.xl),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield, size: 18, color: colors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.privacyNote,
                          style: theme.textTheme.bodySmall?.copyWith(color: colors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.lg),
              ],
            ),
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

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Icon(icon, color: colors.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              trailing ?? Icon(Icons.chevron_right, color: colors.onSurfaceVariant, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
