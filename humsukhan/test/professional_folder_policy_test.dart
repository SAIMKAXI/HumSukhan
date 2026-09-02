import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';

void main() {
  test('folder deletion policy keeps sessions addressable through General', () {
    final session = ProfessionalSession(title: 'Meeting', folderId: 'folder');
    final moved = session.copyWith(folderId: null);
    expect(moved.folderId, isNull);
    expect(moved.title, 'Meeting');
    expect(moved.captions, isEmpty);
  });
}
