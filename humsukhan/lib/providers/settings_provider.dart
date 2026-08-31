import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false, _isHighContrast = false, _isLargeText = false;
  double _captionTextSize = 24.0;
  bool _hapticAlerts = true, _visualAlerts = true, _flashAlerts = false, _screenFlashAlerts = true;
  bool _simplifiedLanguage = false;
  String _captionLanguage = 'English', _appLanguage = 'en';
  int _defaultRetentionDays = 7;
  bool _isOnboardingComplete = false, _monitoringEnabled = false;
  bool _isLoaded = false;
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
  bool get isOnboardingComplete => _isOnboardingComplete;
  bool get monitoringEnabled => _monitoringEnabled;
  Map<String, bool> get allowedAlerts => Map.unmodifiable(_allowedAlerts);
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  SettingsProvider() { _loadSettings(); }

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
    _isOnboardingComplete = prefs.getBool('onboardingComplete') ?? false;
    _monitoringEnabled = prefs.getBool('monitoringEnabled') ?? false;
    final storedAlerts = prefs.getString('allowedAlerts');
    if (storedAlerts != null) {
      try {
        final decoded = Map<String, dynamic>.from(jsonDecode(storedAlerts));
        for (final entry in decoded.entries) _allowedAlerts[entry.key] = entry.value == true;
      } catch (_) {}
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _save(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    else if (value is double) await prefs.setDouble(key, value);
    else if (value is int) await prefs.setInt(key, value);
    else if (value is String) await prefs.setString(key, value);
  }

  void toggleDarkMode() { _isDarkMode = !_isDarkMode; notifyListeners(); _save('darkMode', _isDarkMode); }
  void toggleHighContrast() { _isHighContrast = !_isHighContrast; notifyListeners(); _save('highContrast', _isHighContrast); }
  void toggleLargeText() { _isLargeText = !_isLargeText; notifyListeners(); _save('largeText', _isLargeText); }
  void setCaptionTextSize(double size) { _captionTextSize = size.clamp(16.0, 48.0); notifyListeners(); _save('captionTextSize', _captionTextSize); }
  void toggleHapticAlerts() { _hapticAlerts = !_hapticAlerts; notifyListeners(); _save('hapticAlerts', _hapticAlerts); }
  void toggleVisualAlerts() { _visualAlerts = !_visualAlerts; notifyListeners(); _save('visualAlerts', _visualAlerts); }
  void toggleFlashAlerts() { _flashAlerts = !_flashAlerts; notifyListeners(); _save('flashAlerts', _flashAlerts); }
  void toggleScreenFlashAlerts() { _screenFlashAlerts = !_screenFlashAlerts; notifyListeners(); _save('screenFlashAlerts', _screenFlashAlerts); }
  void toggleSimplifiedLanguage() { _simplifiedLanguage = !_simplifiedLanguage; notifyListeners(); _save('simplifiedLanguage', _simplifiedLanguage); }
  void setCaptionLanguage(String lang) { _captionLanguage = lang; notifyListeners(); _save('captionLanguage', lang); }
  void setAppLanguage(String langCode) { _appLanguage = langCode; notifyListeners(); _save('appLanguage', langCode); }
  void setDefaultRetentionDays(int days) { _defaultRetentionDays = days.clamp(1, 15); notifyListeners(); _save('defaultRetentionDays', _defaultRetentionDays); }
  void toggleMonitoring() { _monitoringEnabled = !_monitoringEnabled; notifyListeners(); _save('monitoringEnabled', _monitoringEnabled); }
  void toggleAllowedAlert(String alertType) { _allowedAlerts[alertType] = !(_allowedAlerts[alertType] ?? true); notifyListeners(); _save('allowedAlerts', jsonEncode(_allowedAlerts)); }

  Future<bool> hasCompletedOnboardingForUser(String userId) async {
    if (userId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboardingComplete:$userId') ?? _isOnboardingComplete;
  }

  Future<void> completeOnboardingForUser(String userId) async {
    if (userId.isEmpty) return;
    _isOnboardingComplete = true;
    await _save('onboardingComplete', true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete:$userId', true);
    notifyListeners();
  }

  Future<void> completeOnboarding() async => completeOnboardingForUser('legacy');
}
