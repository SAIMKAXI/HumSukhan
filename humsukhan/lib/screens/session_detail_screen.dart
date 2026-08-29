import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/reusable_widgets.dart';
import '../l10n/app_strings.dart';

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
      final pro = context.read<ProfessionalProvider>();
      if (pro.getInsightForSession(widget.sessionId) == null) {
        pro.generateInsights(widget.sessionId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pro = context.watch<ProfessionalProvider>();
    final session = pro.sessions.firstWhere(
      (s) => s.id == widget.sessionId,
      orElse: () => ProfessionalSession(title: 'Unknown', status: SessionStatus.completed),
    );
    final insight = pro.getInsightForSession(widget.sessionId);
    final s = AppStrings.of(context);

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(session.title),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: s.overviewTab),
              Tab(text: s.transcriptTab),
              Tab(text: s.summaryTab),
              Tab(text: s.vocabularyTab),
              Tab(text: s.themesTab),
              Tab(text: s.actionsTab),
            ],
          ),
          actions: [
            PopupMenuButton(
              itemBuilder: (_) => [
                PopupMenuItem(value: 'export', child: Text(s.exportAction)),
                PopupMenuItem(value: 'delete', child: Text(s.deleteAction)),
              ],
              onSelected: (value) {
                if (value == 'export') _showExportDialog(context, session, insight, s);
                if (value == 'delete') _confirmDelete(context, session, s);
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildOverviewTab(context, session, insight, s),
            _buildTranscriptTab(context, session, s),
            _buildSummaryTab(context, insight, s),
            _buildVocabularyTab(context, insight, s),
            _buildThemesTab(context, insight, s),
            _buildActionsTab(context, insight, s),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, ProfessionalSession session, ProfessionalInsight? insight, AppStrings s) {
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
                  Text(session.title, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  _infoRow(context, Icons.category, 'Type', session.type.name.toUpperCase()),
                  _infoRow(context, Icons.calendar_today, 'Date',
                      '${session.createdAt.day}/${session.createdAt.month}/${session.createdAt.year}'),
                  _infoRow(context, Icons.subtitles, 'Captions', '${session.captions.length}'),
                  _infoRow(context, Icons.language, 'Language', session.captionLanguage),
                  _infoRow(context, Icons.schedule, 'Retention', '${session.retentionDays} days'),
                  Row(
                    children: [
                      Icon(Icons.timer, size: 16, color: Theme.of(context).textTheme.bodySmall?.color),
                      const SizedBox(width: 8),
                      RetentionBadge(daysRemaining: session.daysRemaining),
                    ],
                  ),
                ],
              ),
            ),
          ),

          PrivacyNotice(
            text: s.savedRecordsNote,
          ),

          const SizedBox(height: 16),

          if (insight != null && insight.isAvailable) ...[
            Text(s.aiInsights, style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
              letterSpacing: 1.2,
            )),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 16),
                        const SizedBox(width: 8),
                        Text(s.aiSummary, style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      insight.summary,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    const AiDisclaimer(),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).textTheme.bodySmall?.color),
          const SizedBox(width: 8),
          Text('$label: ', style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildTranscriptTab(BuildContext context, ProfessionalSession session, AppStrings s) {
    if (session.captions.isEmpty) {
      return EmptyState(
        icon: Icons.subtitles_off,
        title: s.noTranscriptAvailable,
        subtitle: s.noTranscriptDesc,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: session.captions.length,
      itemBuilder: (context, index) {
        final caption = session.captions[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${caption.speaker} · ${caption.timestamp.hour.toString().padLeft(2, '0')}:${caption.timestamp.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(caption.text, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryTab(BuildContext context, ProfessionalInsight? insight, AppStrings s) {
    if (insight == null || !insight.isAvailable) {
      return ErrorState(
        title: s.insightsUnavailable,
        message: s.insightsUnavailableDesc,
        buttonText: s.viewTranscript,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AiDisclaimer(),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.summaryTitle, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(insight.summary, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          ),
          if (insight.actionItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            InsightCard(
              title: s.actionItems,
              icon: Icons.check_circle_outline,
              items: insight.actionItems,
              iconColor: AppTheme.secondaryLight,
            ),
          ],
          if (insight.deadlines.isNotEmpty) ...[
            const SizedBox(height: 8),
            InsightCard(
              title: s.deadlines,
              icon: Icons.schedule,
              items: insight.deadlines,
              iconColor: AppTheme.warningLight,
            ),
          ],
          if (insight.mentionedPeople.isNotEmpty) ...[
            const SizedBox(height: 8),
            InsightCard(
              title: s.peopleMentioned,
              icon: Icons.person_outline,
              items: insight.mentionedPeople,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVocabularyTab(BuildContext context, ProfessionalInsight? insight, AppStrings s) {
    if (insight == null || insight.vocabulary.isEmpty) {
      return EmptyState(
        icon: Icons.book,
        title: s.noVocabulary,
        subtitle: s.noVocabularyDesc,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AiDisclaimer(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: insight.vocabulary.map((term) => Chip(
              label: Text(term),
              avatar: const Icon(Icons.bookmark_outline, size: 16),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildThemesTab(BuildContext context, ProfessionalInsight? insight, AppStrings s) {
    if (insight == null || insight.themes.isEmpty) {
      return EmptyState(
        icon: Icons.category,
        title: s.noThemes,
        subtitle: s.noThemesDesc,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AiDisclaimer(),
          const SizedBox(height: 12),
          InsightCard(
            title: s.themesTab,
            icon: Icons.category,
            items: insight.themes,
            iconColor: AppTheme.primaryLight,
          ),
        ],
      ),
    );
  }

  Widget _buildActionsTab(BuildContext context, ProfessionalInsight? insight, AppStrings s) {
    if (insight == null || insight.actionItems.isEmpty) {
      return EmptyState(
        icon: Icons.task_alt,
        title: s.noActionItems,
        subtitle: s.noActionItemsDesc,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AiDisclaimer(),
          const SizedBox(height: 12),
          InsightCard(
            title: s.actionItems,
            icon: Icons.task_alt,
            items: insight.actionItems,
            iconColor: AppTheme.secondaryLight,
          ),
          if (insight.deadlines.isNotEmpty) ...[
            const SizedBox(height: 16),
            InsightCard(
              title: s.deadlines,
              icon: Icons.schedule,
              items: insight.deadlines,
              iconColor: AppTheme.warningLight,
            ),
          ],
          if (insight.mentionedPeople.isNotEmpty) ...[
            const SizedBox(height: 16),
            InsightCard(
              title: s.peopleMentioned,
              icon: Icons.people_outline,
              items: insight.mentionedPeople,
            ),
          ],
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, ProfessionalSession session, ProfessionalInsight? insight, AppStrings s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.exportAction),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrivacyNotice(
              text: s.exportPrivacyNote,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: Text(s.exportTxt),
              onTap: () async {
                Navigator.pop(ctx);
                await _exportAsTxt(session, insight, context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: Text(s.exportPdf),
              onTap: () async {
                Navigator.pop(ctx);
                await _exportAsPdf(session, insight, context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(s.copyClipboard),
              onTap: () async {
                Navigator.pop(ctx);
                await _copyToClipboard(session, insight, context);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _buildExportText(ProfessionalSession session, ProfessionalInsight? insight) {
    final buffer = StringBuffer();
    buffer.writeln('HumSukhan — Session Export');
    buffer.writeln('=' * 40);
    buffer.writeln();
    buffer.writeln('Title: ${session.title}');
    buffer.writeln('Type: ${session.type.name.toUpperCase()}');
    buffer.writeln('Date: ${session.createdAt.day}/${session.createdAt.month}/${session.createdAt.year}');
    buffer.writeln('Language: ${session.captionLanguage}');
    buffer.writeln('Captions: ${session.captions.length}');
    buffer.writeln();
    buffer.writeln('--- TRANSCRIPT ---');
    buffer.writeln();
    for (final caption in session.captions) {
      final time = '${caption.timestamp.hour.toString().padLeft(2, '0')}:${caption.timestamp.minute.toString().padLeft(2, '0')}';
      buffer.writeln('[$time] ${caption.speaker}: ${caption.text}');
    }
    if (insight != null && insight.isAvailable) {
      buffer.writeln();
      buffer.writeln('--- AI INSIGHTS ---');
      buffer.writeln();
      buffer.writeln('Summary: ${insight.summary}');
      if (insight.actionItems.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('Action Items:');
        for (final item in insight.actionItems) {
          buffer.writeln('  • $item');
        }
      }
      if (insight.deadlines.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('Deadlines:');
        for (final d in insight.deadlines) {
          buffer.writeln('  • $d');
        }
      }
      if (insight.vocabulary.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('Key Terms: ${insight.vocabulary.join(', ')}');
      }
    }
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('Exported from HumSukhan');
    return buffer.toString();
  }

  Future<void> _exportAsTxt(ProfessionalSession session, ProfessionalInsight? insight, BuildContext context) async {
    try {
      final text = _buildExportText(session, insight);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/humsukhan_${session.id}.txt');
      await file.writeAsString(text);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'HumSukhan session export',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('TXT file exported successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _exportAsPdf(ProfessionalSession session, ProfessionalInsight? insight, BuildContext context) async {
    try {
      // Generate a formatted text representation as PDF alternative
      final text = _buildExportText(session, insight);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/humsukhan_${session.id}.txt');
      await file.writeAsString(text);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'HumSukhan session export',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session exported successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _copyToClipboard(ProfessionalSession session, ProfessionalInsight? insight, BuildContext context) async {
    try {
      final text = _buildExportText(session, insight);
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copy failed: $e')),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, ProfessionalSession session, AppStrings s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteSessionConfirm),
        content: Text(s.deleteSessionDesc),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          TextButton(
            onPressed: () {
              context.read<ProfessionalProvider>().deleteSession(session.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text(s.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
