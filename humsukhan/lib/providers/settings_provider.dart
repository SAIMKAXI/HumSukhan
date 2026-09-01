import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false, _isHighContrast = false, _isLargeText = false;
  double _captionTextSize = 24.0;
  bool _hapticAlerts = true, _visualAlerts = true, _flashAlerts = false, _screenFlashAlerts = true;
  bool _simplifiedLanguage = false;
  String _captionLanguage = 'English', _appLanguage = 'en';
  int _defaultRetentionDays = 7;
  bool _legacyOnboardingComplete = false, _monitoringEnabled = false;
  bool _isLoaded = false;
  final Set<String> _onboardedUsers = <String>{};
  final Map<String, bool> _allowedAlerts = {
    'Fire Alarm': true, 'Smoke Alarm': true, 'Siren': true, 'Doorbell': true,
    'Knock': true, 'Phone': true, 'Alarm Clock': true, 'Baby Cry': true,
    'Vehicle Horn': true, 'Glass Break': true, 'Dog Bark': true,
  };

  bool get isDarkMode => _isDarkMode;
  bool get isHighContrast => _isHighContrast;
  bool get isLargeText => _isLargeText;
  bool get isLoaded => _isLoaded;
  double get captionTextSize => _captionTextSize;
  bool get hapticAlerts => _hapticAlerts;
  bool get visualAlerts => _visualAlerts;
  bool get flashAlerts => _flashAlerts;
  bool get screenFlashAlerts => _screenFlashAlerts;
  bool get simplifiedLanguage => _simplifiedLanguage;
  String get captionLanguage => _captionLanguage;
  String get appLanguage => _appLanguage;
  int get defaultRetentionDays => _defaultRetentionDays;
  bool get isOnboardingComplete {
    final userId = AuthService.instance.currentUser?.id;
    return userId != null && _onboardedUsers.contains(userId);
  }
  bool get monitoringEnabled => _monitoringEnabled;
  Map<String, bool> get allowedAlerts => Map.unmodifiable(_allowedAlerts);
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  SettingsProvider() { _loadSettings(); }

  Map<String, dynamic> _settingsPayload() => {
        'darkMode': _isDarkMode,
        'highContrast': _isHighContrast,
        'largeText': _isLargeText,
        'captionTextSize': _captionTextSize,
        'hapticAlerts': _hapticAlerts,
        'visualAlerts': _visualAlerts,
        'flashAlerts': _flashAlerts,
        'screenFlashAlerts': _screenFlashAlerts,
        'simplifiedLanguage': _simplifiedLanguage,
        'captionLanguage': _captionLanguage,
        'appLanguage': _appLanguage,
        'defaultRetentionDays': _defaultRetentionDays,
        'monitoringEnabled': _monitoringEnabled,
        'allowedAlerts': _allowedAlerts,
      };

  void _applySettings(Map<String, dynamic> data) {
    _isDarkMode = data['darkMode'] is bool ? data['darkMode'] as bool : _isDarkMode;
    _isHighContrast = data['highContrast'] is bool ? data['highContrast'] as bool : _isHighContrast;
    _isLargeText = data['largeText'] is bool ? data['largeText'] as bool : _isLargeText;
    final captionSize = data['captionTextSize'];
    if (captionSize is num) _captionTextSize = captionSize.toDouble().clamp(16.0, 48.0);
    _hapticAlerts = data['hapticAlerts'] is bool ? data['hapticAlerts'] as bool : _hapticAlerts;
    _visualAlerts = data['visualAlerts'] is bool ? data['visualAlerts'] as bool : _visualAlerts;
    _flashAlerts = data['flashAlerts'] is bool ? data['flashAlerts'] as bool : _flashAlerts;
    _screenFlashAlerts = data['screenFlashAlerts'] is bool ? data['screenFlashAlerts'] as bool : _screenFlashAlerts;
    _simplifiedLanguage = data['simplifiedLanguage'] is bool ? data['simplifiedLanguage'] as bool : _simplifiedLanguage;
    if (data['captionLanguage'] is String && const ['English', 'Roman Urdu', 'Urdu'].contains(data['captionLanguage'])) _captionLanguage = data['captionLanguage'] as String;
    if (data['appLanguage'] is String && const ['en', 'ur'].contains(data['appLanguage'])) _appLanguage = data['appLanguage'] as String;
    final retention = data['defaultRetentionDays'];
    if (retention is int) _defaultRetentionDays = retention.clamp(1, 15);
    _monitoringEnabled = data['monitoringEnabled'] is bool ? data['monitoringEnabled'] as bool : _monitoringEnabled;
    final alerts = data['allowedAlerts'];
    if (alerts is Map) {
      for (final entry in alerts.entries) {
        if (entry.key is String && entry.value is bool && _allowedAlerts.containsKey(entry.key)) {
          _allowedAlerts[entry.key as String] = entry.value as bool;
        }
      }
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('darkMode') ?? false;
    _isHighContrast = prefs.getBool('highContrast') ?? false;
    _isLargeText = prefs.getBool('largeText') ?? false;
    _captionTextSize = prefs.getDouble('captionTextSize') ?? 24.0;
    _hapticAlerts = prefs.getBool('hapticAlerts') ?? true;
    _visualAlerts = prefs.getBool('visualAlerts') ?? true;
    _flashAlerts = prefs.getBool('flashAlerts') ?? false;
    _screenFlashAlerts = prefs.getBool('screenFlashAlerts') ?? true;
    _simplifiedLanguage = prefs.getBool('simplifiedLanguage') ?? false;
    _captionLanguage = prefs.getString('captionLanguage') ?? 'English';
    _appLanguage = prefs.getString('appLanguage') ?? 'en';
    _defaultRetentionDays = prefs.getInt('defaultRetentionDays') ?? 7;
    _legacyOnboardingComplete = prefs.getBool('onboardingComplete') ?? false;
    _monitoringEnabled = prefs.getBool('monitoringEnabled') ?? false;

    final currentUserId = AuthService.instance.currentUser?.id;
    if (_legacyOnboardingComplete && currentUserId != null) {
      _onboardedUsers.add(currentUserId);
      await prefs.setBool('onboardingComplete:$currentUserId', true);
    }
    for (final key in prefs.getKeys()) {
      if (key.startsWith('onboardingComplete:') && prefs.getBool(key) == true) {
        _onboardedUsers.add(key.substring('onboardingComplete:'.length));
      }
    }

    final storedAlerts = prefs.getString('allowedAlerts');
    if (storedAlerts != null) {
      try {
        _applySettings({'allowedAlerts': jsonDecode(storedAlerts)});
      } catch (_) {}
    }

    if (SupabaseService.instance.isAuthenticated) {
      try {
        final cloudSettings = await DatabaseService.instance.fetchSettings(SupabaseService.instance.userId);
        if (cloudSettings != null && cloudSettings.isNotEmpty) {
          _applySettings(cloudSettings);
          await _persistAllLocal(prefs);
        } else {
          await _saveToCloud();
        }
      } catch (e) {
        debugPrint('Settings cloud load error: $e');
      }
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _persistAllLocal([SharedPreferences? existing]) async {
    final prefs = existing ?? await SharedPreferences.getInstance();
    final data = _settingsPayload();
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is bool) await prefs.setBool(entry.key, value);
      if (value is double) await prefs.setDouble(entry.key, value);
      if (value is int) await prefs.setInt(entry.key, value);
      if (value is String) await prefs.setString(entry.key, value);
      if (entry.key == 'allowedAlerts') await prefs.setString(entry.key, jsonEncode(value));
    }
  }

  Future<void> _save(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    else if (value is double) await prefs.setDouble(key, value);
    else if (value is int) await prefs.setInt(key, value);
    else if (value is String) await prefs.setString(key, value);
  }

  Future<void> _saveToCloud() async {
    if (!SupabaseService.instance.isAuthenticated) return;
    await DatabaseService.instance.upsertSettings(_settingsPayload());
  }

  Future<void> _persistChange(String key, dynamic value) async {
    await _save(key, value);
    if (key == 'allowedAlerts') await _saveToCloud();
    else await _saveToCloud();
  }

  void toggleDarkMode() { _isDarkMode = !_isDarkMode; notifyListeners(); _persistChange('darkMode', _isDarkMode); }
  void toggleHighContrast() { _isHighContrast = !_isHighContrast; notifyListeners(); _persistChange('highContrast', _isHighContrast); }
  void toggleLargeText() { _isLargeText = !_isLargeText; notifyListeners(); _persistChange('largeText', _isLargeText); }
  void setCaptionTextSize(double size) { _captionTextSize = size.clamp(16.0, 48.0); notifyListeners(); _persistChange('captionTextSize', _captionTextSize); }
  void toggleHapticAlerts() { _hapticAlerts = !_hapticAlerts; notifyListeners(); _persistChange('hapticAlerts', _hapticAlerts); }
  void toggleVisualAlerts() { _visualAlerts = !_visualAlerts; notifyListeners(); _persistChange('visualAlerts', _visualAlerts); }
  void toggleFlashAlerts() { _flashAlerts = !_flashAlerts; notifyListeners(); _persistChange('flashAlerts', _flashAlerts); }
  void toggleScreenFlashAlerts() { _screenFlashAlerts = !_screenFlashAlerts; notifyListeners(); _persistChange('screenFlashAlerts', _screenFlashAlerts); }
  void toggleSimplifiedLanguage() { _simplifiedLanguage = !_simplifiedLanguage; notifyListeners(); _persistChange('simplifiedLanguage', _simplifiedLanguage); }
  void setCaptionLanguage(String lang) { _captionLanguage = lang; notifyListeners(); _persistChange('captionLanguage', lang); }
  void setAppLanguage(String langCode) { _appLanguage = langCode; notifyListeners(); _persistChange('appLanguage', langCode); }
  void setDefaultRetentionDays(int days) { _defaultRetentionDays = days.clamp(1, 15); notifyListeners(); _persistChange('defaultRetentionDays', _defaultRetentionDays); }
  void toggleMonitoring() { _monitoringEnabled = !_monitoringEnabled; notifyListeners(); _persistChange('monitoringEnabled', _monitoringEnabled); }
  void toggleAllowedAlert(String alertType) { _allowedAlerts[alertType] = !(_allowedAlerts[alertType] ?? true); notifyListeners(); _persistChange('allowedAlerts', jsonEncode(_allowedAlerts)); }

  Future<bool> hasCompletedOnboardingForUser(String userId) async {
    if (userId.isEmpty) return false;
    if (_onboardedUsers.contains(userId)) return true;
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('onboardingComplete:$userId') ?? false;
    if (done) _onboardedUsers.add(userId);
    return done;
  }

  Future<void> completeOnboardingForUser(String userId) async {
    if (userId.isEmpty) return;
    _onboardedUsers.add(userId);
    await _save('onboardingComplete:$userId', true);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    final userId = AuthService.instance.currentUser?.id;
    if (userId != null) await completeOnboardingForUser(userId);
  }

  Future<void> clearLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    const keys = [
      'darkMode', 'highContrast', 'largeText', 'captionTextSize', 'hapticAlerts',
      'visualAlerts', 'flashAlerts', 'screenFlashAlerts', 'simplifiedLanguage',
      'captionLanguage', 'appLanguage', 'defaultRetentionDays', 'monitoringEnabled',
      'allowedAlerts', 'onboardingComplete',
    ];
    for (final key in keys) await prefs.remove(key);
    final userKeys = prefs.getKeys().where((key) => key.startsWith('onboardingComplete:')).toList();
    for (final key in userKeys) await prefs.remove(key);
    _isDarkMode = false;
    _isHighContrast = false;
    _isLargeText = false;
    _captionTextSize = 24.0;
    _hapticAlerts = true;
    _visualAlerts = true;
    _flashAlerts = false;
    _screenFlashAlerts = true;
    _simplifiedLanguage = false;
    _captionLanguage = 'English';
    _appLanguage = 'en';
    _defaultRetentionDays = 7;
    _monitoringEnabled = false;
    _onboardedUsers.clear();
    for (final key in _allowedAlerts.keys) _allowedAlerts[key] = true;
    notifyListeners();
  }
}
