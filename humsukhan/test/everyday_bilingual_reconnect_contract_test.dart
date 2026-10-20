import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('English and Urdu reconnect attempts are isolated per source', () {
    final source = File('lib/services/everyday_bilingual_stt.dart').readAsStringSync();

    expect(source, contains("final Set<String> _reconnectingSources = <String>{};"));
    expect(source, contains("final Map<String, int> _reconnectAttempts = <String, int>{};"));
    expect(source, contains("if (_reconnectingSources.contains(source)) return;"));
    expect(source, contains("_reconnectingSources.add(source);"));
    expect(source, contains("_reconnectingSources.remove(source);"));
    expect(source, contains("final attempts = _reconnectAttempts[source] ?? 0;"));
    expect(source, contains("_reconnectAttempts[source] = attempts + 1;"));
    expect(source, contains("_reconnectAttempts[source] = 0;"));

    expect(source, isNot(contains('bool _reconnecting = false;')));
    expect(source, isNot(contains('int _reconnectAttempts = 0;')));
  });
}
