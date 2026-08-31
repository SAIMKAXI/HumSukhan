import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
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
  Widget build(BuildContext context) {
    final pro = context.watch<ProfessionalProvider>();
    final s = AppStrings.of(context);
    return DefaultTabController(
      length: 4,
      child: Builder(builder: (context) {
        final controller = DefaultTabController.of(context);
        return Scaffold(
          appBar: AppBar(
            title: Text(s.professionalTitle),
            bottom: TabBar(
              onTap: (_) => setState(() {}),
              isScrollable: true,
              tabs: const [
                Tab(text: 'Folders', icon: Icon(Icons.folder_outlined)),
                Tab(text: 'Classes', icon: Icon(Icons.school_outlined)),
                Tab(text: 'Meetings', icon: Icon(Icons.meeting_room_outlined)),
                Tab(text: 'Lectures', icon: Icon(Icons.menu_book_outlined)),
              ],
            ),
          ),
          body: TabBarView(children: [
            _buildFoldersTab(context, pro, s),
            _buildTypeTab(context, pro, SessionType.class_, 'Classes', Icons.school_outlined),
            _buildTypeTab(context, pro, SessionType.meeting, 'Meetings', Icons.meeting_room_outlined),
            _buildTypeTab(context, pro, SessionType.lecture, 'Lectures', Icons.menu_book_outlined),
          ]),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showCreateSessionDialog(context, s, presetType: _typeForTab(controller.index)),
            icon: const Icon(Icons.add),
            label: Text(s.newSession),
          ),
        );
      }),
    );
  }

  SessionType? _typeForTab(int index) {
    switch (index) {
      case 1: return SessionType.class_;
      case 2: return SessionType.meeting;
      case 3: return SessionType.lecture;
      default: return null;
    }
  }

  Widget _buildFoldersTab(BuildContext context, ProfessionalProvider pro, AppStrings s) {
    final generalSessions = pro.getSessionsForFolder(null)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ListView(padding: const EdgeInsets.only(top: 8, bottom: 96), children: [
      ListTile(leading: const Icon(Icons.folder, size: 32), title: Text(s.generalFolder), subtitle: Text('${generalSessions.length} ${s.sessionsCount}'), trailing: const Icon(Icons.chevron_right), onTap: () => _showFolderSessions(context, s.generalFolder, generalSessions)),
      const Divider(),
      if (pro.folders.isEmpty)
        EmptyState(icon: Icons.folder_open, title: s.noFoldersYet, subtitle: s.noFoldersDesc, buttonText: s.createFolder, onButtonPressed: () => _showCreateFolderDialog(context, s))
      else
        ...pro.folders.map((folder) {
          final sessions = pro.getSessionsForFolder(folder.id)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return ListTile(leading: const Icon(Icons.folder_outlined, size: 30), title: Text(folder.name), subtitle: Text('${sessions.length} ${s.sessionsCount}'), trailing: const Icon(Icons.chevron_right), onTap: () => _showFolderSessions(context, folder.name, sessions));
        }),
    ]);
  }

  Widget _buildTypeTab(BuildContext context, ProfessionalProvider pro, SessionType type, String title, IconData icon) {
    final sessions = pro.sessions.where((s) => s.type == type).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final strings = AppStrings.of(context);
    return ListView(padding: const EdgeInsets.only(top: 8, bottom: 96), children: [
      if (sessions.isEmpty)
        Padding(padding: const EdgeInsets.all(24), child: EmptyState(icon: icon, title: 'No $title yet', subtitle: 'Start a new $title session and your transcript will appear here.', buttonText: strings.startSession, onButtonPressed: () => _showCreateSessionDialog(context, strings, presetType: type)))
      else
        ...sessions.map((session) => SessionCard(session: session, insight: pro.getInsightForSession(session.id), onTap: () => Navigator.pushNamed(context, AppRouter.sessionDetail, arguments: session.id), onDelete: () => _confirmDelete(context, session, strings))),
    ]);
  }

  void _showFolderSessions(BuildContext context, String name, List<ProfessionalSession> sessions) {
    final pro = context.read<ProfessionalProvider>();
    final s = AppStrings.of(context);
    showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) => SizedBox(height: MediaQuery.of(ctx).size.height * .75, child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 8, 12, 8), child: Row(children: [const Icon(Icons.folder, size: 24), const SizedBox(width: 8), Expanded(child: Text(name, style: Theme.of(ctx).textTheme.titleLarge))])),
      Expanded(child: sessions.isEmpty ? EmptyState(icon: Icons.inbox_outlined, title: s.noSavedSessions, subtitle: s.noSavedSessionsDesc) : ListView.builder(itemCount: sessions.length, itemBuilder: (_, i) => SessionCard(session: sessions[i], insight: pro.getInsightForSession(sessions[i].id), onTap: () { Navigator.pop(ctx); Navigator.pushNamed(context, AppRouter.sessionDetail, arguments: sessions[i].id); }))),
    ])));
  }

  void _showCreateSessionDialog(BuildContext context, AppStrings s, {SessionType? presetType}) {
    final titleController = TextEditingController();
    final settings = context.read<SettingsProvider>();
    final pro = context.read<ProfessionalProvider>();
    SessionType selectedType = presetType ?? SessionType.meeting;
    int retentionDays = settings.defaultRetentionDays;
    String? selectedFolderId;
    showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(presetType == null ? s.newSession : 'New ${_typeLabel(presetType)}', style: Theme.of(ctx).textTheme.headlineSmall),
        const SizedBox(height: 20),
        TextField(controller: titleController, decoration: InputDecoration(labelText: s.sessionTitle, hintText: s.sessionTitleHint), autofocus: true),
        const SizedBox(height: 16),
        if (presetType == null) DropdownButtonFormField<SessionType>(initialValue: selectedType, decoration: InputDecoration(labelText: s.sessionType), items: const [DropdownMenuItem(value: SessionType.meeting, child: Text('Meeting')), DropdownMenuItem(value: SessionType.lecture, child: Text('Lecture')), DropdownMenuItem(value: SessionType.class_, child: Text('Class'))], onChanged: (v) => setState(() => selectedType = v ?? selectedType)) else InputDecorator(decoration: InputDecoration(labelText: s.sessionType), child: Text(_typeLabel(selectedType))),
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(initialValue: selectedFolderId, decoration: const InputDecoration(labelText: 'Folder'), items: [const DropdownMenuItem<String?>(value: null, child: Text('General')), ...pro.folders.map((folder) => DropdownMenuItem<String?>(value: folder.id, child: Text(folder.name)))], onChanged: (v) => setState(() => selectedFolderId = v)),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(initialValue: retentionDays, decoration: InputDecoration(labelText: s.retentionPeriod), items: [DropdownMenuItem(value: 1, child: Text(s.retention1Day)), DropdownMenuItem(value: 7, child: Text(s.retention7Days)), DropdownMenuItem(value: 15, child: Text(s.retention15Days))], onChanged: (v) => setState(() => retentionDays = v ?? retentionDays)),
        const SizedBox(height: 24),
        PrimaryActionButton(label: s.startSession, icon: Icons.play_arrow, onPressed: () async {
          final title = titleController.text.trim();
          if (title.isEmpty) return;
          final session = await pro.createSession(title: title, type: selectedType, folderId: selectedFolderId, retentionDays: retentionDays);
          if (ctx.mounted) Navigator.pop(ctx);
          if (context.mounted) Navigator.pushNamed(context, AppRouter.sessionLive, arguments: session.id);
        }),
      ]),),
    )));
  }

  String _typeLabel(SessionType type) => switch (type) { SessionType.class_ => 'Class', SessionType.meeting => 'Meeting', SessionType.lecture => 'Lecture' };

  void _showCreateFolderDialog(BuildContext context, AppStrings s) {
    final controller = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(s.createFolder), content: TextField(controller: controller, decoration: InputDecoration(hintText: s.folderName), autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)), TextButton(onPressed: () async { final name = controller.text.trim(); if (name.isEmpty) return; await context.read<ProfessionalProvider>().createFolder(name); if (ctx.mounted) Navigator.pop(ctx); }, child: Text(s.create))]));
  }

  void _confirmDelete(BuildContext context, ProfessionalSession session, AppStrings s) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(s.deleteSessionConfirm), content: Text(s.deleteSessionDesc), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)), TextButton(onPressed: () { context.read<ProfessionalProvider>().deleteSession(session.id); Navigator.pop(ctx); }, child: Text(s.delete, style: TextStyle(color: Theme.of(ctx).colorScheme.error)))]));
  }
}
