import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../widgets/reusable_widgets.dart';
import '../l10n/app_strings.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final user = context.watch<UserProvider>();
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.settingsTitle)),
      body: ListView(
        children: [
          // Profile Section
          _SectionHeader(title: s.profile),
          ListTile(
            leading: CircleAvatar(
              child: Text(user.profile?.avatarEmoji ?? '👤'),
            ),
            title: Text(user.profile?.name ?? s.setupProfile),
            subtitle: Text(user.profile?.preferredLanguage ?? s.tapToEdit),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showEditProfileDialog(context, s),
          ),

          // Auth Section
          Consumer<AuthProvider>(
            builder: (_, auth, _a) => Column(
              children: [
                ListTile(
                  leading: Icon(
                    auth.isAuthenticated ? Icons.cloud_done : Icons.cloud_off,
                    color: auth.isAuthenticated ? Colors.green : Colors.grey,
                  ),
                  title: Text(
                    auth.isAuthenticated
                        ? 'Synced with Supabase'
                        : 'Not signed in',
                  ),
                  subtitle: Text(
                    auth.isAuthenticated
                        ? (auth.user?.email ?? 'Anonymous user')
                        : 'Sign in to sync data across devices',
                  ),
                  trailing: auth.isAuthenticated
                      ? TextButton(
                          onPressed: () async {
                            await auth.signOut();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Signed out')),
                              );
                            }
                          },
                          child: const Text('Sign Out'),
                        )
                      : TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/auth'),
                          child: const Text('Sign In'),
                        ),
                ),
              ],
            ),
          ),

          // App Language
          _SectionHeader(title: s.appLanguage),
          ListTile(
            title: Text(s.appLanguage),
            subtitle: Text(settings.appLanguage == 'ur' ? s.languageUrdu : s.languageEnglish),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAppLanguageDialog(context, settings, s),
          ),

          // Accessibility Section
          _SectionHeader(title: s.accessibility),
          SwitchListTile(
            title: Text(s.darkMode),
            subtitle: Text(s.darkModeDesc),
            value: settings.isDarkMode,
            onChanged: (_) => settings.toggleDarkMode(),
          ),
          SwitchListTile(
            title: Text(s.highContrast),
            subtitle: Text(s.highContrastDesc),
            value: settings.isHighContrast,
            onChanged: (_) => settings.toggleHighContrast(),
          ),
          SwitchListTile(
            title: Text(s.largeText),
            subtitle: Text(s.largeTextDesc),
            value: settings.isLargeText,
            onChanged: (_) => settings.toggleLargeText(),
          ),
          SwitchListTile(
            title: Text(s.simplifiedLanguage),
            subtitle: Text(s.simplifiedLanguageDesc),
            value: settings.simplifiedLanguage,
            onChanged: (_) => settings.toggleSimplifiedLanguage(),
          ),
          ListTile(
            title: Text(s.captionTextSize),
            subtitle: Text('${settings.captionTextSize.toInt()} sp'),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                value: settings.captionTextSize,
                min: 16,
                max: 48,
                divisions: 16,
                label: '${settings.captionTextSize.toInt()}',
                onChanged: (v) => settings.setCaptionTextSize(v),
              ),
            ),
          ),

          // Alert Preferences
          _SectionHeader(title: s.alertPreferences),
          SwitchListTile(
            title: Text(s.hapticAlerts),
            subtitle: Text(s.hapticAlertsDesc),
            value: settings.hapticAlerts,
            onChanged: (_) => settings.toggleHapticAlerts(),
          ),
          SwitchListTile(
            title: Text(s.visualAlerts),
            subtitle: Text(s.visualAlertsDesc),
            value: settings.visualAlerts,
            onChanged: (_) => settings.toggleVisualAlerts(),
          ),
          SwitchListTile(
            title: Text(s.screenFlashAlerts),
            subtitle: Text(s.screenFlashAlertsDesc),
            value: settings.screenFlashAlerts,
            onChanged: (_) => settings.toggleScreenFlashAlerts(),
          ),
          SwitchListTile(
            title: Text(s.flashlightAlerts),
            subtitle: Text(s.flashlightAlertsDesc),
            value: settings.flashAlerts,
            onChanged: (_) => settings.toggleFlashAlerts(),
          ),

          // Caption Language
          _SectionHeader(title: s.languageSection),
          ListTile(
            title: Text(s.captionLanguage),
            subtitle: Text(settings.captionLanguage),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageDialog(context, settings, s),
          ),

          // Speech Recognition
          _SectionHeader(title: s.speechRecognition),
          const _SpeechModelsSection(),

          // Environmental Alerts
          _SectionHeader(title: s.environmentalAlerts),
          ...settings.allowedAlerts.entries.map((entry) =>
            SwitchListTile(
              title: Text(entry.key),
              value: entry.value,
              onChanged: (_) => settings.toggleAllowedAlert(entry.key),
            ),
          ),

          // Privacy & Retention
          _SectionHeader(title: '${s.privacySection} & Retention'),
          ListTile(
            title: Text(s.defaultRetentionPeriod),
            subtitle: Text('${settings.defaultRetentionDays} ${s.sessionsCount}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showRetentionDialog(context, settings, s),
          ),
          ListTile(
            title: Text(s.deleteAllData),
            subtitle: Text(s.deleteAllDataDesc),
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: () => _confirmDeleteAllData(context, s),
          ),

          // Privacy Info
          _SectionHeader(title: s.privacySection),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PrivacyNotice(
              text: s.privacyNoticeText,
            ),
          ),

          // About
          _SectionHeader(title: s.aboutSection),
          ListTile(
            title: const Text('HumSukhan'),
            subtitle: Text(s.versionLabel),
          ),
          ListTile(
            title: Text(s.fontLabel),
            subtitle: Text(s.fontDesc),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, AppStrings s) {
    final user = context.read<UserProvider>();
    final nameController = TextEditingController(text: user.profile?.name ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.editProfile, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: s.nameLabel),
            ),
            const SizedBox(height: 24),
            PrimaryActionButton(
              label: s.save,
              icon: Icons.save,
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  if (user.hasProfile) {
                    await user.saveProfile(user.profile!.copyWith(name: nameController.text.trim()));
                  } else {
                    await user.createProfile(name: nameController.text.trim());
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAppLanguageDialog(BuildContext context, SettingsProvider settings, AppStrings s) {
    String selected = settings.appLanguage;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(s.appLanguage),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('English'),
                value: 'en',
                groupValue: selected,
                onChanged: (v) {
                  setModalState(() => selected = v ?? 'en');
                  settings.setAppLanguage('en');
                  Navigator.pop(ctx);
                },
              ),
              RadioListTile<String>(
                title: const Text('اردو (Urdu)'),
                value: 'ur',
                groupValue: selected,
                onChanged: (v) {
                  setModalState(() => selected = v ?? 'ur');
                  settings.setAppLanguage('ur');
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, SettingsProvider settings, AppStrings s) {
    String selected = settings.captionLanguage;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(s.captionLanguage),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['English', 'Roman Urdu', 'Urdu'].map((lang) =>
              RadioListTile<String>(
                title: Text(lang),
                value: lang,
                groupValue: selected,
                onChanged: (v) {
                  setModalState(() => selected = v ?? 'English');
                  settings.setCaptionLanguage(v ?? 'English');
                  Navigator.pop(ctx);
                },
              ),
            ).toList(),
          ),
        ),
      ),
    );
  }

  void _showRetentionDialog(BuildContext context, SettingsProvider settings, AppStrings s) {
    int selected = settings.defaultRetentionDays;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(s.defaultRetention),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<int>(title: Text(s.retention1Day), value: 1, groupValue: selected,
                onChanged: (v) { setModalState(() => selected = v ?? 1); settings.setDefaultRetentionDays(1); Navigator.pop(ctx); }),
              RadioListTile<int>(title: Text(s.retention7Days), value: 7, groupValue: selected,
                onChanged: (v) { setModalState(() => selected = v ?? 7); settings.setDefaultRetentionDays(7); Navigator.pop(ctx); }),
              RadioListTile<int>(title: Text(s.retention15Days), value: 15, groupValue: selected,
                onChanged: (v) { setModalState(() => selected = v ?? 15); settings.setDefaultRetentionDays(15); Navigator.pop(ctx); }),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAllData(BuildContext context, AppStrings s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteAllConfirm),
        content: Text(s.deleteAllConfirmDesc),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Delete from Supabase if authenticated
              if (SupabaseService.instance.isAuthenticated) {
                await DatabaseService.instance.deleteAllUserData();
              }
              // Delete local data
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data deleted')),
                );
              }
            },
            child: Text(s.deleteEverything, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SpeechModelsSection extends StatelessWidget {
  const _SpeechModelsSection();

  @override
  Widget build(BuildContext context) {
    final speech = context.watch<SpeechProvider>();
    final s = AppStrings.of(context);

    return Column(
      children: [
        ListTile(
          leading: Icon(
            speech.isOfflineMode ? Icons.wifi_off : Icons.wifi,
            color: speech.isOfflineMode ? Colors.green : Colors.blue,
          ),
          title: Text(s.currentMode),
          subtitle: Text(speech.sttModeLabel),
          trailing: Text(
            speech.currentLanguage,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Divider(height: 1),

        _ModelTile(
          language: s.englishLabel,
          modelName: 'Zipformer Streaming',
          sizeMB: 80,
          isStreaming: true,
          isReady: speech.isModelReady('English'),
          onDownload: () => speech.downloadOfflineModel('English'),
          onDelete: () => speech.deleteModel('English'),
          s: s,
        ),

        _ModelTile(
          language: s.urduLabel,
          modelName: 'Dolphin CTC',
          sizeMB: 239,
          isStreaming: false,
          isReady: speech.isModelReady('Urdu'),
          onDownload: () => speech.downloadOfflineModel('Urdu'),
          onDelete: () => speech.deleteModel('Urdu'),
          s: s,
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            s.offlineSttDesc,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModelTile extends StatelessWidget {
  final String language;
  final String modelName;
  final int sizeMB;
  final bool isStreaming;
  final bool isReady;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final AppStrings s;

  const _ModelTile({
    required this.language,
    required this.modelName,
    required this.sizeMB,
    required this.isStreaming,
    required this.isReady,
    required this.onDownload,
    required this.onDelete,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isReady
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        child: Icon(
          isReady ? Icons.check_circle : Icons.download,
          color: isReady ? Colors.green : Colors.grey,
          size: 20,
        ),
      ),
      title: Text('$language ($modelName)'),
      subtitle: Text(
        isReady ? '${s.readyLabel} · ${sizeMB}MB' : '${s.notDownloaded} · ${sizeMB}MB',
        style: TextStyle(
          color: isReady ? Colors.green : Colors.grey,
          fontSize: 12,
        ),
      ),
      trailing: isReady
          ? IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('${s.delete} $language Model?'),
                    content: Text(s.deleteModelDesc(sizeMB)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(s.cancel),
                      ),
                      TextButton(
                        onPressed: () {
                          onDelete();
                          Navigator.pop(ctx);
                        },
                        child: Text(s.delete, style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            )
          : TextButton(
              onPressed: onDownload,
              child: Text(s.downloadLabel),
            ),
    );
  }
}
