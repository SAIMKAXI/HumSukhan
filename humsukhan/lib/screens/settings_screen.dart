import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/reusable_widgets.dart';
import '../widgets/modern_ui.dart';
import '../l10n/app_strings.dart';

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
        ListTile(title: Text(s.appLanguage), subtitle: Text(settings.appLanguage == 'ur' ? s.languageUrdu : s.languageEnglish), trailing: const Icon(Icons.chevron_right), onTap: () => _showAppLanguageDialog(context, settings, s)),
        _SectionHeader(title: s.accessibility),
        SwitchListTile(title: Text(s.darkMode), subtitle: Text(s.darkModeDesc), value: settings.isDarkMode, onChanged: (_) => settings.toggleDarkMode()),
        SwitchListTile(title: Text(s.highContrast), subtitle: Text(s.highContrastDesc), value: settings.isHighContrast, onChanged: (_) => settings.toggleHighContrast()),
        SwitchListTile(title: Text(s.largeText), subtitle: Text(s.largeTextDesc), value: settings.isLargeText, onChanged: (_) => settings.toggleLargeText()),
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
        _SectionHeader(title: s.speechRecognition),
        const _SpeechModelsSection(),
        _SectionHeader(title: s.environmentalAlerts),
        ...settings.allowedAlerts.entries.map((entry) => SwitchListTile(title: Text(entry.key), value: entry.value, onChanged: (_) => settings.toggleAllowedAlert(entry.key))),
        _SectionHeader(title: '${s.privacySection} & ${s.defaultRetention}'),
        ListTile(title: Text(s.defaultRetentionPeriod), subtitle: Text('${settings.defaultRetentionDays} ${s.days}'), trailing: const Icon(Icons.chevron_right), onTap: () => _showRetentionDialog(context, settings, s)),
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
    var isSaving = false;
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
              try {
                final file = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 82,
                );
                if (file == null) return;
                final bytes = await file.readAsBytes();
                if (ctx.mounted) {
                  setModalState(() => avatarData = base64Encode(bytes));
                }
              } catch (error) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Could not select profile photo: $error')),
                  );
                }
              }
            },
            child: Stack(alignment: Alignment.bottomRight, children: [
              _Avatar(profile: user.profile?.copyWith(avatarData: avatarData), radius: 46),
              CircleAvatar(radius: 16, backgroundColor: Theme.of(ctx).colorScheme.primary, child: const Icon(Icons.camera_alt, size: 16)),
            ]),
          ),
          const SizedBox(height: 16),
          TextField(controller: nameController, onChanged: (_) => setModalState(() {}), decoration: InputDecoration(labelText: s.nameLabel)),
          const SizedBox(height: 20),
          PrimaryActionButton(
            label: isSaving ? 'Saving…' : s.save,
            icon: isSaving ? Icons.hourglass_empty : Icons.save,
            onPressed: isSaving || nameController.text.trim().isEmpty
                ? null
                : () async {
                    setModalState(() => isSaving = true);
                    try {
                      final name = nameController.text.trim();
                      final base = user.profile ?? UserProfile(name: name);
                      await user.saveProfile(
                        base.copyWith(name: name, avatarData: avatarData),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (error) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Could not save profile: $error')),
                        );
                      }
                    } finally {
                      if (ctx.mounted) setModalState(() => isSaving = false);
                    }
                  },
          ),
        ]),
      )),
    );
    nameController.dispose();
  }

  void _showAppLanguageDialog(BuildContext context, SettingsProvider settings, AppStrings s) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.appLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(title: Text(s.languageEnglish), value: 'en', groupValue: settings.appLanguage, onChanged: (v) { if (v != null) settings.setAppLanguage(v); Navigator.pop(ctx); }),
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

class _SpeechModelsSection extends StatefulWidget {
  const _SpeechModelsSection();

  @override
  State<_SpeechModelsSection> createState() => _SpeechModelsSectionState();
}

class _SpeechModelsSectionState extends State<_SpeechModelsSection> {
  bool _modelsInitializing = true;
  String? _deletingLanguage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeModels());
  }

  Future<void> _initializeModels() async {
    if (!mounted) return;
    setState(() => _modelsInitializing = true);
    try {
      await context.read<SpeechProvider>().initializeOfflineModels();
    } catch (_) {
      // An unavailable storage/platform service is surfaced by the retry row.
    }
    if (mounted) setState(() => _modelsInitializing = false);
  }

  Future<void> _downloadModel(String language) async {
    final speech = context.read<SpeechProvider>();
    final s = AppStrings.of(context);
    try {
      final success = await speech.downloadOfflineModel(language);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? s.modelDownloadComplete(language)
                : s.modelDownloadFailed(language),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.modelDownloadFailed(language))),
      );
    }
  }

  Future<void> _deleteModel(String language) async {
    final s = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.modelDeleteConfirm),
        content: Text(s.deleteModelDesc(
          context.read<SpeechProvider>().getModelStatus(language)?.model.sizeMB ?? 0,
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(s.removeDownload),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _deletingLanguage = language);
    try {
      final success = await context.read<SpeechProvider>().deleteModel(language);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? s.modelRemoved(language) : s.modelRemoveFailed(language),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.modelRemoveFailed(language))),
      );
    } finally {
      if (mounted) setState(() => _deletingLanguage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final speech = context.watch<SpeechProvider>();
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final englishStatus = speech.getModelStatus('English');

    return Column(
      children: [
        ListTile(
          leading: Icon(
            speech.isOfflineMode ? Icons.wifi_off : Icons.wifi,
            color: theme.colorScheme.primary,
          ),
          title: Text(s.currentMode),
          subtitle: Text(speech.sttModeLabel),
          trailing: Text(
            speech.currentLanguage,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Divider(height: 1),
        if (_modelsInitializing && englishStatus == null)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: LinearProgressIndicator(),
          )
        else if (englishStatus == null)
          ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text(s.englishModelTitle),
            subtitle: Text(s.modelDownloadFailed(s.englishLabel)),
            trailing: IconButton(
              tooltip: s.retry,
              onPressed: _initializeModels,
              icon: const Icon(Icons.refresh),
            ),
          )
        else
          _ModelTile(
            title: s.englishModelTitle,
            description: s.englishModelDesc,
            language: s.englishLabel,
            sizeMB: englishStatus.model.sizeMB,
            isReady: englishStatus.isDownloaded,
            isDownloading: englishStatus.isDownloading,
            downloadProgress: englishStatus.downloadProgress,
            isWorking: englishStatus.isDownloading || _deletingLanguage == 'English',
            onDownload: englishStatus.isDownloading || _deletingLanguage != null
                ? null
                : () => _downloadModel('English'),
            onDelete: englishStatus.isDownloaded && _deletingLanguage == null
                ? () => _deleteModel('English')
                : null,
            s: s,
          ),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            child: Icon(Icons.cloud_off_outlined, color: theme.colorScheme.outline),
          ),
          title: Text(s.urduModelTitle),
          subtitle: Text(s.urduModelDesc),
          trailing: Tooltip(
            message: s.urduModelDesc,
            child: const Icon(Icons.info_outline_rounded),
          ),
          isThreeLine: true,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(s.offlineModelsInfo, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _ModelTile extends StatelessWidget {
  final String title, description, language;
  final int sizeMB;
  final bool isReady;
  final bool isDownloading;
  final double downloadProgress;
  final bool isWorking;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final AppStrings s;

  const _ModelTile({
    required this.title,
    required this.description,
    required this.language,
    required this.sizeMB,
    required this.isReady,
    required this.isDownloading,
    required this.downloadProgress,
    required this.isWorking,
    required this.onDownload,
    required this.onDelete,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (downloadProgress * 100).round();
    final status = isDownloading
        ? '${s.modelDownloading} $percent%'
        : isWorking
            ? s.modelWorking
            : '${isReady ? s.ready : s.notDownloadedStatus} · $sizeMB MB';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          isReady ? Icons.check_circle : Icons.download_outlined,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(title),
      subtitle: Text('${description}\n$status'),
      isThreeLine: true,
      trailing: isWorking
          ? SizedBox(
              width: 72,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      value: isDownloading ? downloadProgress : null,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isDownloading ? '$percent%' : s.modelWorking,
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )
          : isReady
              ? IconButton(
                  tooltip: s.removeDownload,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                )
              : TextButton(
                  onPressed: onDownload,
                  child: Text(s.downloadLabel),
                ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const BrandLogo(size: 56), const SizedBox(width: 14), Expanded(child: Text('HumSukhan', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)))]),
            const SizedBox(height: 16),
            Text(isUrdu ? 'قابلِ رسائی مواصلات، لائیو کیپشنز، تقریر کی مدد اور پیشہ ورانہ سننا ایک ہی جگہ۔' : 'Accessible communication, live captions, speech assistance, and professional listening in one place.', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            Text(isUrdu ? 'HumSukhan روزمرہ گفتگو، کلاس رومز، میٹنگز اور ماحول سے آگاہی کو زیادہ قابلِ رسائی بنانے کے لیے تیار کیا گیا ہے۔' : 'HumSukhan is designed to make everyday conversations, classrooms, meetings, and environmental awareness more accessible.', style: theme.textTheme.bodyMedium),
          ]),
        ),
      ),
    );
  }
}
