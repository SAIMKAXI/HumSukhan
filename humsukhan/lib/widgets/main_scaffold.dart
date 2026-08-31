import 'package:flutter/material.dart';
import '../screens/screens.dart';
import '../l10n/app_strings.dart';
import '../services/alert_service.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    EverydayScreen(),
    ProfessionalScreen(),
    EnvironmentalScreen(),
    SettingsScreen(),
    PslScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AlertService.instance.registerContext(context);
    });
  }

  void _selectDestination(int index) {
    Navigator.of(context).pop();
    if (mounted) setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';
    final destinations = [
      (s.navHome, Icons.home_outlined, Icons.home),
      (s.navEveryday, Icons.chat_bubble_outline, Icons.chat_bubble),
      (s.navProfessional, Icons.work_outline, Icons.work),
      (s.navAlerts, Icons.volume_up_outlined, Icons.volume_up),
      (s.navSettings, Icons.settings_outlined, Icons.settings),
      (isUrdu ? 'PSL شناخت' : 'PSL Recognition', Icons.pan_tool_outlined, Icons.pan_tool),
    ];

    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Align(
                  alignment: isUrdu ? Alignment.centerRight : Alignment.centerLeft,
                  child: Text(
                    s.appName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: destinations.length,
                  itemBuilder: (context, index) {
                    final item = destinations[index];
                    return ListTile(
                      leading: Icon(index == _currentIndex ? item.$3 : item.$2),
                      title: Text(item.$1),
                      selected: index == _currentIndex,
                      onTap: () => _selectDestination(index),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context) + 4,
            left: 4,
            child: Builder(
              builder: (context) => Material(
                color: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  tooltip: isUrdu ? 'مینو کھولیں' : 'Open menu',
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}