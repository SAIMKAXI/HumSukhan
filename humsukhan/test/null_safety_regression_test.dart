import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/main.dart';
import 'package:humsukhan/services/supabase_service.dart';
import 'package:humsukhan/services/auth_service.dart';
import 'package:humsukhan/services/database_service.dart';
import 'package:humsukhan/models/models.dart';

void main() {
  group('SupabaseService safety when not initialized', () {
    test('isReady returns false when Supabase is not initialized', () {
      final service = SupabaseService.instance;
      // Accessing these getters must NEVER throw, even if Supabase
      // was never initialized (e.g. empty SUPABASE_ANON_KEY)
      expect(() => service.isReady, returnsNormally);
      expect(() => service.client, returnsNormally);
      expect(() => service.auth, returnsNormally);
      expect(() => service.currentUser, returnsNormally);
      expect(() => service.isAuthenticated, returnsNormally);
      expect(() => service.userId, returnsNormally);
    });

    test('client returns null when Supabase is not ready', () {
      final service = SupabaseService.instance;
      if (!service.isReady) {
        expect(service.client, isNull);
        expect(service.auth, isNull);
        expect(service.currentUser, isNull);
        expect(service.isAuthenticated, isFalse);
        expect(service.userId, isEmpty);
      }
    });

    test('onAuthStateChange returns listenable stream when not initialized', () {
      final service = SupabaseService.instance;
      if (!service.isReady) {
        final stream = service.onAuthStateChange;
        expect(stream, isNotNull);
        // Should not throw when listening to the stream
        late bool gotEvent;
        gotEvent = false;
        stream.listen((_) { gotEvent = true; });
        // No event should arrive since stream is empty
        expect(gotEvent, isFalse);
      }
    });
  });

  group('AuthService safety when Supabase is unavailable', () {
    test('isAvailable reflects Supabase auth state', () {
      final auth = AuthService.instance;
      final supabase = SupabaseService.instance;
      expect(auth.isAvailable, equals(supabase.auth != null));
    });

    test('signIn returns failure when Supabase is unavailable', () async {
      final auth = AuthService.instance;
      if (!auth.isAvailable) {
        final result = await auth.signIn(email: 'test@test.com', password: 'pass');
        expect(result.success, isFalse);
        expect(result.errorMessage, isNotNull);
        expect(result.user, isNull);
      }
    });

    test('signUp returns failure when Supabase is unavailable', () async {
      final auth = AuthService.instance;
      if (!auth.isAvailable) {
        final result = await auth.signUp(
          email: 'test@test.com',
          password: 'pass',
          name: 'Test',
        );
        expect(result.success, isFalse);
        expect(result.errorMessage, isNotNull);
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

    test('resetPassword returns false when Supabase is unavailable', () async {
      final auth = AuthService.instance;
      if (!auth.isAvailable) {
        final result = await auth.resetPassword('test@test.com');
        expect(result, isFalse);
      }
    });
  });

  group('DatabaseService safety when Supabase is unavailable', () {
    test('upsertProfile returns without error when unavailable', () async {
      final db = DatabaseService.instance;
      final profile = UserProfile(name: 'Test');
      // Must not throw even if Supabase is unavailable
      await db.upsertProfile(profile);
    });

    test('fetchProfile returns null when unavailable', () async {
      final db = DatabaseService.instance;
      final result = await db.fetchProfile('test-user-id');
      expect(result, isNull);
    });

    test('fetchSessions returns empty list when unavailable', () async {
      final db = DatabaseService.instance;
      final result = await db.fetchSessions();
      expect(result, isEmpty);
    });

    test('fetchFolders returns empty list when unavailable', () async {
      final db = DatabaseService.instance;
      final result = await db.fetchFolders();
      expect(result, isEmpty);
    });

    test('fetchQuickReplies returns empty list when unavailable', () async {
      final db = DatabaseService.instance;
      final result = await db.fetchQuickReplies();
      expect(result, isEmpty);
    });

    test('cleanupExpiredSessions returns 0 when unavailable', () async {
      final db = DatabaseService.instance;
      final result = await db.cleanupExpiredSessions();
      expect(result, equals(0));
    });

    test('deleteSession does not throw when unavailable', () async {
      final db = DatabaseService.instance;
      expect(() => db.deleteSession('test-id'), returnsNormally);
      await db.deleteSession('test-id');
    });

    test('deleteFolder does not throw when unavailable', () async {
      final db = DatabaseService.instance;
      expect(() => db.deleteFolder('test-id'), returnsNormally);
      await db.deleteFolder('test-id');
    });

    test('deleteAllUserData does not throw when unavailable', () async {
      final db = DatabaseService.instance;
      expect(() => db.deleteAllUserData(), returnsNormally);
      await db.deleteAllUserData();
    });
  });

  group('App cold start safety', () {
    testWidgets('App renders splash screen without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(const HumSukhanApp());
      await tester.pump();
      expect(find.text('HumSukhan'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('App handles missing Supabase gracefully', (WidgetTester tester) async {
      // This test verifies the app can start even when Supabase is not configured.
      // The SupabaseService catches initialization errors internally.
      await tester.pumpWidget(const HumSukhanApp());
      await tester.pump();
      // App should render without throwing null-check errors
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
