import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../widgets/reusable_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final _pages = const [
    _OnboardingPage(
      icon: Icons.accessibility_new,
      title: 'Welcome to HumSukhan',
      subtitle: 'A calm, inclusive companion for conversations, captions, and professional listening.',
    ),
    _OnboardingPage(
      icon: Icons.chat_bubble_outline,
      title: 'Everyday Conversations',
      subtitle: 'Get live captions during conversations. Respond with text, quick replies, or text-to-speech.',
    ),
    _OnboardingPage(
      icon: Icons.work_outline,
      title: 'Professional Listening',
      subtitle: 'Capture lectures and meetings. Get AI-powered summaries, action items, and insights.',
    ),
    _OnboardingPage(
      icon: Icons.volume_up,
      title: 'Environmental Awareness',
      subtitle: 'Know about important sounds around you — fire alarms, doorbells, phone calls, and more.',
    ),
    _OnboardingPage(
      icon: Icons.shield,
      title: 'Privacy First',
      subtitle: 'Audio is processed temporarily and released. No raw audio is ever stored. You control your data.',
    ),
    _OnboardingPage(
      icon: Icons.settings,
      title: 'Accessibility Settings',
      subtitle: 'Customize captions, contrast, text size, haptic alerts, and more to suit your needs.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: const Text('Skip'),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (context, idx) => _pages[idx],
              ),
            ),

            // Dots indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (idx) =>
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == idx ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == idx
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: _currentPage == _pages.length - 1
                  ? PrimaryActionButton(
                      label: 'Get Started',
                      icon: Icons.arrow_forward,
                      onPressed: _completeOnboarding,
                    )
                  : Row(
                      children: [
                        if (_currentPage > 0)
                          Expanded(
                            child: SecondaryActionButton(
                              label: 'Back',
                              icon: Icons.arrow_back,
                              onPressed: () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                            ),
                          ),
                        if (_currentPage > 0) const SizedBox(width: 16),
                        Expanded(
                          child: PrimaryActionButton(
                            label: 'Next',
                            icon: Icons.arrow_forward,
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _completeOnboarding() {
    context.read<SettingsProvider>().completeOnboarding();
    Navigator.of(context).pushReplacementNamed('/home');
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
