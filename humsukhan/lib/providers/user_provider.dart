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
      // Load from local first
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('userProfile');
      if (json != null) {
        _profile = UserProfile.fromJson(jsonDecode(json));
      }

      // Sync from Supabase if authenticated
      if (SupabaseService.instance.isAuthenticated) {
        final userId = SupabaseService.instance.userId;
        final cloudProfile = await DatabaseService.instance.fetchProfile(userId);
        if (cloudProfile != null) {
          _profile = cloudProfile;
          // Update local cache
          await prefs.setString('userProfile', jsonEncode(cloudProfile.toJson()));
        } else if (_profile != null) {
          // Push local profile to cloud
          await DatabaseService.instance.upsertProfile(_profile!);
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userProfile', jsonEncode(profile.toJson()));

    // Sync to Supabase if authenticated
    if (SupabaseService.instance.isAuthenticated) {
      await DatabaseService.instance.upsertProfile(profile);
    }

    notifyListeners();
  }

  Future<void> createProfile({
    required String name,
    String avatarEmoji = '👤',
    String preferredLanguage = 'English',
    String tutorName = 'Sam',
  }) async {
    final profile = UserProfile(
      name: name,
      avatarEmoji: avatarEmoji,
      preferredLanguage: preferredLanguage,
      tutorName: tutorName,
    );
    await saveProfile(profile);
  }
}
