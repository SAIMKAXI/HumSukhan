import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/models/models.dart';
import 'package:humsukhan/navigation/app_stage.dart';
import 'package:humsukhan/providers/auth_provider.dart';
import 'package:humsukhan/providers/everyday_speech_provider.dart';
import 'package:humsukhan/providers/wellbeing_provider.dart';
import 'package:humsukhan/screens/auth_screen.dart';
import 'package:humsukhan/screens/session_live_screen.dart';
import 'package:humsukhan/services/conversation_engine.dart';
import 'package:humsukhan/services/everyday_bilingual_stt.dart';
import 'package:humsukhan/services/stt/enhanced_stt.dart';
import 'package:humsukhan/utils/state_machine.dart';

/// Every state machine's table is complete: each state has an entry, can be
/// reached from where the machine starts, and is a dead end only on purpose.
/// docs/state-machines.md draws each one.
void main() {
  group('transition tables', () {
    void check<S extends Enum>(String name, List<S> values, Map<S, Set<S>> table, {required S initial, Set<S> terminal = const {}}) {
      test(name, () => expect(transitionTableProblems(values, table, initial: initial, terminal: terminal), isEmpty));
    }

    check('auth form', AuthFormMode.values, authFormTransitions, initial: AuthFormMode.signIn);
    check('auth session', AuthStatus.values, authTransitions, initial: AuthStatus.signedOut);
    check('conversation', ConversationState.values, conversationTransitions, initial: ConversationState.idle);
    check('conversation engine', ConversationEngineState.values, conversationEngineTransitions, initial: ConversationEngineState.idle);
    check('listening', ListeningPhase.values, listeningTransitions, initial: ListeningPhase.idle);
    check('recognizer', RecognizerPhase.values, recognizerTransitions, initial: RecognizerPhase.idle);
    check('cloud stream', StreamPhase.values, streamTransitions, initial: StreamPhase.idle);
    check('caption watchdog', WatchdogState.values, watchdogTransitions, initial: WatchdogState.waitingForSound);
    check('live session microphone', LiveMic.values, liveMicTransitions, initial: LiveMic.preparing, terminal: {LiveMic.unavailable});
    check('wellbeing check-ins', CheckInsLoad.values, checkInsLoadTransitions, initial: CheckInsLoad.loading, terminal: {CheckInsLoad.loaded});
  });

  group('StateMachine', () {
    final table = {_Light.red: {_Light.green}, _Light.green: {_Light.amber}, _Light.amber: {_Light.red}};

    test('moves along the table', () {
      final light = StateMachine(_Light.red, table);
      expect(light.moveTo(_Light.green), isTrue);
      expect(light.state, _Light.green);
      expect(light.moveTo(_Light.green), isFalse, reason: 'staying put changes nothing');
    });

    test('a move the table does not allow fails in debug builds', () {
      final light = StateMachine(_Light.red, table);
      expect(() => light.moveTo(_Light.amber), throwsA(isA<AssertionError>()));
    });

    test('tryMoveTo makes only allowed moves', () {
      final light = StateMachine(_Light.red, table);
      expect(light.tryMoveTo(_Light.amber), isFalse);
      expect(light.state, _Light.red);
      expect(light.tryMoveTo(_Light.green), isTrue);
    });

    test('the table checker finds gaps', () {
      final problems = transitionTableProblems(_Light.values, {_Light.red: {_Light.green}, _Light.green: <_Light>{}}, initial: _Light.red);
      expect(problems, containsAll(['green is a dead end', 'amber has no entry', 'amber cannot be reached from red']));
    });
  });

  group('app stage', () {
    AppStage stage({bool recovering = false, bool loaded = true, bool signedIn = true, bool onboarded = true}) =>
        appStageFor(recoveringPassword: recovering, settingsLoaded: loaded, signedIn: signedIn, onboardingComplete: onboarded);

    test('a password-reset link comes before everything', () {
      expect(stage(recovering: true, loaded: false), AppStage.settingNewPassword);
      expect(stage(recovering: true, onboarded: false), AppStage.settingNewPassword);
    });

    test('then settings, sign-in and onboarding, in that order', () {
      expect(stage(loaded: false, signedIn: false), AppStage.loadingSettings);
      expect(stage(signedIn: false, onboarded: false), AppStage.signedOut);
      expect(stage(onboarded: false), AppStage.onboarding);
      expect(stage(), AppStage.ready);
    });
  });

  test('every live session microphone state has its own status line', () {
    final lines = {for (final state in LiveMic.values) state.status};
    expect(lines, hasLength(LiveMic.values.length));
  });
}

enum _Light { red, green, amber }
