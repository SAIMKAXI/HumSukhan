import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../l10n/app_strings.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _pageCount = 5;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.scaffoldBackgroundColor,
              colors.surfaceContainerHighest,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(strings.skip),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    if (mounted) {
                      setState(() => _currentPage = index);
                    }
                  },
                  children: [
                    _buildPage(
                      context,
                      imagePath: 'assets/logo.png',
                      title: strings.onboardingWelcome,
                      subtitle: strings.onboardingWelcomeDesc,
                    ),
                    _buildPage(
                      context,
                      icon: Icons.chat_bubble_outline,
                      title: strings.onboardingEveryday,
                      subtitle: strings.onboardingEverydayDesc,
                    ),
                    _buildPage(
                      context,
                      icon: Icons.work_outline,
                      title: strings.onboardingProfessional,
                      subtitle: strings.onboardingProfessionalDesc,
                    ),
                    _buildPage(
                      context,
                      icon: Icons.volume_up,
                      title: strings.onboardingEnvironmental,
                      subtitle: strings.onboardingEnvironmentalDesc,
                    ),
                    _buildPage(
                      context,
                      icon: Icons.shield_outlined,
                      title: strings.onboardingPrivacy,
                      subtitle: strings.onboardingPrivacyDesc,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pageCount,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? colors.primary
                            : colors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _currentPage == _pageCount - 1
                        ? _completeOnboarding
                        : () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            ),
                    child: Text(
                      _currentPage == _pageCount - 1
                          ? strings.getStarted
                          : strings.next,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(
    BuildContext context, {
    required String title,
    required String subtitle,
    String? imagePath,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final showLogo = imagePath != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showLogo)
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(imagePath, fit: BoxFit.cover),
            )
          else if (icon != null)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: colors.primary),
            ),
          const SizedBox(height: 40),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    await context.read<SettingsProvider>().completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/auth');
  }
}
