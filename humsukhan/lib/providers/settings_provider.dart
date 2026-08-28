import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool _isHighContrast = false;
  bool _isLargeText = false;
  double _captionTextSize = 24.0;
  bool _hapticAlerts = true;
  bool _visualAlerts = true;
  bool _flashAlerts = false;
  bool _screenFlashAlerts = true;
  bool _simplifiedLanguage = false;
  String _captionLanguage = 'English';
  int _defaultRetentionDays = 7;
  bool _isOnboardingComplete = false;

  // Environmental alert settings
  bool _monitoringEnabled = false;
  Map<String, bool> _allowedAlerts = {
    'Fire Alarm': true,
    'Smoke Alarm': true,
    'Siren': true,
    'Doorbell': true,
    'Knock': true,
    'Phone': true,
    'Alarm Clock': true,
    'Baby Cry': true,
  };

  // Getters
  bool get isDarkMode => _isDarkMode;
  bool get isHighContrast => _isHighContrast;
  bool get isLargeText => _isLargeText;
  double get captionTextSize => _captionTextSize;
  bool get hapticAlerts => _hapticAlerts;
  bool get visualAlerts => _visualAlerts;
  bool get flashAlerts => _flashAlerts;
  bool get screenFlashAlerts => _screenFlashAlerts;
  bool get simplifiedLanguage => _simplifiedLanguage;
  String get captionLanguage => _captionLanguage;
  int get defaultRetentionDays => _defaultRetentionDays;
  bool get isOnboardingComplete => _isOnboardingComplete;
  bool get monitoringEnabled => _monitoringEnabled;
  Map<String, bool> get allowedAlerts => Map.unmodifiable(_allowedAlerts);

  ThemeMode get themeMode {
    if (_isHighContrast) return ThemeMode.dark;
    return _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  SettingsProvider() {
    _loadSettings();
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
    _defaultRetentionDays = prefs.getInt('defaultRetentionDays') ?? 7;
    _isOnboardingComplete = prefs.getBool('onboardingComplete') ?? false;
    _monitoringEnabled = prefs.getBool('monitoringEnabled') ?? false;
    notifyListeners();
  }

  Future<void> _save(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    else if (value is double) await prefs.setDouble(key, value);
    else if (value is int) await prefs.setInt(key, value);
    else if (value is String) await prefs.setString(key, value);
  }

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    _save('darkMode', _isDarkMode);
    notifyListeners();
  }

  void toggleHighContrast() {
    _isHighContrast = !_isHighContrast;
    _save('highContrast', _isHighContrast);
    notifyListeners();
  }

  void toggleLargeText() {
    _isLargeText = !_isLargeText;
    _save('largeText', _isLargeText);
    notifyListeners();
  }

  void setCaptionTextSize(double size) {
    _captionTextSize = size.clamp(16.0, 48.0);
    _save('captionTextSize', _captionTextSize);
    notifyListeners();
  }

  void toggleHapticAlerts() {
    _hapticAlerts = !_hapticAlerts;
    _save('hapticAlerts', _hapticAlerts);
    notifyListeners();
  }

  void toggleVisualAlerts() {
    _visualAlerts = !_visualAlerts;
    _save('visualAlerts', _visualAlerts);
    notifyListeners();
  }

  void toggleFlashAlerts() {
    _flashAlerts = !_flashAlerts;
    _save('flashAlerts', _flashAlerts);
    notifyListeners();
  }

  void toggleScreenFlashAlerts() {
    _screenFlashAlerts = !_screenFlashAlerts;
    _save('screenFlashAlerts', _screenFlashAlerts);
    notifyListeners();
  }

  void toggleSimplifiedLanguage() {
    _simplifiedLanguage = !_simplifiedLanguage;
    _save('simplifiedLanguage', _simplifiedLanguage);
    notifyListeners();
  }

  void setCaptionLanguage(String lang) {
    _captionLanguage = lang;
    _save('captionLanguage', lang);
    notifyListeners();
  }

  void setDefaultRetentionDays(int days) {
    _defaultRetentionDays = days;
    _save('defaultRetentionDays', days);
    notifyListeners();
  }

  void toggleMonitoring() {
    _monitoringEnabled = !_monitoringEnabled;
    _save('monitoringEnabled', _monitoringEnabled);
    notifyListeners();
  }

  void toggleAllowedAlert(String alertType) {
    _allowedAlerts[alertType] = !(_allowedAlerts[alertType] ?? true);
    notifyListeners();
  }

  void completeOnboarding() {
    _isOnboardingComplete = true;
    _save('onboardingComplete', true);
    notifyListeners();
  }
}
