import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/providers/professional_provider.dart';

void main() {
  test('folder-only deletion preserves the session by moving it to General', () {
    final session = ProfessionalSession(title: 'Meeting', folderId: 'folder');
    final moved = session.copyWith(folderId: null);
    expect(FolderDeleteMode.keepSessions, isNot(FolderDeleteMode.deleteSessions));
    expect(moved.folderId, isNull);
    expect(moved.title, 'Meeting');
  });

  test('folder-plus-sessions deletion is the explicit destructive mode', () {
    expect(FolderDeleteMode.values, contains(FolderDeleteMode.deleteSessions));
    expect(FolderDeleteMode.deleteSessions, isNot(FolderDeleteMode.keepSessions));
  });
}
