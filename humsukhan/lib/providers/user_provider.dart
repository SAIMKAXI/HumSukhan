import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/database_service.dart';

class UserProvider extends ChangeNotifier {
  UserProfile? _profile;
  bool _isLoading = false;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get hasProfile => _profile != null;

  UserProvider() {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('userProfile');
      if (json != null) _profile = UserProfile.fromJson(jsonDecode(json));

      final supabase = SupabaseService.instance;
      if (supabase.isAuthenticated) {
        final userId = supabase.userId;
        final cloudProfile = await DatabaseService.instance.fetchProfile(userId);
        if (cloudProfile != null) {
          _profile = cloudProfile;
          await prefs.setString('userProfile', jsonEncode(cloudProfile.toJson()));
        } else if (_profile != null) {
          // Never upload a locally generated UUID as the auth profile id.
          await saveProfile(_profile!, syncCloud: true);
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveProfile(UserProfile profile, {bool syncCloud = true}) async {
    final supabase = SupabaseService.instance;
    final userId = supabase.isAuthenticated ? supabase.userId : null;
    final persisted = userId == null || userId.isEmpty || profile.id == userId
        ? profile
        : UserProfile(
            id: userId,
            name: profile.name,
            avatarEmoji: profile.avatarEmoji,
            preferredLanguage: profile.preferredLanguage,
            tutorName: profile.tutorName,
            createdAt: profile.createdAt,
          );

    _profile = persisted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userProfile', jsonEncode(persisted.toJson()));

    if (syncCloud && supabase.isAuthenticated) {
      await DatabaseService.instance.upsertProfile(persisted);
    }
    notifyListeners();
  }

  Future<void> createProfile({
    required String name,
    String avatarEmoji = '👤',
    String preferredLanguage = 'English',
    String tutorName = 'Sam',
  }) async {
    await saveProfile(UserProfile(
      name: name,
      avatarEmoji: avatarEmoji,
      preferredLanguage: preferredLanguage,
      tutorName: tutorName,
    ));
  }
}
