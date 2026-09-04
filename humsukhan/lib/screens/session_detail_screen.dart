import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/action_item_normalizer.dart';
import '../widgets/reusable_widgets.dart';
import '../widgets/speakable_caption_bubble.dart';

class SessionDetailScreen extends StatefulWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ProfessionalProvider>();
      if (provider.getInsightForSession(widget.sessionId) == null) {
        provider.generateInsights(widget.sessionId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfessionalProvider>();
    final session = provider.sessions.where((item) => item.id == widget.sessionId).firstOrNull;
    final strings = AppStrings.of(context);

    if (session == null) {
      return const Scaffold(
        body: Center(child: Text('Session is no longer available.')),
      );
    }

    final insight = provider.getInsightForSession(widget.sessionId);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(session.title),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: strings.overviewTab),
              Tab(text: strings.transcriptTab),
              Tab(text: strings.summaryTab),
              Tab(text: strings.actionsTab),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'export') {
                  _showExport(context, session, insight, strings);
                } else {
                  _confirmDelete(context, session, strings);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'export',
                  child: Text(strings.exportAction),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(strings.deleteAction),
                ),
              ],
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _overview(context, session, strings),
            _transcript(context, session, strings),
            _summary(context, insight, strings),
            _actions(context, insight, strings),
          ],
        ),
      ),
    );
  }

  Widget _overview(
    BuildContext context,
    ProfessionalSession session,
    AppStrings strings,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  _row(context, 'Type', session.type.name.toUpperCase()),
                  _row(
                    context,
                    'Date',
                    '${session.createdAt.day}/${session.createdAt.month}/${session.createdAt.year}',
                  ),
                  _row(context, 'Captions', '${session.captions.length}'),
                  _row(context, 'Language', session.captionLanguage),
                  _row(context, 'Retention', '${session.retentionDays} days'),
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 16),
                      const SizedBox(width: 8),
                      RetentionBadge(daysRemaining: session.daysRemaining),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          PrivacyNotice(text: strings.savedRecordsNote),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _transcript(
    BuildContext context,
    ProfessionalSession session,
    AppStrings strings,
  ) {
    if (session.captions.isEmpty) {
      return EmptyState(
        icon: Icons.subtitles_off,
        title: strings.noTranscriptAvailable,
        subtitle: strings.noTranscriptDesc,
      );
    }

    final settings = context.read<SettingsProvider>();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: session.captions.length,
      itemBuilder: (context, index) {
        final caption = session.captions[index];
        final hour = caption.timestamp.hour.toString().padLeft(2, '0');
        final minute = caption.timestamp.minute.toString().padLeft(2, '0');

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${caption.speaker} · $hour:$minute',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              SpeakableCaptionBubble(
                caption: caption,
                textSize: settings.captionTextSize,
                isHighContrast: settings.isHighContrast,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summary(
    BuildContext context,
    ProfessionalInsight? insight,
    AppStrings strings,
  ) {
    if (insight == null || !insight.isAvailable || insight.summaryBullets.isEmpty) {
      return ErrorState(
        title: strings.insightsUnavailable,
        message: strings.insightsUnavailableDesc,
        buttonText: strings.viewTranscript,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AiDisclaimer(),
          const SizedBox(height: 12),
          _summaryCard(context, insight, strings),
          if (insight.deadlines.isNotEmpty) ...[
            const SizedBox(height: 16),
            InsightCard(
              title: strings.deadlines,
              icon: Icons.schedule,
              items: insight.deadlines,
              iconColor: AppTheme.warningLight,
            ),
          ],
          if (insight.mentionedPeople.isNotEmpty) ...[
            const SizedBox(height: 8),
            InsightCard(
              title: strings.peopleMentioned,
              icon: Icons.people_outline,
              items: insight.mentionedPeople,
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryCard(
    BuildContext context,
    ProfessionalInsight insight,
    AppStrings strings,
  ) {
    final bullets = insight.summaryBullets;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 16),
                const SizedBox(width: 8),
                Text(
                  strings.aiSummary,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (bullets.isEmpty)
              Text(strings.insightsUnavailableDesc)
            else
              ...bullets.map(
                (bullet) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Text('•'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(bullet)),
                    ],
                  ),
                ),
              ),
            const AiDisclaimer(),
          ],
        ),
      ),
    );
  }

  Widget _actions(
    BuildContext context,
    ProfessionalInsight? insight,
    AppStrings strings,
  ) {
    final actionItems = insight == null
        ? const <String>[]
        : ActionItemNormalizer.normalize(insight.actionItems);
    if (actionItems.isEmpty) {
      return EmptyState(
        icon: Icons.task_alt,
        title: strings.noActionItems,
        subtitle: strings.noActionItemsDesc,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: InsightCard(
        title: strings.actionItems,
        icon: Icons.task_alt,
        items: actionItems,
        iconColor: AppTheme.secondaryLight,
      ),
    );
  }

  void _showExport(
    BuildContext context,
    ProfessionalSession session,
    ProfessionalInsight? insight,
    AppStrings strings,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.exportAction),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrivacyNotice(text: strings.exportPrivacyNote),
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: Text(strings.exportTxt),
              onTap: () {
                Navigator.pop(dialogContext);
                _exportTxt(session, insight, context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(strings.copyClipboard),
              onTap: () async {
                Navigator.pop(dialogContext);
                await Clipboard.setData(
                  ClipboardData(text: _exportText(session, insight)),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _exportText(
    ProfessionalSession session,
    ProfessionalInsight? insight,
  ) {
    final buffer = StringBuffer()
      ..writeln('HumSukhan — Session Export')
      ..writeln()
      ..writeln('Title: ${session.title}')
      ..writeln('Type: ${session.type.name}')
      ..writeln('Language: ${session.captionLanguage}')
      ..writeln()
      ..writeln('--- TRANSCRIPT ---');

    for (final caption in session.captions) {
      buffer.writeln('${caption.speaker}: ${caption.text}');
    }

    if (insight?.isAvailable == true && insight!.summaryBullets.isNotEmpty) {
      buffer.writeln('\n--- AI SUMMARY ---');
      for (final bullet in insight.summaryBullets) {
        buffer.writeln('• $bullet');
      }

      if (insight.actionItems.isNotEmpty) {
        buffer.writeln('\nAction Items:');
        for (final item in insight.actionItems) {
          buffer.writeln('• $item');
        }
      }

      if (insight.deadlines.isNotEmpty) {
        buffer.writeln('\nDeadlines:');
        for (final deadline in insight.deadlines) {
          buffer.writeln('• $deadline');
        }
      }
    } else if (insight?.summary.trim().isNotEmpty == true) {
      buffer.writeln('\n--- LEGACY AI SUMMARY ---');
      buffer.writeln(insight!.summary.trim());
    }

    return buffer.toString();
  }

  Future<void> _exportTxt(
    ProfessionalSession session,
    ProfessionalInsight? insight,
    BuildContext context,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/humsukhan_${session.id}.txt');
      await file.writeAsString(_exportText(session, insight));
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'HumSukhan session export',
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $error')),
      );
    }
  }

  void _confirmDelete(
    BuildContext context,
    ProfessionalSession session,
    AppStrings strings,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.deleteSessionConfirm),
        content: Text(strings.deleteSessionDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () async {
              await context.read<ProfessionalProvider>().deleteSession(session.id);
              if (!context.mounted) return;
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: Text(
              strings.delete,
              style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
