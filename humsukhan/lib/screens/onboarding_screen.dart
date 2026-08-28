import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/reusable_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTokens.warmIvory, AppTokens.softCream],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: const Text('Skip', style: TextStyle(color: AppTokens.textSecondary)),
                ),
              ),

              // Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  children: [
                    _buildPage(
                      'assets/logo.png',
                      'Welcome to HumSukhan',
                      'A calm, inclusive companion for conversations, captions, and professional listening.',
                      isLogo: true,
                    ),
                    _buildPage(
                      null,
                      'Everyday Conversations',
                      'Get live captions during conversations. Respond with text, quick replies, or text-to-speech.',
                      icon: Icons.chat_bubble_outline,
                    ),
                    _buildPage(
                      null,
                      'Professional Listening',
                      'Capture lectures and meetings. Get AI-powered summaries, action items, and insights.',
                      icon: Icons.work_outline,
                    ),
                    _buildPage(
                      null,
                      'Environmental Awareness',
                      'Know about important sounds around you — fire alarms, doorbells, phone calls, and more.',
                      icon: Icons.volume_up,
                    ),
                    _buildPage(
                      null,
                      'Privacy First',
                      'Audio is processed temporarily and released. No raw audio is ever stored.',
                      icon: Icons.shield,
                    ),
                  ],
                ),
              ),

              // Dots
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (idx) =>
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == idx ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == idx
                            ? AppTokens.deepSage
                            : AppTokens.deepSage.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),

              // Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: _currentPage == 4
                    ? ElevatedButton(
                        onPressed: _completeOnboarding,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          backgroundColor: AppTokens.deepSage,
                          foregroundColor: AppTokens.warmIvory,
                        ),
                        child: const Text('Get Started', style: TextStyle(fontWeight: FontWeight.w600)),
                      )
                    : ElevatedButton(
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          backgroundColor: AppTokens.deepSage,
                          foregroundColor: AppTokens.warmIvory,
                        ),
                        child: const Text('Next', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(String? imagePath, String title, String subtitle, {
    IconData? icon,
    bool isLogo = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLogo && imagePath != null)
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppTokens.deepSage.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(imagePath, fit: BoxFit.cover),
              ),
            )
          else if (icon != null)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTokens.deepSage.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: AppTokens.deepSage),
            ),
          const SizedBox(height: 40),
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppTokens.textDeepForest,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 15,
              color: AppTokens.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _completeOnboarding() {
    context.read<SettingsProvider>().completeOnboarding();
    Navigator.of(context).pushReplacementNamed('/home');
  }
}
