import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/reusable_widgets.dart';
import '../navigation/app_router.dart';
import '../l10n/app_strings.dart';

class ProfessionalScreen extends StatefulWidget {
  const ProfessionalScreen({super.key});

  @override
  State<ProfessionalScreen> createState() => _ProfessionalScreenState();
}

class _ProfessionalScreenState extends State<ProfessionalScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final pro = context.watch<ProfessionalProvider>();
    final s = AppStrings.of(context);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.professionalTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: s.sessionsTab, icon: const Icon(Icons.event_note)),
              Tab(text: s.foldersTab, icon: const Icon(Icons.folder)),
              Tab(text: s.classesTab, icon: const Icon(Icons.school)),
              Tab(text: s.meetingsTab, icon: const Icon(Icons.meeting_room)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSessionsTab(context, pro, s),
            _buildFoldersTab(context, pro, s),
            _buildClassesTab(context, pro, s),
            _buildMeetingsTab(context, pro, s),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreateSessionDialog(context, s),
          icon: const Icon(Icons.add),
          label: Text(s.newSession),
        ),
      ),
    );
  }

  Widget _buildSessionsTab(BuildContext context, ProfessionalProvider pro, AppStrings s) {
    if (pro.sessions.isEmpty) {
      return EmptyState(
        icon: Icons.event_note,
        title: s.noSavedSessions,
        subtitle: s.noSavedSessionsDesc,
        buttonText: s.startSession,
        onButtonPressed: () => _showCreateSessionDialog(context, s),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      children: [
        if (pro.recentSessions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              s.recentLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...pro.recentSessions.map((session) =>
            SessionCard(
              session: session,
              insight: pro.getInsightForSession(session.id),
              onTap: () => Navigator.pushNamed(
                context,
                AppRouter.sessionDetail,
                arguments: session.id,
              ),
              onDelete: () => _confirmDelete(context, session, s),
            ),
          ),
        ],
        if (pro.sessions.where((s) => s.status == SessionStatus.completed && !pro.recentSessions.contains(s)).isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              s.allSessionsLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...pro.sessions
              .where((s) => s.status == SessionStatus.completed)
              .where((s) => !pro.recentSessions.contains(s))
              .map((session) =>
                SessionCard(
                  session: session,
                  insight: pro.getInsightForSession(session.id),
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRouter.sessionDetail,
                    arguments: session.id,
                  ),
                  onDelete: () => _confirmDelete(context, session, s),
                ),
              ),
        ],
      ],
    );
  }

  Widget _buildFoldersTab(BuildContext context, ProfessionalProvider pro, AppStrings s) {
    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.folder, color: AppTheme.primaryLight),
          title: Text(s.generalFolder),
          subtitle: Text('${pro.getSessionsForFolder(null).length} ${s.sessionsCount}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
        const Divider(),

        Expanded(
          child: pro.folders.isEmpty
              ? EmptyState(
                  icon: Icons.folder_open,
                  title: s.noFoldersYet,
                  subtitle: s.noFoldersDesc,
                  buttonText: s.createFolder,
                  onButtonPressed: () => _showCreateFolderDialog(context, s),
                )
              : ListView.builder(
                  itemCount: pro.folders.length,
                  itemBuilder: (context, index) {
                    final folder = pro.folders[index];
                    final sessionCount = pro.getSessionsForFolder(folder.id).length;
                    return ListTile(
                      leading: Icon(Icons.folder, color: AppTheme.primaryLight),
                      title: Text(folder.name),
                      subtitle: Text('$sessionCount ${s.sessionsCount}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => _confirmDeleteFolder(context, pro, folder, s),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildClassesTab(BuildContext context, ProfessionalProvider pro, AppStrings s) {
    final classSessions = pro.sessions.where((s) => s.type == SessionType.class_).toList();
    if (classSessions.isEmpty) {
      return EmptyState(
        icon: Icons.school,
        title: s.noClassSessions,
        subtitle: s.noClassSessionsDesc,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: classSessions.length,
      itemBuilder: (context, index) {
        final session = classSessions[index];
        return SessionCard(
          session: session,
          insight: pro.getInsightForSession(session.id),
          onTap: () => Navigator.pushNamed(context, AppRouter.sessionDetail, arguments: session.id),
        );
      },
    );
  }

  Widget _buildMeetingsTab(BuildContext context, ProfessionalProvider pro, AppStrings s) {
    final meetingSessions = pro.sessions.where((s) => s.type == SessionType.meeting).toList();
    if (meetingSessions.isEmpty) {
      return EmptyState(
        icon: Icons.meeting_room,
        title: s.noMeetingSessions,
        subtitle: s.noMeetingSessionsDesc,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: meetingSessions.length,
      itemBuilder: (context, index) {
        final session = meetingSessions[index];
        return SessionCard(
          session: session,
          insight: pro.getInsightForSession(session.id),
          onTap: () => Navigator.pushNamed(context, AppRouter.sessionDetail, arguments: session.id),
        );
      },
    );
  }

  void _showCreateSessionDialog(BuildContext context, AppStrings s) {
    final titleController = TextEditingController();
    SessionType selectedType = SessionType.meeting;
    int retentionDays = 7;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.newSession, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: s.sessionTitle,
                  hintText: s.sessionTitleHint,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<SessionType>(
                initialValue: selectedType,
                decoration: InputDecoration(labelText: s.sessionType),
                items: [
                  DropdownMenuItem(value: SessionType.meeting, child: Text(s.meetingType)),
                  DropdownMenuItem(value: SessionType.lecture, child: Text(s.lectureType)),
                  DropdownMenuItem(value: SessionType.class_, child: Text(s.classType)),
                ],
                onChanged: (v) => setModalState(() => selectedType = v ?? selectedType),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: retentionDays,
                decoration: InputDecoration(labelText: s.retentionPeriod),
                items: [
                  DropdownMenuItem(value: 1, child: Text(s.retention1Day)),
                  DropdownMenuItem(value: 7, child: Text(s.retention7Days)),
                  DropdownMenuItem(value: 15, child: Text(s.retention15Days)),
                ],
                onChanged: (v) => setModalState(() => retentionDays = v ?? retentionDays),
              ),
              const SizedBox(height: 24),
              PrimaryActionButton(
                label: s.startSession,
                icon: Icons.play_arrow,
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) return;
                  final pro = context.read<ProfessionalProvider>();
                  final session = await pro.createSession(
                    title: titleController.text.trim(),
                    type: selectedType,
                    retentionDays: retentionDays,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    Navigator.pushNamed(context, AppRouter.sessionLive, arguments: session.id);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context, AppStrings s) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.createFolder),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: s.folderName),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await context.read<ProfessionalProvider>().createFolder(controller.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: Text(s.create),
          ),
        ],
      ),
    );
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
            },
            child: Text(s.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFolder(BuildContext context, ProfessionalProvider pro, Folder folder, AppStrings s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteFolderConfirm),
        content: Text(s.deleteFolderDesc),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          TextButton(
            onPressed: () {
              pro.deleteFolder(folder.id);
              Navigator.pop(ctx);
            },
            child: Text(s.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
