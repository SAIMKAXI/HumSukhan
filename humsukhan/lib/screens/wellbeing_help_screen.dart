import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../modules/wellbeing/data/support_library.dart';
import '../modules/wellbeing/services/mood_patterns.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

/// Opens the right help for [state]: the fixed help screen when it is
/// urgent, otherwise the pre-written ideas.
Future<void> openWellbeingHelp(BuildContext context, MoodState state) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => state == MoodState.urgent ? const HelpNowScreen() : SupportScreen(state: state),
  ));
}

/// Text in the app language, or in both languages when the user asked for
/// that. Urdu is set right to left in Nastaliq, English left to right.
class BilingualBlock extends StatelessWidget {
  const BilingualBlock(this.text, {super.key, this.style, this.both = false});

  final BilingualText text;
  final TextStyle? style;
  final bool both;

  @override
  Widget build(BuildContext context) {
    final urduFirst = AppStrings.of(context).isUrdu;
    Widget line(bool urdu, {bool secondary = false}) {
      final base = style ?? Theme.of(context).textTheme.bodyLarge;
      final muted = secondary ? base?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant) : base;
      return Text(
        text.of(urdu),
        textDirection: urdu ? TextDirection.rtl : TextDirection.ltr,
        textAlign: urdu ? TextAlign.right : TextAlign.left,
        style: urdu ? muted?.copyWith(fontFamily: 'NotoNastaliqUrdu', height: 1.8) : muted?.copyWith(fontFamily: 'NotoSans'),
      );
    }

    if (!both) return SizedBox(width: double.infinity, child: line(urduFirst));
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [line(urduFirst), const SizedBox(height: 4), line(!urduFirst, secondary: true)],
      ),
    );
  }
}

/// The pre-written ideas for a mood state.
class SupportScreen extends StatelessWidget {
  const SupportScreen({required this.state, super.key});

  final MoodState state;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final wellbeing = context.watch<WellbeingProvider>();
    final theme = Theme.of(context);
    final items = SupportLibrary.forState(state);
    return Scaffold(
      appBar: AppBar(title: Text(s.ideasThatMayHelp)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(patternMessage(s, state), style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.showBothLanguages),
              value: wellbeing.showBothLanguages,
              onChanged: (value) => wellbeing.setShowBothLanguages(value),
            ),
            for (final item in items) ...[
              SupportItemCard(item: item, both: wellbeing.showBothLanguages),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            _UrgentHelpLink(),
          ],
        ),
      ),
    );
  }
}

String patternMessage(AppStrings s, MoodState state) => switch (state) {
      MoodState.noData => s.patternNoData,
      MoodState.doingWell => s.patternDoingWell,
      MoodState.steady => s.patternSteady,
      MoodState.lowDay => s.patternLowDay,
      MoodState.severalLowDays => s.patternSeveralLowDays,
      MoodState.urgent => s.patternUrgent,
    };

class _UrgentHelpLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: colors.error.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.feelUnsafe, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.support_rounded),
            label: Text(s.openUrgentHelp),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HelpNowScreen())),
          ),
        ],
      ),
    );
  }
}

/// One support item, with an optional read-aloud button for users who can
/// hear some speech.
class SupportItemCard extends StatefulWidget {
  const SupportItemCard({required this.item, required this.both, super.key});

  final SupportItem item;
  final bool both;

  @override
  State<SupportItemCard> createState() => _SupportItemCardState();
}

class _SupportItemCardState extends State<SupportItemCard> {
  bool _speaking = false;

  String _spokenText(bool urdu) {
    final item = widget.item;
    return [item.title.of(urdu), item.body.of(urdu), for (final step in item.steps) step.of(urdu)].join('۔ ');
  }

  Future<void> _toggleListen() async {
    final speech = context.read<SpeechProvider>();
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_speaking) {
      await speech.stopSpeaking();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    try {
      final urdu = s.isUrdu;
      if (widget.both) {
        await speech.speak(_spokenText(urdu), language: urdu ? 'Urdu' : 'English');
        if (mounted && _speaking) await speech.speak(_spokenText(!urdu), language: urdu ? 'English' : 'Urdu');
      } else {
        await speech.speak(_spokenText(urdu), language: urdu ? 'Urdu' : 'English');
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(s.listenFailed)));
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final item = widget.item;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BilingualBlock(item.title, both: widget.both, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            BilingualBlock(item.body, both: widget.both),
            const SizedBox(height: 12),
            for (var i = 0; i < item.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(radius: 12, child: Text('${i + 1}', style: theme.textTheme.labelSmall)),
                    const SizedBox(width: 10),
                    Expanded(child: BilingualBlock(item.steps[i], both: widget.both)),
                  ],
                ),
              ),
            if (item.id == SupportLibrary.breathing.id) const Center(child: BreathingCircle()),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                icon: Icon(_speaking ? Icons.stop_rounded : Icons.volume_up_rounded),
                label: Text(_speaking ? s.stopAction : s.listenAction),
                onPressed: _toggleListen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The fixed help screen for the lowest mood or words about self-harm. Its
/// content never changes and is never generated.
class HelpNowScreen extends StatelessWidget {
  const HelpNowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final both = context.watch<WellbeingProvider>().showBothLanguages;
    return Scaffold(
      appBar: AppBar(title: Text(SupportLibrary.helpNowTitle.of(s.isUrdu))),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            BilingualBlock(SupportLibrary.helpNowBody, both: both, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            for (var i = 0; i < SupportLibrary.helpNowSteps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(radius: 14, child: Text('${i + 1}')),
                    const SizedBox(width: 12),
                    Expanded(child: BilingualBlock(SupportLibrary.helpNowSteps[i], both: both)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              icon: const Icon(Icons.front_hand_rounded),
              label: Text(s.showThisToSomeone),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => const ShowSomeoneScreen(),
              )),
            ),
            const SizedBox(height: 24),
            const Center(child: BreathingCircle()),
            const SizedBox(height: 24),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(s.iAmSafeNow),
            ),
          ],
        ),
      ),
    );
  }
}

/// A full-screen message for the user to show a person nearby, in both
/// languages and very large type.
class ShowSomeoneScreen extends StatelessWidget {
  const ShowSomeoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    const message = SupportLibrary.showSomeone;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        message.en,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700, height: 1.3, fontFamily: 'NotoSans'),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        message.ur,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: Colors.white, fontSize: 30, height: 2.0, fontFamily: 'NotoNastaliqUrdu'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, minimumSize: const Size.fromHeight(56)),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(s.doneAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A circle that grows for 4 seconds (breathe in) and shrinks for 6 (breathe
/// out). Visual only, so it works without sound. With animations turned off
/// in the phone's settings it stands still and shows both steps.
class BreathingCircle extends StatefulWidget {
  const BreathingCircle({super.key, this.size = 180});

  final double size;

  static const Duration inhale = Duration(seconds: 4);
  static const Duration exhale = Duration(seconds: 6);

  @override
  State<BreathingCircle> createState() => _BreathingCircleState();
}

class _BreathingCircleState extends State<BreathingCircle> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: BreathingCircle.inhale + BreathingCircle.exhale,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    final still = MediaQuery.of(context).disableAnimations;
    final inhaleShare = BreathingCircle.inhale.inMilliseconds /
        (BreathingCircle.inhale + BreathingCircle.exhale).inMilliseconds;
    return Semantics(
      label: '${s.breatheIn} 4, ${s.breatheOut} 6',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final breathingIn = t < inhaleShare;
            final progress = breathingIn ? t / inhaleShare : (t - inhaleShare) / (1 - inhaleShare);
            final eased = Curves.easeInOut.transform(progress);
            final scale = still ? 0.8 : (breathingIn ? 0.55 + 0.45 * eased : 1.0 - 0.45 * eased);
            final label = still ? '${s.breatheIn} 4 · ${s.breatheOut} 6' : (breathingIn ? s.breatheIn : s.breatheOut);
            return Center(
              child: Container(
                width: widget.size * scale,
                height: widget.size * scale,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: .18),
                  border: Border.all(color: colors.primary, width: 3),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
