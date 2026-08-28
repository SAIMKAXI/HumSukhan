import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/reusable_widgets.dart';
import '../navigation/app_router.dart';

class ProfessionalScreen extends StatefulWidget {
  const ProfessionalScreen({super.key});

  @override
  State<ProfessionalScreen> createState() => _ProfessionalScreenState();
}

class _ProfessionalScreenState extends State<ProfessionalScreen> {
  @override
  void initState() {
    super.initState();
    // Add demo data if empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pro = context.read<ProfessionalProvider>();
      if (pro.sessions.isEmpty) {
        pro.addDemoSession();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pro = context.watch<ProfessionalProvider>();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Professional'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sessions', icon: Icon(Icons.event_note)),
              Tab(text: 'Folders', icon: Icon(Icons.folder)),
              Tab(text: 'Classes', icon: Icon(Icons.school)),
              Tab(text: 'Meetings', icon: Icon(Icons.meeting_room)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSessionsTab(context, pro),
            _buildFoldersTab(context, pro),
            _buildClassesTab(context, pro),
            _buildMeetingsTab(context, pro),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreateSessionDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('New Session'),
        ),
      ),
    );
  }

  Widget _buildSessionsTab(BuildContext context, ProfessionalProvider pro) {
    if (pro.sessions.isEmpty) {
      return EmptyState(
        icon: Icons.event_note,
        title: 'No saved sessions yet',
        subtitle: 'Start a Professional session when you are ready to capture a lecture or meeting.',
        buttonText: 'Start Session',
        onButtonPressed: () => _showCreateSessionDialog(context),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      children: [
        if (pro.recentSessions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'RECENT',
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
              onDelete: () => _confirmDelete(context, session),
            ),
          ),
        ],
        if (pro.sessions.where((s) => s.status == SessionStatus.completed && !pro.recentSessions.contains(s)).isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'ALL SESSIONS',
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
                  onDelete: () => _confirmDelete(context, session),
                ),
              ),
        ],
      ],
    );
  }

  Widget _buildFoldersTab(BuildContext context, ProfessionalProvider pro) {
    return Column(
      children: [
        // General folder (always exists)
        ListTile(
          leading: Icon(Icons.folder, color: AppTheme.primaryLight),
          title: const Text('General'),
          subtitle: Text('${pro.getSessionsForFolder(null).length} sessions'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
        const Divider(),

        // Custom folders
        Expanded(
          child: pro.folders.isEmpty
              ? EmptyState(
                  icon: Icons.folder_open,
                  title: 'No folders yet',
                  subtitle: 'Create a folder to organize your sessions.',
                  buttonText: 'Create Folder',
                  onButtonPressed: () => _showCreateFolderDialog(context),
                )
              : ListView.builder(
                  itemCount: pro.folders.length,
                  itemBuilder: (context, index) {
                    final folder = pro.folders[index];
                    final sessionCount = pro.getSessionsForFolder(folder.id).length;
                    return ListTile(
                      leading: Icon(Icons.folder, color: AppTheme.primaryLight),
                      title: Text(folder.name),
                      subtitle: Text('$sessionCount sessions'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => _confirmDeleteFolder(context, pro, folder),
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

  Widget _buildClassesTab(BuildContext context, ProfessionalProvider pro) {
    final classSessions = pro.sessions.where((s) => s.type == SessionType.class_).toList();
    if (classSessions.isEmpty) {
      return EmptyState(
        icon: Icons.school,
        title: 'No class sessions',
        subtitle: 'Start a session and select "Class" as the type to see them here.',
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

  Widget _buildMeetingsTab(BuildContext context, ProfessionalProvider pro) {
    final meetingSessions = pro.sessions.where((s) => s.type == SessionType.meeting).toList();
    if (meetingSessions.isEmpty) {
      return EmptyState(
        icon: Icons.meeting_room,
        title: 'No meeting sessions',
        subtitle: 'Start a session and select "Meeting" as the type to see them here.',
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

  void _showCreateSessionDialog(BuildContext context) {
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
              Text('New Session', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Session Title',
                  hintText: 'e.g., Product Launch Planning',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<SessionType>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Session Type'),
                items: const [
                  DropdownMenuItem(value: SessionType.meeting, child: Text('Meeting')),
                  DropdownMenuItem(value: SessionType.lecture, child: Text('Lecture')),
                  DropdownMenuItem(value: SessionType.class_, child: Text('Class')),
                ],
                onChanged: (v) => setModalState(() => selectedType = v ?? selectedType),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: retentionDays,
                decoration: const InputDecoration(labelText: 'Retention Period'),
                items: RetentionPolicy.options.map((r) =>
                  DropdownMenuItem(value: r.days, child: Text(r.label)),
                ).toList(),
                onChanged: (v) => setModalState(() => retentionDays = v ?? retentionDays),
              ),
              const SizedBox(height: 24),
              PrimaryActionButton(
                label: 'Start Session',
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

  void _showCreateFolderDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Folder name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await context.read<ProfessionalProvider>().createFolder(controller.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, ProfessionalSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session?'),
        content: const Text('This will permanently remove the saved transcript and insights. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<ProfessionalProvider>().deleteSession(session.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFolder(BuildContext context, ProfessionalProvider pro, Folder folder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: Text(
          'Existing sessions will be moved to the General folder. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              pro.deleteFolder(folder.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
