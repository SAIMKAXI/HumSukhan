import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

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
      if (json != null) {
        _profile = UserProfile.fromJson(jsonDecode(json));
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
