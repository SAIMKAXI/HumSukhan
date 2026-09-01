import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../l10n/app_strings.dart';
import '../widgets/reusable_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _pageCount = 5;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

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
    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.scaffoldBackgroundColor, colors.surfaceContainerHighest],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _currentPage > 0
                          ? Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton.icon(
                                onPressed: _isCompleting ? null : _goPrevious,
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: Text(isUrdu ? 'واپس' : 'Back'),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    TextButton(
                      onPressed: _isCompleting ? null : () { _completeOnboarding(); },
                      child: Text(strings.skip),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    if (mounted) setState(() => _currentPage = index);
                  },
                  children: [
                    _buildPage(context, imagePath: 'assets/logo.png', title: strings.onboardingWelcome, subtitle: strings.onboardingWelcomeDesc),
                    _buildPage(context, icon: Icons.chat_bubble_outline, title: strings.onboardingEveryday, subtitle: strings.onboardingEverydayDesc),
                    _buildPage(context, icon: Icons.work_outline, title: strings.onboardingProfessional, subtitle: strings.onboardingProfessionalDesc),
                    _buildPage(context, icon: Icons.volume_up, title: strings.onboardingEnvironmental, subtitle: strings.onboardingEnvironmentalDesc),
                    _buildPage(context, icon: Icons.shield_outlined, title: strings.onboardingPrivacy, subtitle: strings.onboardingPrivacyDesc),
                  ],
                ),
              ),
              Semantics(
                liveRegion: true,
                label: '${isUrdu ? 'مرحلہ' : 'Step'} ${_currentPage + 1} ${isUrdu ? 'از' : 'of'} $_pageCount',
                child: Padding(
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
                          color: _currentPage == index ? colors.primary : colors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: _isCompleting
                    ? PrimaryActionButton(
                        label: isUrdu ? 'براہ کرم انتظار کریں…' : 'Please wait…',
                        icon: Icons.hourglass_top_rounded,
                        onPressed: () {},
                      )
                    : PrimaryActionButton(
                        label: _currentPage == _pageCount - 1 ? strings.getStarted : strings.next,
                        icon: _currentPage == _pageCount - 1 ? Icons.check_rounded : Icons.arrow_forward_rounded,
                        onPressed: _currentPage == _pageCount - 1 ? _completeOnboardingSync : _goNext,
                      ),
              ),
              const SizedBox(height: 8),
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
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (imagePath != null)
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(color: colors.primary.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(imagePath, fit: BoxFit.cover),
          )
        else if (icon != null)
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(color: colors.primaryContainer, shape: BoxShape.circle),
            child: Icon(icon, size: 56, color: colors.primary),
          ),
        const SizedBox(height: 32),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant, height: 1.6),
          textAlign: TextAlign.center,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }

  void _goNext() {
    if (_currentPage >= _pageCount - 1 || _isCompleting) return;
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _goPrevious() {
    if (_currentPage <= 0 || _isCompleting) return;
    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _completeOnboardingSync() {
    if (_isCompleting) return;
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    final userId = context.read<AuthProvider>().userId;
    if (userId.isEmpty) return;

    setState(() => _isCompleting = true);
    try {
      await context.read<SettingsProvider>().completeOnboardingForUser(userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to finish onboarding. Please try again.')),
        );
        setState(() => _isCompleting = false);
      }
    }
  }
}
