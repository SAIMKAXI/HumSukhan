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

  UserProvider() { _loadProfile(); }

  Future<void> _loadProfile() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('userProfile');
      if (json != null) _profile = UserProfile.fromJson(jsonDecode(json));
      await reloadFromCloud();
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reloadFromCloud() async {
    final supabase = SupabaseService.instance;
    if (!supabase.isAuthenticated || supabase.userId.isEmpty) return;
    try {
      final cloudProfile = await DatabaseService.instance.fetchProfile(supabase.userId);
      final prefs = await SharedPreferences.getInstance();
      if (cloudProfile != null) {
        _profile = cloudProfile;
        await prefs.setString('userProfile', jsonEncode(cloudProfile.toJson()));
        return;
      }
      final metadataName = supabase.currentUser?.userMetadata?['name']?.toString().trim();
      await saveProfile(UserProfile(
        id: supabase.userId,
        name: metadataName?.isNotEmpty == true ? metadataName! : (_profile?.name ?? 'User'),
        avatarEmoji: _profile?.avatarEmoji ?? '👤',
        avatarData: _profile?.avatarData,
        preferredLanguage: _profile?.preferredLanguage ?? 'English',
        tutorName: _profile?.tutorName ?? 'Sam',
        createdAt: _profile?.createdAt ?? DateTime.now(),
      ));
    } catch (e) {
      debugPrint('Profile cloud sync error: $e');
    }
  }

  Future<void> saveProfile(UserProfile profile, {bool syncCloud = true}) async {
    final supabase = SupabaseService.instance;
    final userId = supabase.isAuthenticated ? supabase.userId : null;
    final persisted = userId == null || userId.isEmpty || profile.id == userId
        ? profile
        : UserProfile(id: userId, name: profile.name, avatarEmoji: profile.avatarEmoji, avatarData: profile.avatarData, preferredLanguage: profile.preferredLanguage, tutorName: profile.tutorName, createdAt: profile.createdAt);
    _profile = persisted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userProfile', jsonEncode(persisted.toJson()));
    if (syncCloud && supabase.isAuthenticated && supabase.client != null) {
      try {
        await supabase.client!.from('profiles').upsert({
          'id': supabase.userId,
          'name': persisted.name,
          'avatar_emoji': persisted.avatarEmoji,
          'avatar_data': persisted.avatarData,
          'preferred_language': persisted.preferredLanguage,
          'tutor_name': persisted.tutorName,
          'created_at': persisted.createdAt.toIso8601String(),
        });
      } catch (e) {
        debugPrint('Profile photo/cloud sync error: $e');
      }
    }
    notifyListeners();
  }

  Future<void> createProfile({required String name, String avatarEmoji = '👤', String? avatarData, String preferredLanguage = 'English', String tutorName = 'Sam'}) async {
    await saveProfile(UserProfile(name: name, avatarEmoji: avatarEmoji, avatarData: avatarData, preferredLanguage: preferredLanguage, tutorName: tutorName));
  }
}
