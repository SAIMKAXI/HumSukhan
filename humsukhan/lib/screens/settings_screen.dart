import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.settingsTitle)),
      body: ListView(children: [
        _SectionHeader(title: s.profile),
        ListTile(
          leading: _Avatar(profile: user.profile, radius: 24),
          title: Text(user.profile?.name ?? s.setupProfile),
          subtitle: Text(user.profile?.preferredLanguage ?? s.tapToEdit),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showEditProfileDialog(context, s),
        ),
        Consumer<AuthProvider>(builder: (_, auth, __) => ListTile(
          leading: Icon(auth.isAuthenticated ? Icons.cloud_done : Icons.cloud_off, color: auth.isAuthenticated ? theme.colorScheme.primary : theme.colorScheme.outline),
          title: Text(auth.isAuthenticated ? s.syncedWithSupabase : s.notSignedIn),
          subtitle: Text(auth.isAuthenticated ? (auth.user?.email ?? s.signedInAccount) : s.signInToSync),
          trailing: TextButton(
            onPressed: auth.isAuthenticated ? auth.signOut : () => Navigator.pushNamed(context, '/auth'),
            child: Text(auth.isAuthenticated ? s.signOut : s.signIn),
          ),
        )),
        _SectionHeader(title: s.appLanguage),
        ListTile(title: Text(s.appLanguage), subtitle: Text(settings.appLanguage == 'ur' ? s.languageUrdu : s.languageEnglish), trailing: const Icon(Icons.chevron_right), onTap: () => _showAppLanguageDialog(context, settings, s)),
        _SectionHeader(title: s.accessibility),
        SwitchListTile(title: Text(s.darkMode), subtitle: Text(s.darkModeDesc), value: settings.isDarkMode, onChanged: (_) => settings.toggleDarkMode()),
        SwitchListTile(title: Text(s.highContrast), subtitle: Text(s.highContrastDesc), value: settings.isHighContrast, onChanged: (_) => settings.toggleHighContrast()),
        SwitchListTile(title: Text(s.largeText), subtitle: Text(s.largeTextDesc), value: settings.isLargeText, onChanged: (_) => settings.toggleLargeText()),
        SwitchListTile(title: Text(s.simplifiedLanguage), subtitle: Text(s.simplifiedLanguageDesc), value: settings.simplifiedLanguage, onChanged: (_) => settings.toggleSimplifiedLanguage()),
        ListTile(
          title: Text(s.captionTextSize),
          subtitle: Text('${settings.captionTextSize.toInt()} sp'),
          trailing: SizedBox(width: 190, child: Slider(value: settings.captionTextSize, min: 16, max: 48, divisions: 16, label: '${settings.captionTextSize.toInt()}', onChanged: settings.setCaptionTextSize)),
        ),
        _SectionHeader(title: s.alertPreferences),
        SwitchListTile(title: Text(s.hapticAlerts), subtitle: Text(s.hapticAlertsDesc), value: settings.hapticAlerts, onChanged: (_) => settings.toggleHapticAlerts()),
        SwitchListTile(title: Text(s.visualAlerts), subtitle: Text(s.visualAlertsDesc), value: settings.visualAlerts, onChanged: (_) => settings.toggleVisualAlerts()),
        SwitchListTile(title: Text(s.screenFlashAlerts), subtitle: Text(s.screenFlashAlertsDesc), value: settings.screenFlashAlerts, onChanged: (_) => settings.toggleScreenFlashAlerts()),
        SwitchListTile(title: Text(s.flashlightAlerts), subtitle: Text(s.flashlightAlertsDesc), value: settings.flashAlerts, onChanged: (_) => settings.toggleFlashAlerts()),
        _SectionHeader(title: s.languageSection),
        ListTile(title: Text(s.captionLanguage), subtitle: Text(settings.captionLanguage), trailing: const Icon(Icons.chevron_right), onTap: () => _showLanguageDialog(context, settings, s)),
        _SectionHeader(title: s.speechRecognition),
        const _SpeechModelsSection(),
        _SectionHeader(title: s.environmentalAlerts),
        ...settings.allowedAlerts.entries.map((entry) => SwitchListTile(title: Text(entry.key), value: entry.value, onChanged: (_) => settings.toggleAllowedAlert(entry.key))),
        _SectionHeader(title: '${s.privacySection} & ${s.defaultRetention}'),
        ListTile(title: Text(s.defaultRetentionPeriod), subtitle: Text('${settings.defaultRetentionDays} ${s.days}'), trailing: const Icon(Icons.chevron_right), onTap: () => _showRetentionDialog(context, settings, s)),
        ListTile(title: Text(s.deleteAllData), subtitle: Text(s.deleteAllDataDesc), leading: Icon(Icons.delete_forever, color: theme.colorScheme.error), onTap: () => _confirmDeleteAllData(context, s)),
        _SectionHeader(title: s.privacySection),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: PrivacyNotice(text: s.privacyNoticeText)),
        _SectionHeader(title: s.aboutSection),
        const _AboutSection(),
        const SizedBox(height: 32),
      ]),
    );
  }

  Future<void> _showEditProfileDialog(BuildContext context, AppStrings s) async {
    final user = context.read<UserProvider>();
    final nameController = TextEditingController(text: user.profile?.name ?? '');
    String? avatarData = user.profile?.avatarData;
    final picker = ImagePicker();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) => Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(s.editProfile, style: Theme.of(ctx).textTheme.headlineSmall),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () async {
              final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 82);
              if (file == null) return;
              final bytes = await file.readAsBytes();
              setModalState(() => avatarData = base64Encode(bytes));
            },
            child: Stack(alignment: Alignment.bottomRight, children: [
              _Avatar(profile: user.profile?.copyWith(avatarData: avatarData), radius: 46),
              CircleAvatar(radius: 16, backgroundColor: Theme.of(ctx).colorScheme.primary, child: const Icon(Icons.camera_alt, size: 16)),
            ]),
          ),
          const SizedBox(height: 16),
          TextField(controller: nameController, decoration: InputDecoration(labelText: s.nameLabel)),
          const SizedBox(height: 20),
          PrimaryActionButton(label: s.save, icon: Icons.save, onPressed: () async {
            final name = nameController.text.trim();
            if (name.isEmpty) return;
            final base = user.profile ?? UserProfile(name: name);
            await user.saveProfile(base.copyWith(name: name, avatarData: avatarData));
            if (ctx.mounted) Navigator.pop(ctx);
          }),
        ]),
      )),
    );
    nameController.dispose();
  }

  void _showAppLanguageDialog(BuildContext context, SettingsProvider settings, AppStrings s) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(s.appLanguage), content: Column(mainAxisSize: MainAxisSize.min, children: [
      RadioListTile<String>(title: Text(s.languageEnglish), value: 'en', groupValue: settings.appLanguage, onChanged: (v) { if (v != null) settings.setAppLanguage(v); Navigator.pop(ctx); }),
      RadioListTile<String>(title: Text(s.languageUrdu), value: 'ur', groupValue: settings.appLanguage, onChanged: (v) { if (v != null) settings.setAppLanguage(v); Navigator.pop(ctx); }),
    ])));
  }

  void _showLanguageDialog(BuildContext context, SettingsProvider settings, AppStrings s) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(s.captionLanguage), content: Column(mainAxisSize: MainAxisSize.min, children: ['English', 'Roman Urdu', 'Urdu'].map((lang) => RadioListTile<String>(title: Text(lang), value: lang, groupValue: settings.captionLanguage, onChanged: (v) { if (v != null) settings.setCaptionLanguage(v); Navigator.pop(ctx); })).toList())));
  }

  void _showRetentionDialog(BuildContext context, SettingsProvider settings, AppStrings s) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(s.defaultRetention), content: Column(mainAxisSize: MainAxisSize.min, children: [1, 7, 15].map((days) => RadioListTile<int>(title: Text(days == 1 ? s.retention1Day : days == 7 ? s.retention7Days : s.retention15Days), value: days, groupValue: settings.defaultRetentionDays, onChanged: (v) { if (v != null) settings.setDefaultRetentionDays(v); Navigator.pop(ctx); })).toList())));
  }

  void _confirmDeleteAllData(BuildContext context, AppStrings s) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(s.deleteAllConfirm), content: Text(s.deleteAllConfirmDesc), actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
      TextButton(onPressed: () async {
        Navigator.pop(ctx);
        if (SupabaseService.instance.isAuthenticated) await DatabaseService.instance.deleteAllUserData();
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.allDataDeletedMessage)));
      }, child: Text(s.deleteEverything, style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
    ]));
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(16, 24, 16, 8), child: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary, letterSpacing: 1.1, fontWeight: FontWeight.w700));
}

class _Avatar extends StatelessWidget {
  final UserProfile? profile;
  final double radius;
  const _Avatar({required this.profile, required this.radius});
  @override
  Widget build(BuildContext context) {
    final data = profile?.avatarData;
    if (data != null && data.isNotEmpty) {
      try { return CircleAvatar(radius: radius, backgroundImage: MemoryImage(base64Decode(data))); } catch (_) {}
    }
    return CircleAvatar(radius: radius, child: Text(profile?.avatarEmoji ?? '👤', style: TextStyle(fontSize: radius * .72)));
  }
}

class _SpeechModelsSection extends StatelessWidget {
  const _SpeechModelsSection();
  @override
  Widget build(BuildContext context) {
    final speech = context.watch<SpeechProvider>();
    final s = AppStrings.of(context);
    return Column(children: [
      ListTile(leading: Icon(speech.isOfflineMode ? Icons.wifi_off : Icons.wifi, color: Theme.of(context).colorScheme.primary), title: Text(s.currentMode), subtitle: Text(speech.sttModeLabel), trailing: Text(speech.currentLanguage, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600))),
      const Divider(height: 1),
      _ModelTile(title: s.englishModelTitle, description: s.englishModelDesc, language: s.englishLabel, sizeMB: 80, isReady: speech.isModelReady('English'), onDownload: () => speech.downloadOfflineModel('English'), onDelete: () => speech.deleteModel('English'), s: s),
      _ModelTile(title: s.urduModelTitle, description: s.urduModelDesc, language: s.urduLabel, sizeMB: 239, isReady: speech.isModelReady('Urdu'), onDownload: () => speech.downloadOfflineModel('Urdu'), onDelete: () => speech.deleteModel('Urdu'), s: s),
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: Text(s.offlineModelsInfo, style: Theme.of(context).textTheme.bodySmall)),
    ]);
  }
}

class _ModelTile extends StatelessWidget {
  final String title;
  final String description;
  final String language;
  final int sizeMB;
  final bool isReady;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final AppStrings s;
  const _ModelTile({required this.title, required this.description, required this.language, required this.sizeMB, required this.isReady, required this.onDownload, required this.onDelete, required this.s});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest, child: Icon(isReady ? Icons.check_circle : Icons.download_outlined, color: Theme.of(context).colorScheme.primary, size: 20)),
    title: Text(title),
    subtitle: Text('${description}\n${isReady ? s.ready : s.notDownloadedStatus} · $sizeMB MB'),
    isThreeLine: true,
    trailing: isReady ? IconButton(tooltip: s.removeDownload, icon: const Icon(Icons.delete_outline), onPressed: onDelete) : TextButton(onPressed: onDownload, child: Text(s.downloadLabel)),
  );
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';
    return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Image.asset('assets/logo.png', width: 56, height: 56), const SizedBox(width: 14), Expanded(child: Text('HumSukhan', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)))]),
      const SizedBox(height: 16),
      Text(isUrdu ? 'قابلِ رسائی مواصلات، لائیو کیپشنز، تقریر کی مدد اور پیشہ ورانہ سننا ایک ہی جگہ۔' : 'Accessible communication, live captions, speech assistance, and professional listening in one place.', style: theme.textTheme.bodyLarge),
      const SizedBox(height: 12),
      Text(isUrdu ? 'HumSukhan روزمرہ گفتگو، کلاس رومز، میٹنگز اور ماحول سے آگاہی کو زیادہ قابلِ رسائی بنانے کے لیے تیار کیا گیا ہے۔' : 'HumSukhan is designed to make everyday conversations, classrooms, meetings, and environmental awareness more accessible.', style: theme.textTheme.bodyMedium),
    ]))));
  }
}
