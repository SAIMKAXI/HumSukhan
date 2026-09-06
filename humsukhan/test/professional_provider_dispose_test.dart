import 'package:flutter_test/flutter_test.dart';

import 'package:humsukhan/providers/professional_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('notifyListeners is safe after provider disposal', () {
    final provider = ProfessionalProvider();
    provider.dispose();

    expect(provider.notifyListeners, returnsNormally);
  });
}
