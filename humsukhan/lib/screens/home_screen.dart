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
    final professional = context.watch<ProfessionalProvider>();
    final environmental = context.watch<EnvironmentalProvider>();
    final connectivity = context.watch<ConnectivityProvider>();
    final profile = user.profile;
    final s = AppStrings.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTokens.warmIvory, AppTokens.softCream],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTokens.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppTokens.lg),

                // Logo + Header
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTokens.deepSage.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_timeGreeting(s)}, ${profile?.name ?? 'there'}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppTokens.textDeepForest,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.yourCompanion,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Connectivity status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: connectivity.isOnline
                            ? AppTokens.deepSage.withValues(alpha: 0.1)
                            : AppTokens.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            connectivity.isOnline ? Icons.wifi : Icons.wifi_off,
                            size: 12,
                            color: connectivity.isOnline ? AppTokens.deepSage : AppTokens.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            connectivity.statusLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: connectivity.isOnline ? AppTokens.deepSage : AppTokens.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppTokens.xl),

                // Quick Actions
                Text(
                  s.quickActions,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.textMuted,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: AppTokens.md),

                // Everyday Mode
                _ActionCard(
                  title: s.everydayMode,
                  subtitle: s.startConversation,
                  icon: Icons.chat_bubble_outline,
                  onTap: () => Navigator.pushNamed(context, '/everyday'),
                ),
                const SizedBox(height: AppTokens.sm),

                // Professional Mode
                _ActionCard(
                  title: s.professionalMode,
                  subtitle: s.startMeetingLecture,
                  icon: Icons.work_outline,
                  onTap: () => Navigator.pushNamed(context, '/professional'),
                ),
                const SizedBox(height: AppTokens.sm),

                // Environmental Alerts
                _ActionCard(
                  title: s.environmentalAlerts,
                  subtitle: environmental.monitoringEnabled ? s.monitoringActive : s.monitoringOff,
                  icon: Icons.volume_up,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: environmental.monitoringEnabled
                          ? AppTokens.deepSage.withValues(alpha: 0.15)
                          : AppTokens.mutedSageGray.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                    ),
                    child: Text(
                      environmental.monitoringEnabled ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: environmental.monitoringEnabled ? AppTokens.deepSage : AppTokens.textMuted,
                      ),
                    ),
                  ),
                  onTap: () => Navigator.pushNamed(context, '/environmental'),
                ),

                const SizedBox(height: AppTokens.xl),

                // Recent Sessions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      s.recentSessions,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTokens.textMuted,
                        letterSpacing: 1.5,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/professional'),
                      child: Text(s.viewAll, style: const TextStyle(color: AppTokens.deepSage)),
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
                          Icon(Icons.event_note, color: AppTokens.mutedSageGray),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              s.noRecentSessions,
                              style: const TextStyle(color: AppTokens.textMuted, fontSize: 14),
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
                      onTap: () => Navigator.pushNamed(context, '/session/detail', arguments: session.id),
                    ),
                  ),

                const SizedBox(height: AppTokens.xl),

                // Privacy Note
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTokens.deepSage.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    border: Border.all(color: AppTokens.deepSage.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield, size: 18, color: AppTokens.deepSage),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.privacyNote,
                          style: const TextStyle(fontSize: 12, color: AppTokens.deepSage),
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
                  color: AppTokens.deepSage.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Icon(icon, color: AppTokens.deepSage, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: AppTokens.textDeepForest,
                    )),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(
                      fontSize: 13, color: AppTokens.textSecondary,
                    )),
                  ],
                ),
              ),
              if (trailing != null) trailing! else const Icon(
                Icons.chevron_right, color: AppTokens.mutedSageGray, size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
