import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/reusable_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final user = context.watch<UserProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Profile Section
          _SectionHeader(title: 'Profile'),
          ListTile(
            leading: CircleAvatar(
              child: Text(user.profile?.avatarEmoji ?? '👤'),
            ),
            title: Text(user.profile?.name ?? 'Set up profile'),
            subtitle: Text(user.profile?.preferredLanguage ?? 'Tap to edit'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showEditProfileDialog(context),
          ),

          // Accessibility Section
          _SectionHeader(title: 'Accessibility'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Reduce eye strain in low light'),
            value: settings.isDarkMode,
            onChanged: (_) => settings.toggleDarkMode(),
          ),
          SwitchListTile(
            title: const Text('High Contrast'),
            subtitle: const Text('Increase contrast for better visibility'),
            value: settings.isHighContrast,
            onChanged: (_) => settings.toggleHighContrast(),
          ),
          SwitchListTile(
            title: const Text('Large Text'),
            subtitle: const Text('Increase overall text size'),
            value: settings.isLargeText,
            onChanged: (_) => settings.toggleLargeText(),
          ),
          SwitchListTile(
            title: const Text('Simplified Language'),
            subtitle: const Text('Use simpler language throughout'),
            value: settings.simplifiedLanguage,
            onChanged: (_) => settings.toggleSimplifiedLanguage(),
          ),
          ListTile(
            title: const Text('Caption Text Size'),
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
          _SectionHeader(title: 'Alert Preferences'),
          SwitchListTile(
            title: const Text('Haptic Alerts'),
            subtitle: const Text('Vibrate for alerts'),
            value: settings.hapticAlerts,
            onChanged: (_) => settings.toggleHapticAlerts(),
          ),
          SwitchListTile(
            title: const Text('Visual Alerts'),
            subtitle: const Text('Show visual alert indicators'),
            value: settings.visualAlerts,
            onChanged: (_) => settings.toggleVisualAlerts(),
          ),
          SwitchListTile(
            title: const Text('Screen Flash Alerts'),
            subtitle: const Text('Flash the screen for alerts'),
            value: settings.screenFlashAlerts,
            onChanged: (_) => settings.toggleScreenFlashAlerts(),
          ),
          SwitchListTile(
            title: const Text('Flashlight Alerts'),
            subtitle: const Text('Use flashlight for alerts'),
            value: settings.flashAlerts,
            onChanged: (_) => settings.toggleFlashAlerts(),
          ),

          // Language
          _SectionHeader(title: 'Language'),
          ListTile(
            title: const Text('Caption Language'),
            subtitle: Text(settings.captionLanguage),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageDialog(context),
          ),

          // Environmental Alerts
          _SectionHeader(title: 'Environmental Alerts'),
          ...settings.allowedAlerts.entries.map((entry) =>
            SwitchListTile(
              title: Text(entry.key),
              value: entry.value,
              onChanged: (_) => settings.toggleAllowedAlert(entry.key),
            ),
          ),

          // Privacy & Retention
          _SectionHeader(title: 'Privacy & Retention'),
          ListTile(
            title: const Text('Default Retention Period'),
            subtitle: Text('${settings.defaultRetentionDays} days'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showRetentionDialog(context),
          ),
          ListTile(
            title: const Text('Delete All Data'),
            subtitle: const Text('Remove all saved sessions, transcripts, and settings'),
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: () => _confirmDeleteAllData(context),
          ),

          // Privacy Info
          _SectionHeader(title: 'Privacy'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: PrivacyNotice(
              text: 'HumSukhan processes audio temporarily and releases it. '
                  'No raw audio is ever stored. '
                  'Saved records contain captions and metadata only. '
                  'Exported files are stored outside HumSukhan.',
            ),
          ),

          // About
          _SectionHeader(title: 'About'),
          const ListTile(
            title: Text('HumSukhan'),
            subtitle: Text('Version 1.0.0 — Accessibility-first AI companion'),
          ),
          const ListTile(
            title: Text('Font'),
            subtitle: Text('Atkinson Hyperlegible — Designed for maximum legibility'),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
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
            Text('Edit Profile', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 24),
            PrimaryActionButton(
              label: 'Save',
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

  void _showLanguageDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Caption Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['English', 'Roman Urdu', 'Urdu'].map((lang) =>
            RadioListTile<String>(
              title: Text(lang),
              value: lang,
              groupValue: settings.captionLanguage,
              onChanged: (v) {
                settings.setCaptionLanguage(v ?? 'English');
                Navigator.pop(ctx);
              },
            ),
          ).toList(),
        ),
      ),
    );
  }

  void _showRetentionDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Default Retention'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: RetentionPolicy.options.map((policy) =>
            RadioListTile<int>(
              title: Text(policy.label),
              subtitle: policy.days == 30 ? const Text('Maximum allowed') : null,
              value: policy.days,
              groupValue: settings.defaultRetentionDays,
              onChanged: (v) {
                settings.setDefaultRetentionDays(v ?? 7);
                Navigator.pop(ctx);
              },
            ),
          ).toList(),
        ),
      ),
    );
  }

  void _confirmDeleteAllData(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data?'),
        content: const Text('This will permanently remove all saved sessions, transcripts, insights, and settings. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All data deleted (demo)')),
              );
            },
            child: const Text('Delete Everything', style: TextStyle(color: Colors.red)),
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
