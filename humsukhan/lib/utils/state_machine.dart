import 'package:flutter/foundation.dart';

/// The current state of a process with a fixed set of states, and the moves
/// between them it allows, written down in one place.
///
/// Each process declares its states as an enum and its moves as a table:
///
///     final _phase = StateMachine(Phase.idle, {
///       Phase.idle: {Phase.starting},
///       Phase.starting: {Phase.running, Phase.idle},
///       Phase.running: {Phase.idle},
///     });
///
/// and changes state only with [moveTo]. A move missing from the table is a
/// bug in the process: it fails an assertion, so tests catch it, and in a
/// release build it still happens, so a gap in the table never strands the
/// app. Staying in the same state is always allowed and changes nothing.
///
/// See docs/state-machines.md for every machine in the app.
class StateMachine<S extends Enum> {
  StateMachine(this._state, Map<S, Set<S>> transitions) : transitions = Map.unmodifiable(transitions);

  /// The states each state may move to.
  final Map<S, Set<S>> transitions;

  S _state;

  /// The current state.
  S get state => _state;

  /// Whether the current state is one of [states].
  bool isIn(Set<S> states) => states.contains(_state);

  /// Whether [next] may follow the current state.
  bool canMoveTo(S next) => next == _state || (transitions[_state]?.contains(next) ?? false);

  /// Moves to [next], and returns whether the state changed.
  bool moveTo(S next) {
    assert(canMoveTo(next), '$S: ${_state.name} cannot move to ${next.name}');
    if (next == _state) return false;
    _state = next;
    return true;
  }

  /// Moves to [next] only if the table allows it from here, and returns
  /// whether it did. For events that are meaningful in some states and
  /// ignored in others.
  bool tryMoveTo(S next) {
    if (next == _state || !canMoveTo(next)) return false;
    _state = next;
    return true;
  }

  @override
  String toString() => '$S.${_state.name}';
}

/// Checks a transition table: every state of [values] has an entry, every
/// state can be reached from [initial], and none is a dead end unless listed
/// in [terminal]. For tests.
@visibleForTesting
List<String> transitionTableProblems<S extends Enum>(
  List<S> values,
  Map<S, Set<S>> transitions, {
  required S initial,
  Set<S> terminal = const {},
}) {
  final problems = <String>[];
  for (final state in values) {
    if (!transitions.containsKey(state)) problems.add('${state.name} has no entry');
    if (!terminal.contains(state) && (transitions[state] ?? const {}).isEmpty) problems.add('${state.name} is a dead end');
  }
  final reached = <S>{initial};
  final queue = [initial];
  while (queue.isNotEmpty) {
    for (final next in transitions[queue.removeLast()] ?? const <Never>{}) {
      if (reached.add(next)) queue.add(next);
    }
  }
  for (final state in values) {
    if (!reached.contains(state)) problems.add('${state.name} cannot be reached from ${initial.name}');
  }
  return problems;
}
