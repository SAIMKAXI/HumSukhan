import 'dart:convert';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/reusable_widgets.dart';
import '../widgets/quick_reply_manager.dart';
import '../modules/environmental_alerts/models/environmental_sound.dart';
import '../widgets/modern_ui.dart';
import '../l10n/app_strings.dart';
import '../services/stt/model_manager.dart';

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
          title: Text(user.profile == null ? s.setupProfile : s.displayName(user.profile!.name)),
          subtitle: Text(user.profile?.preferredLanguage ?? s.tapToEdit),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showEditProfileDialog(context, s),
        ),
        Consumer<AuthProvider>(builder: (_, auth, _) => ListTile(
          leading: Icon(auth.isAuthenticated ? Icons.cloud_done : Icons.cloud_off, color: auth.isAuthenticated ? theme.colorScheme.primary : theme.colorScheme.outline),
          title: Text(auth.isAuthenticated ? s.syncedWithSupabase : s.notSignedIn),
          subtitle: Text(auth.isAuthenticated ? (auth.user?.email ?? s.signedInAccount) : s.signInToSync),
          trailing: TextButton(
            onPressed: auth.isAuthenticated ? auth.signOut : () => Navigator.pushNamed(context, '/auth'),
            child: Text(auth.isAuthenticated ? s.signOut : s.signIn),
          ),
        )),
        _SectionHeader(title: s.appLanguage),
        ListTile(title: Text(s.appLanguage), subtitle: settings.appLanguage == 'ur' ? Text(s.languageUrdu) : Text(s.languageEnglish, locale: const Locale('en')), trailing: const Icon(Icons.chevron_right), onTap: () => _showAppLanguageDialog(context, settings, s)),
        _SectionHeader(title: s.accessibility),
        SwitchListTile(title: Text(s.darkMode), subtitle: Text(s.darkModeDesc), value: settings.isDarkMode, onChanged: (_) => settings.toggleDarkMode()),
        SwitchListTile(title: Text(s.highContrast), subtitle: Text(s.highContrastDesc), value: settings.isHighContrast, onChanged: (_) => settings.toggleHighContrast()),
        SwitchListTile(title: Text(s.largeText), subtitle: Text(s.largeTextDesc), value: settings.isLargeText, onChanged: (_) => settings.toggleLargeText()),
        ListTile(
          title: Text(s.captionTextSize),
          subtitle: Text(s.textSizeValue(settings.captionTextSize.toInt())),
          trailing: SizedBox(width: 190, child: Slider(value: settings.captionTextSize, min: 16, max: 48, divisions: 16, label: '${settings.captionTextSize.toInt()}', onChanged: settings.setCaptionTextSize)),
        ),
        _SectionHeader(title: s.alertPreferences),
        SwitchListTile(title: Text(s.hapticAlerts), subtitle: Text(s.hapticAlertsDesc), value: settings.hapticAlerts, onChanged: (_) => settings.toggleHapticAlerts()),
        SwitchListTile(title: Text(s.visualAlerts), subtitle: Text(s.visualAlertsDesc), value: settings.visualAlerts, onChanged: (_) => settings.toggleVisualAlerts()),
        SwitchListTile(title: Text(s.screenFlashAlerts), subtitle: Text(s.screenFlashAlertsDesc), value: settings.screenFlashAlerts, onChanged: (_) => settings.toggleScreenFlashAlerts()),
        SwitchListTile(
          title: Text(s.flashlightAlerts),
          subtitle: Text(defaultTargetPlatform == TargetPlatform.android
              ? s.flashlightCameraNote(s.flashlightAlertsDesc)
              : s.flashlightAndroidOnly),
          value: defaultTargetPlatform == TargetPlatform.android && settings.flashAlerts,
          onChanged: defaultTargetPlatform == TargetPlatform.android
              ? (enabled) => _setFlashlightAlerts(context, settings, enabled)
              : null,
        ),
        _SectionHeader(title: s.speechRecognition),
        const _SpeechModelsSection(),
        _SectionHeader(title: s.environmentalAlerts),
        ...settings.allowedAlerts.entries.map((entry) => SwitchListTile(title: Text(EnvironmentalSound.nameFor(entry.key, urdu: s.isUrdu)), value: entry.value, onChanged: (_) => settings.toggleAllowedAlert(entry.key))),
        _SectionHeader(title: s.quickRepliesSection),
        ListTile(
          leading: const Icon(Icons.bolt_outlined),
          title: Text(s.manageQuickReplies),
          subtitle: Text(s.manageQuickRepliesDesc),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showQuickReplyManager(context),
        ),
        _SectionHeader(title: s.privacyAndRetention),
        ListTile(title: Text(s.defaultRetentionPeriod), subtitle: Text('${settings.defaultRetentionDays} ${s.days}'), trailing: const Icon(Icons.chevron_right), onTap: () => _showRetentionDialog(context, settings, s)),
        _SectionHeader(title: s.privacySection),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: PrivacyNotice(text: s.privacyNoticeText)),
        ListTile(
          leading: Icon(Icons.restart_alt, color: theme.colorScheme.error),
          title: Text(s.resetSettings),
          subtitle: Text(s.resetSettingsDesc),
          onTap: () => _confirmReset(context, settings, s),
        ),
        _SectionHeader(title: s.aboutSection),
        const _AboutSection(),
        const SizedBox(height: 32),
      ]),
    );
  }

  Future<void> _confirmReset(BuildContext context, SettingsProvider settings, AppStrings s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.resetSettings),
        content: Text(s.resetSettingsConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(s.resetAction, style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await settings.resetToDefaults();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.settingsWereReset)));
    }
  }

  Future<void> _setFlashlightAlerts(
    BuildContext context,
    SettingsProvider settings,
    bool enabled,
  ) async {
    final s = AppStrings.of(context);
    if (!enabled) {
      if (settings.flashAlerts) settings.toggleFlashAlerts();
      return;
    }
    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final permission = await Permission.camera.request();
      if (!context.mounted) return;
      if (!permission.isGranted) {
        final message = permission.isPermanentlyDenied
            ? s.cameraBlocked
            : s.cameraRequired;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      final available = await const MethodChannel('com.humsukhan.flashlight')
              .invokeMethod<bool>('isAvailable') ??
          false;
      if (!context.mounted) return;
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.noFlashlight)),
        );
        return;
      }

      if (!settings.flashAlerts) settings.toggleFlashAlerts();
    } on PlatformException catch (error) {
      debugPrint('Flashlight alerts could not be enabled: ${error.message ?? error.code}');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.flashlightFailed)),
      );
    } on MissingPluginException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.flashlightUnavailable)),
      );
    }
  }

  Future<void> _showEditProfileDialog(BuildContext context, AppStrings s) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const _EditProfileSheet(),
      );

  void _showAppLanguageDialog(BuildContext context, SettingsProvider settings, AppStrings s) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.appLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(title: Text(s.languageEnglish, locale: const Locale('en')), value: 'en', groupValue: settings.appLanguage, onChanged: (v) { if (v != null) settings.setAppLanguage(v); Navigator.pop(ctx); }),
            RadioListTile<String>(title: Text(s.languageUrdu), value: 'ur', groupValue: settings.appLanguage, onChanged: (v) { if (v != null) settings.setAppLanguage(v); Navigator.pop(ctx); }),
          ],
        ),
      ),
    );
  }

  void _showRetentionDialog(BuildContext context, SettingsProvider settings, AppStrings s) {
    const retentionOptions = [1, 7, 15];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.defaultRetention),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: retentionOptions.map((days) {
            final label = days == 1 ? s.retention1Day : days == 7 ? s.retention7Days : s.retention15Days;
            return RadioListTile<int>(title: Text(label), value: days, groupValue: settings.defaultRetentionDays, onChanged: (v) { if (v != null) settings.setDefaultRetentionDays(v); Navigator.pop(ctx); });
          }).toList(),
        ),
      ),
    );
  }
}

/// Owns its text field, so the controller lives exactly as long as the
/// sheet, including its closing animation.
class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet();
  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _name;
  String? _avatarData;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<UserProvider>().profile;
    _name = TextEditingController(text: profile?.name ?? '');
    _avatarData = profile?.avatarData;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 82);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _avatarData = base64Encode(bytes));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).photoUnavailable)));
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final s = AppStrings.of(context);
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.nameRequired)));
      return;
    }
    setState(() => _saving = true);
    final user = context.read<UserProvider>();
    final base = user.profile ?? UserProfile(name: name);
    await user.saveProfile(base.copyWith(name: name, avatarData: _avatarData));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final profile = context.watch<UserProvider>().profile;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(s.editProfile, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _pickPhoto,
          child: Stack(alignment: AlignmentDirectional.bottomEnd, children: [
            _Avatar(profile: (profile ?? UserProfile(name: '')).copyWith(avatarData: _avatarData), radius: 46),
            CircleAvatar(radius: 16, backgroundColor: Theme.of(context).colorScheme.primary, child: const Icon(Icons.camera_alt, size: 16)),
          ]),
        ),
        const SizedBox(height: 16),
        TextField(controller: _name, decoration: InputDecoration(labelText: s.nameLabel), textInputAction: TextInputAction.done, onSubmitted: (_) => _save()),
        const SizedBox(height: 20),
        PrimaryActionButton(label: s.save, icon: Icons.save, onPressed: _saving ? null : _save),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary, letterSpacing: 1.1, fontWeight: FontWeight.w700)),
      );
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
      ListTile(leading: Icon(speech.isOfflineMode ? Icons.wifi_off : Icons.wifi, color: Theme.of(context).colorScheme.primary), title: Text(s.currentMode), subtitle: Text(s.message(speech.sttModeLabel)), trailing: Text(s.languageName(speech.currentLanguage), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600))),
      const Divider(height: 1),
      for (final (language, title, description, label) in [
        ('English', s.englishModelTitle, s.englishModelDesc, s.englishLabel),
        ('Urdu', s.urduModelTitle, s.urduModelDesc, s.urduLabel),
      ])
        _ModelTile(
          title: title,
          description: description,
          language: label,
          sizeMB: ModelManager.availableModels[language]!.sizeMB,
          isReady: speech.isModelReady(language),
          downloading: speech.getModelStatus(language)?.isDownloading == true ? speech.getModelStatus(language)!.downloadProgress : null,
          onDownload: () => _download(context, speech, language),
          onDelete: () => speech.deleteModel(language),
          s: s,
        ),
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: Text(s.offlineModelsInfo, style: Theme.of(context).textTheme.bodySmall)),
    ]);
  }
}

Future<void> _download(BuildContext context, SpeechProvider speech, String language) async {
  final s = AppStrings.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final ok = await speech.downloadOfflineModel(language);
  messenger.showSnackBar(SnackBar(content: Text(ok ? s.modelReadyNotice : s.modelDownloadFailedWith(speech.modelError(language)))));
}

class _ModelTile extends StatelessWidget {
  final String title, description, language;
  final int sizeMB;
  final bool isReady;

  /// Progress from 0 to 1 while downloading, otherwise null.
  final double? downloading;
  final VoidCallback onDownload, onDelete;
  final AppStrings s;
  const _ModelTile({required this.title, required this.description, required this.language, required this.sizeMB, required this.isReady, this.downloading, required this.onDownload, required this.onDelete, required this.s});
  @override
  Widget build(BuildContext context) {
    final progress = downloading;
    final status = isReady ? s.ready : progress != null ? s.downloadingPercent((progress * 100).round()) : s.notDownloadedStatus;
    return ListTile(
      leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest, child: Icon(isReady ? Icons.check_circle : Icons.download_outlined, color: Theme.of(context).colorScheme.primary, size: 20)),
      title: Text(title),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$description\n$status · ${s.megabytes(sizeMB)}'),
        if (progress != null) Padding(padding: const EdgeInsets.only(top: 6), child: LinearProgressIndicator(value: progress)),
      ]),
      isThreeLine: true,
      trailing: isReady
          ? IconButton(tooltip: s.removeDownload, icon: const Icon(Icons.delete_outline), onPressed: onDelete)
          : progress != null
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
              : TextButton(onPressed: onDownload, child: Text(s.downloadLabel)),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final isUrdu = s.isUrdu;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const BrandLogo(size: 56), const SizedBox(width: 14), Expanded(child: Text('HumSukhan', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)))]),
            const SizedBox(height: 16),
            Text(s.aboutTagline, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            Text(isUrdu ? 'HumSukhan روزمرہ گفتگو، کلاس رومز، میٹنگز اور ماحول سے آگاہی کو زیادہ قابلِ رسائی بنانے کے لیے تیار کیا گیا ہے۔' : 'HumSukhan is designed to make everyday conversations, classrooms, meetings, and environmental awareness more accessible.', style: theme.textTheme.bodyMedium),
          ]),
        ),
      ),
    );
  }
}
