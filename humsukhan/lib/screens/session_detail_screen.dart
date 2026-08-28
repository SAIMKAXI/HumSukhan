import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/reusable_widgets.dart';

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

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(session.title),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Transcript'),
              Tab(text: 'Summary'),
              Tab(text: 'Vocabulary'),
              Tab(text: 'Themes'),
              Tab(text: 'Actions'),
            ],
          ),
          actions: [
            PopupMenuButton(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'export', child: Text('Export')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (value) {
                if (value == 'export') _showExportDialog(context, session, insight);
                if (value == 'delete') _confirmDelete(context, session);
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildOverviewTab(context, session, insight),
            _buildTranscriptTab(context, session),
            _buildSummaryTab(context, insight),
            _buildVocabularyTab(context, insight),
            _buildThemesTab(context, insight),
            _buildActionsTab(context, insight),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, ProfessionalSession session, ProfessionalInsight? insight) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session info card
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

          // Privacy notice
          const PrivacyNotice(
            text: 'Saved records contain captions and metadata. Raw audio is not stored.',
          ),

          const SizedBox(height: 16),

          // Quick insight preview
          if (insight != null && insight.isAvailable) ...[
            Text('AI INSIGHTS', style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
                        Text('AI Summary', style: Theme.of(context).textTheme.titleMedium),
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

  Widget _buildTranscriptTab(BuildContext context, ProfessionalSession session) {
    if (session.captions.isEmpty) {
      return const EmptyState(
        icon: Icons.subtitles_off,
        title: 'No transcript available',
        subtitle: 'No transcript was captured. You can start a new session to capture a transcript.',
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

  Widget _buildSummaryTab(BuildContext context, ProfessionalInsight? insight) {
    if (insight == null || !insight.isAvailable) {
      return const ErrorState(
        title: 'Insights unavailable',
        message: 'We couldn\'t generate AI insights for this session. Your original transcript is still available.',
        buttonText: 'View Transcript',
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
                  Text('Summary', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(insight.summary, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          ),
          if (insight.actionItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            InsightCard(
              title: 'Action Items',
              icon: Icons.check_circle_outline,
              items: insight.actionItems,
              iconColor: AppTheme.secondaryLight,
            ),
          ],
          if (insight.deadlines.isNotEmpty) ...[
            const SizedBox(height: 8),
            InsightCard(
              title: 'Deadlines',
              icon: Icons.schedule,
              items: insight.deadlines,
              iconColor: AppTheme.warningLight,
            ),
          ],
          if (insight.mentionedPeople.isNotEmpty) ...[
            const SizedBox(height: 8),
            InsightCard(
              title: 'People Mentioned',
              icon: Icons.person_outline,
              items: insight.mentionedPeople,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVocabularyTab(BuildContext context, ProfessionalInsight? insight) {
    if (insight == null || insight.vocabulary.isEmpty) {
      return const EmptyState(
        icon: Icons.book,
        title: 'No vocabulary',
        subtitle: 'Key terms will appear here after AI analysis.',
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

  Widget _buildThemesTab(BuildContext context, ProfessionalInsight? insight) {
    if (insight == null || insight.themes.isEmpty) {
      return const EmptyState(
        icon: Icons.category,
        title: 'No themes',
        subtitle: 'Themes will appear here after AI analysis.',
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
            title: 'Themes',
            icon: Icons.category,
            items: insight.themes,
            iconColor: AppTheme.primaryLight,
          ),
        ],
      ),
    );
  }

  Widget _buildActionsTab(BuildContext context, ProfessionalInsight? insight) {
    if (insight == null || insight.actionItems.isEmpty) {
      return const EmptyState(
        icon: Icons.task_alt,
        title: 'No action items',
        subtitle: 'Action items will appear here after AI analysis.',
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
            title: 'Action Items',
            icon: Icons.task_alt,
            items: insight.actionItems,
            iconColor: AppTheme.secondaryLight,
          ),
          if (insight.deadlines.isNotEmpty) ...[
            const SizedBox(height: 16),
            InsightCard(
              title: 'Deadlines',
              icon: Icons.schedule,
              items: insight.deadlines,
              iconColor: AppTheme.warningLight,
            ),
          ],
          if (insight.mentionedPeople.isNotEmpty) ...[
            const SizedBox(height: 16),
            InsightCard(
              title: 'People Mentioned',
              icon: Icons.people_outline,
              items: insight.mentionedPeople,
            ),
          ],
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, ProfessionalSession session, ProfessionalInsight? insight) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PrivacyNotice(
              text: 'Exported files are stored outside HumSukhan and won\'t be automatically deleted.',
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text('Export as TXT'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('TXT export ready (demo)')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export as PDF'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF export ready (demo)')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy to Clipboard'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard (demo)')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ProfessionalSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session?'),
        content: const Text('This will permanently remove the saved transcript and insights.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<ProfessionalProvider>().deleteSession(session.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
