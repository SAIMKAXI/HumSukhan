import 'dart:async';

import 'package:flutter/material.dart';
import '../navigation/app_router.dart';
import '../screens/screens.dart';
import '../l10n/app_strings.dart';
import '../services/alert_service.dart';
import '../services/notification_service.dart';
import 'modern_ui.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  StreamSubscription<String>? _notificationTaps;

  final _screens = const [
    HomeScreen(),
    EverydayScreen(),
    ProfessionalScreen(),
    EnvironmentalScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AlertService.instance.registerContext(context);
      unawaited(_openLaunchNotification());
    });
    _notificationTaps = NotificationService.instance.taps.listen(_onNotificationTap);
  }

  /// HumSukhan was started by tapping a notification.
  Future<void> _openLaunchNotification() async {
    final payload = await NotificationService.instance.takeLaunchPayload();
    if (payload != null) _onNotificationTap(payload);
  }

  void _onNotificationTap(String payload) {
    if (!mounted || payload != NotificationService.checkInPayload) return;
    Navigator.of(context).pushNamed(AppRouter.wellbeing, arguments: true);
  }

  @override
  void dispose() {
    unawaited(_notificationTaps?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final destinations = [
      (s.navHome, Icons.home_outlined, Icons.home_rounded),
      (s.navEveryday, Icons.forum_outlined, Icons.forum_rounded),
      (s.navProfessional, Icons.work_outline_rounded, Icons.work_rounded),
      (s.navAlerts, Icons.notifications_none_rounded, Icons.notifications_rounded),
      (s.navSettings, Icons.tune_rounded, Icons.tune_rounded),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          for (final item in destinations)
            NavigationDestination(
              icon: Icon(item.$2),
              selectedIcon: Icon(item.$3),
              label: item.$1,
            ),
        ],
      ),
      drawer: null,
      floatingActionButton: null,
    );
  }
}

// Kept as a small public visual helper for pages that need a compact brand mark.
class ShellBrandMark extends StatelessWidget {
  const ShellBrandMark({super.key});

  @override
  Widget build(BuildContext context) => const BrandLogo(size: 44, radius: AppTokens.radiusMd);
}
