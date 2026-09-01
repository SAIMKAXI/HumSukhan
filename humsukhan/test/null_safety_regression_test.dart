import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/services/auth_service.dart';
import 'package:humsukhan/services/database_service.dart';
import 'package:humsukhan/services/supabase_service.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/main.dart';

void main() {
  group('SupabaseService safety when not initialized', () {
    test('isReady returns false when Supabase is not initialized', () {
      final service = SupabaseService.instance;
      expect(service.isReady, isFalse);
    });

    test('client returns null when Supabase is not ready', () {
      final service = SupabaseService.instance;
      expect(service.client, isNull);
    });

    test('onAuthStateChange returns listenable stream when not initialized', () {
      final service = SupabaseService.instance;
      expect(service.onAuthStateChange, isNotNull);
    });
  });

  group('AuthService safety when Supabase is unavailable', () {
    test('isAvailable reflects Supabase auth state', () {
      final auth = AuthService.instance;
      expect(auth.isAvailable, isFalse);
    });

    test('signIn returns failure when Supabase is unavailable', () async {
      final auth = AuthService.instance;
      if (!auth.isAvailable) {
        final result = await auth.signIn(
          email: 'test@test.com',
          password: 'Password1!',
        );
        expect(result.success, isFalse);
      }
    });

    test('signUp returns failure when Supabase is unavailable', () async {
      final auth = AuthService.instance;
      if (!auth.isAvailable) {
        final result = await auth.signUp(
          email: 'test@test.com',
          password: 'Password1!',
        );
        expect(result.success, isFalse);
      }
    });

    test('signInAnonymously returns failure when Supabase is unavailable', () async {
      final auth = AuthService.instance;
      if (!auth.isAvailable) {
        final result = await auth.signInAnonymously();
        expect(result.success, isFalse);
      }
    });

    test('signOut does not throw when Supabase is unavailable', () async {
      final auth = AuthService.instance;
      if (!auth.isAvailable) {
        expect(() => auth.signOut(), returnsNormally);
        await auth.signOut();
      }
    });

    test('resetPassword returns failure when Supabase is unavailable', () async {
      final auth = AuthService.instance;
      if (!auth.isAvailable) {
        final result = await auth.resetPassword('test@test.com');
        expect(result.success, isFalse);
      }
    });
  });

  group('DatabaseService safety when Supabase is unavailable', () {
    test('upsertProfile returns without error when unavailable', () async {
      final db = DatabaseService.instance;
      final profile = UserProfile(name: 'Test');
      await db.upsertProfile(profile);
    });

    test('fetchProfile returns null when unavailable', () async {
      final db = DatabaseService.instance;
      expect(await db.fetchProfile('test-user'), isNull);
    });

    test('fetchSessions returns empty list when unavailable', () async {
      final db = DatabaseService.instance;
      expect(await db.fetchSessions(), isEmpty);
    });

    test('fetchFolders returns empty list when unavailable', () async {
      final db = DatabaseService.instance;
      expect(await db.fetchFolders(), isEmpty);
    });

    test('fetchQuickReplies returns empty list when unavailable', () async {
      final db = DatabaseService.instance;
      expect(await db.fetchQuickReplies(), isEmpty);
    });

    test('cleanupExpiredSessions returns 0 when unavailable', () async {
      final db = DatabaseService.instance;
      expect(await db.cleanupExpiredSessions(), 0);
    });

    test('deleteSession does not throw when unavailable', () async {
      final db = DatabaseService.instance;
      await db.deleteSession('test-session');
    });

    test('deleteFolder does not throw when unavailable', () async {
      final db = DatabaseService.instance;
      await db.deleteFolder('test-folder');
    });

    test('deleteAllUserData does not throw when unavailable', () async {
      final db = DatabaseService.instance;
      await db.deleteAllUserData();
    });
  });

  group('App cold start safety', () {
    testWidgets('App mounts startup screen without crashing', (tester) async {
      await tester.pumpWidget(const HumSukhanApp());
      await tester.pump();
      expect(find.byType(HumSukhanApp), findsOneWidget);
    });

    testWidgets('App handles missing Supabase gracefully', (tester) async {
      await tester.pumpWidget(const HumSukhanApp());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
