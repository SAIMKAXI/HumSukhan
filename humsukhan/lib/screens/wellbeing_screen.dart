import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../modules/wellbeing/models/mood_entry.dart';
import '../modules/wellbeing/services/check_in_reminders.dart';
import '../modules/wellbeing/services/mood_patterns.dart';
import '../providers/wellbeing_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_ui.dart';
import '../theme/app_typography.dart';
import 'wellbeing_help_screen.dart';

String moodLabel(AppStrings s, Mood mood) => switch (mood) {
      Mood.veryLow => s.moodVeryLow,
      Mood.low => s.moodLow,
      Mood.okay => s.moodOkay,
      Mood.good => s.moodGood,
      Mood.great => s.moodGreat,
    };

String tagLabel(AppStrings s, MoodTag tag) => switch (tag) {
      MoodTag.tired => s.tagTired,
      MoodTag.lonely => s.tagLonely,
      MoodTag.leftOut => s.tagLeftOut,
      MoodTag.anxious => s.tagAnxious,
      MoodTag.stressed => s.tagStressed,
      MoodTag.sad => s.tagSad,
      MoodTag.calm => s.tagCalm,
      MoodTag.happy => s.tagHappy,
      MoodTag.grateful => s.tagGrateful,
    };

/// Optional daily check-ins, the user's own pattern, and pre-written ideas.
class WellbeingScreen extends StatefulWidget {
  const WellbeingScreen({super.key, this.openCheckIn = false});

  /// Opens the check-in straight away, as when a reminder is tapped.
  final bool openCheckIn;

  @override
  State<WellbeingScreen> createState() => _WellbeingScreenState();
}

class _WellbeingScreenState extends State<WellbeingScreen> {
  int _chartDays = 7;
  bool _showAllHistory = false;

  @override
  void initState() {
    super.initState();
    if (widget.openCheckIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_checkIn(null));
      });
    }
  }

  Future<void> _checkIn(Mood? preselected) async {
    final wellbeing = context.read<WellbeingProvider>();
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final entry = await showModalBottomSheet<MoodEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => CheckInSheet(initial: preselected),
    );
    if (entry == null || !mounted) return;
    if (MoodPatterns.isUrgent(entry)) {
      await openWellbeingHelp(context, MoodState.urgent);
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(s.checkInSaved)));
    final state = wellbeing.pattern.state;
    if (state == MoodState.lowDay || state == MoodState.severalLowDays) {
      await openWellbeingHelp(context, state);
    }
  }

  Future<void> _setReminders(bool on) async {
    final wellbeing = context.read<WellbeingProvider>();
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final failure = await wellbeing.setRemindersOn(on);
    if (failure == null || !mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(failure == ReminderFailure.permissionDenied ? s.reminderPermissionDenied : s.reminderSchedulingFailed),
    ));
  }

  Future<void> _pickTime(int index, ReminderTime current) async {
    final wellbeing = context.read<WellbeingProvider>();
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;
    final ok = await wellbeing.setReminderTime(index, ReminderTime(picked.hour, picked.minute));
    if (!ok && mounted) messenger.showSnackBar(SnackBar(content: Text(s.reminderSchedulingFailed)));
  }

  Future<void> _deleteEntry(MoodEntry entry) async {
    final s = AppStrings.of(context);
    final wellbeing = context.read<WellbeingProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(s.deleteCheckInConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.delete)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await wellbeing.deleteEntry(entry.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(s.deleteFailed)));
    }
  }

  Future<void> _deleteAll() async {
    final s = AppStrings.of(context);
    final wellbeing = context.read<WellbeingProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deleteAllCheckIns),
        content: Text(s.deleteAllCheckInsConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await wellbeing.deleteAllCheckIns();
      messenger.showSnackBar(SnackBar(content: Text(s.checkInsDeleted)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(s.deleteFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final wellbeing = context.watch<WellbeingProvider>();
    final theme = Theme.of(context);
    if (!wellbeing.isLoaded) {
      return Scaffold(appBar: AppBar(title: Text(s.wellbeingTitle)), body: const Center(child: CircularProgressIndicator()));
    }
    final pattern = wellbeing.pattern;
    final history = wellbeing.entries;
    final visibleHistory = _showAllHistory ? history : history.take(5).toList();

    return Scaffold(
      appBar: AppBar(title: Text(s.wellbeingTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (wellbeing.loadDamaged) ...[
              _Notice(icon: Icons.info_outline_rounded, text: s.wellbeingLoadDamaged),
              const SizedBox(height: 12),
            ],
            if (!wellbeing.introSeen) ...[
              _IntroCard(
                onRemind: () async {
                  await wellbeing.markIntroSeen();
                  await _setReminders(true);
                },
                onNotNow: wellbeing.markIntroSeen,
              ),
              const SizedBox(height: 16),
            ],
            _CheckInCard(latest: pattern.latest, onMood: _checkIn),
            const SizedBox(height: 16),
            _PatternCard(
              pattern: pattern,
              days: wellbeing.days(_chartDays),
              chartDays: _chartDays,
              onChartDays: (days) => setState(() => _chartDays = days),
              onGetHelp: () => openWellbeingHelp(context, pattern.state),
            ),
            const SizedBox(height: 24),
            Text(s.recentCheckIns, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (history.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(s.noCheckInsYet, style: theme.textTheme.bodyMedium))
            else ...[
              for (final entry in visibleHistory) _HistoryTile(entry: entry, onDelete: () => _deleteEntry(entry)),
              if (!_showAllHistory && history.length > visibleHistory.length)
                TextButton(onPressed: () => setState(() => _showAllHistory = true), child: Text(s.showAll)),
            ],
            const SizedBox(height: 24),
            _ReminderSettings(
              wellbeing: wellbeing,
              onToggle: _setReminders,
              onPickTime: _pickTime,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.showBothLanguages),
              value: wellbeing.showBothLanguages,
              onChanged: wellbeing.setShowBothLanguages,
            ),
            const SizedBox(height: 16),
            PrivacyStrip(text: s.wellbeingPrivacy),
            const SizedBox(height: 12),
            _Notice(icon: Icons.medical_information_outlined, text: s.wellbeingDisclaimer),
            if (history.isNotEmpty) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                icon: const Icon(Icons.delete_forever_rounded),
                label: Text(s.deleteAllCheckIns),
                onPressed: _deleteAll,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colors.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: AppTypography.latinLineHeight(context, 1.45)))),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.onRemind, required this.onNotNow});
  final Future<void> Function() onRemind;
  final Future<void> Function() onNotNow;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.wellbeingIntroTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(s.wellbeingIntroBody, style: theme.textTheme.bodyMedium?.copyWith(height: AppTypography.latinLineHeight(context, 1.5))),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(s.wellbeingIntroRemind),
              onPressed: onRemind,
            ),
            TextButton(onPressed: onNotNow, child: Text(s.wellbeingIntroNotNow)),
          ],
        ),
      ),
    );
  }
}

/// Five faces, large enough to tap easily, each labelled in words too.
class MoodPicker extends StatelessWidget {
  const MoodPicker({super.key, required this.selected, required this.onSelected});

  final Mood? selected;
  final ValueChanged<Mood> onSelected;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    // Every face the same height, even when a label wraps to two lines.
    return IntrinsicHeight(
      child: Row(
        // Low to high follows the reading direction: from the right in Urdu.
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final mood in Mood.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: selected == mood,
                label: moodLabel(s, mood),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  onTap: () => onSelected(mood),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                      color: selected == mood ? colors.primary.withValues(alpha: .14) : null,
                      border: Border.all(color: selected == mood ? colors.primary : colors.outline.withValues(alpha: .4), width: selected == mood ? 2 : 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ExcludeSemantics(child: Text(mood.face, style: const TextStyle(fontSize: 30))),
                        const SizedBox(height: 4),
                        ExcludeSemantics(
                          child: Text(
                            moodLabel(s, mood),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.latest, required this.onMood});
  final MoodEntry? latest;
  final Future<void> Function(Mood?) onMood;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = latest != null && latest!.at.year == now.year && latest!.at.month == now.month && latest!.at.day == now.day;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.howAreYouFeeling, style: theme.textTheme.titleLarge),
            if (today) ...[
              const SizedBox(height: 4),
              Text('${s.todayLabel}: ${latest!.mood.face} ${moodLabel(s, latest!.mood)}', style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            MoodPicker(selected: null, onSelected: onMood),
          ],
        ),
      ),
    );
  }
}

/// The check-in itself: a face, optional words and an optional note.
/// Returns the saved entry, or null if the user skipped it.
class CheckInSheet extends StatefulWidget {
  const CheckInSheet({super.key, this.initial});
  final Mood? initial;

  @override
  State<CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<CheckInSheet> {
  late Mood? _mood = widget.initial;
  final Set<MoodTag> _tags = {};
  final TextEditingController _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final mood = _mood;
    if (mood == null || _saving) return;
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final entry = await context.read<WellbeingProvider>().addCheckIn(mood, tags: _tags, note: _note.text);
      navigator.pop(entry);
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(s.checkInFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.howAreYouFeeling, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            MoodPicker(selected: _mood, onSelected: (mood) => setState(() => _mood = mood)),
            const SizedBox(height: 20),
            Text(s.checkInTagsLabel, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in MoodTag.values)
                  FilterChip(
                    label: Text(tagLabel(s, tag)),
                    selected: _tags.contains(tag),
                    onSelected: (on) => setState(() => on ? _tags.add(tag) : _tags.remove(tag)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 5,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: s.checkInNoteLabel, hintText: s.checkInNoteHint, alignLabelWithHint: true),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _mood == null || _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(s.saveCheckIn),
            ),
            TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: Text(s.skipForNow)),
          ],
        ),
      ),
    );
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({
    required this.pattern,
    required this.days,
    required this.chartDays,
    required this.onChartDays,
    required this.onGetHelp,
  });

  final MoodPattern pattern;
  final List<MoodDay> days;
  final int chartDays;
  final ValueChanged<int> onChartDays;
  final VoidCallback onGetHelp;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final concerned = pattern.state == MoodState.severalLowDays || pattern.state == MoodState.urgent;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.yourPattern, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(patternMessage(s, pattern.state), style: theme.textTheme.bodyLarge),
            if (pattern.streakDays > 1) ...[
              const SizedBox(height: 4),
              Text(s.streakDays(pattern.streakDays), style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
            ],
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 7, label: Text(s.sevenDays)),
                ButtonSegment(value: 30, label: Text(s.thirtyDays)),
              ],
              selected: {chartDays},
              onSelectionChanged: (value) => onChartDays(value.first),
            ),
            const SizedBox(height: 12),
            MoodChart(days: days),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: concerned ? colors.error : null,
                foregroundColor: concerned ? colors.onError : null,
              ),
              icon: const Icon(Icons.volunteer_activism_rounded),
              label: Text(s.getHelp),
              onPressed: onGetHelp,
            ),
          ],
        ),
      ),
    );
  }
}

/// Daily averages as bars from very low (short) to great (tall), each
/// topped with that day's face. Days without a check-in are left empty.
class MoodChart extends StatelessWidget {
  const MoodChart({super.key, required this.days});
  final List<MoodDay> days;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final s = AppStrings.of(context);
    final dense = days.length > 10;
    final dayFormat = DateFormat.E(s.isUrdu ? 'ur' : 'en');
    // At least this tall, and taller when large text needs the room.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 132),
      child: Row(
        // Time follows the reading direction: today is on the left in Urdu.
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final day in days)
            Expanded(
              child: Semantics(
                label: '${DateFormat.MMMd(s.isUrdu ? 'ur' : 'en').format(day.day)}: '
                    '${day.average == null ? '-' : moodLabel(s, Mood.fromScore(day.average!.round()))}',
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: dense ? 1 : 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (day.average != null && !dense)
                        ExcludeSemantics(child: Text(Mood.fromScore(day.average!.round()).face, style: const TextStyle(fontSize: 16))),
                      const SizedBox(height: 2),
                      Container(
                        height: day.average == null ? 2 : 14 + (day.average! - 1) / 4 * 70,
                        decoration: BoxDecoration(
                          color: day.average == null
                              ? colors.outline.withValues(alpha: .3)
                              : day.average! <= 2
                                  ? colors.error.withValues(alpha: .75)
                                  : colors.primary.withValues(alpha: .35 + (day.average! - 1) / 4 * .6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      if (!dense) ...[
                        const SizedBox(height: 4),
                        ExcludeSemantics(
                          child: Text(dayFormat.format(day.day), maxLines: 1, style: Theme.of(context).textTheme.labelSmall),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.onDelete});
  final MoodEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final when = '${DateFormat.MMMd(s.isUrdu ? 'ur' : 'en').format(entry.at)} ${s.clockTime(entry.at.hour, entry.at.minute)}';
    final words = [for (final tag in entry.tags) tagLabel(s, tag)].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Text(entry.mood.face, style: const TextStyle(fontSize: 28)),
      title: Text('${moodLabel(s, entry.mood)} · $when'),
      subtitle: words.isEmpty && entry.note.isEmpty
          ? null
          : Text([if (words.isNotEmpty) words, if (entry.note.isNotEmpty) entry.note].join('\n'), style: theme.textTheme.bodySmall),
      trailing: IconButton(
        tooltip: s.delete,
        icon: const Icon(Icons.delete_outline_rounded),
        onPressed: onDelete,
      ),
    );
  }
}

class _ReminderSettings extends StatelessWidget {
  const _ReminderSettings({required this.wellbeing, required this.onToggle, required this.onPickTime});

  final WellbeingProvider wellbeing;
  final Future<void> Function(bool) onToggle;
  final Future<void> Function(int, ReminderTime) onPickTime;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final times = wellbeing.reminderTimes;
    final error = wellbeing.reminderError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.dailyReminder),
          subtitle: Text(s.dailyReminderDesc),
          value: wellbeing.remindersOn,
          onChanged: onToggle,
        ),
        if (wellbeing.remindersOn) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.twiceADay),
            value: wellbeing.twiceDaily,
            onChanged: (value) => wellbeing.setTwiceDaily(value),
          ),
          for (var i = 0; i < times.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: Text(s.reminderTime),
              trailing: Text(
                s.clockTime(times[i].hour, times[i].minute),
                style: theme.textTheme.titleMedium,
              ),
              onTap: () => onPickTime(i, times[i]),
            ),
          Text(s.reminderKeepsGoing, style: theme.textTheme.bodySmall),
        ],
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error == 'permission' ? s.reminderPermissionDenied : s.reminderSchedulingFailed,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}
