import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:humsukhan/modules/environmental_alerts/services/pcm_window_accumulator.dart';

import 'fakes.dart';

void main() {
  test('windows are cut on schedule whatever size the chunks arrive in', () {
    final accumulator = PcmWindowAccumulator(windowSamples: 6, hopSamples: 2);
    final windows = <Float32List>[];

    accumulator.add(pcm([1, 2]), windows.add);
    accumulator.add(pcm([3]), windows.add);
    accumulator.add(pcm([4, 5, 6]), windows.add);

    expect(windows, hasLength(1));
    expect(windows.single.first, closeTo(1 / 32768, 1e-9));
    expect(windows.single.last, closeTo(6 / 32768, 1e-9));

    accumulator.add(pcm([7, 8]), windows.add);
    expect(windows, hasLength(2));
    expect(windows[1].first, closeTo(3 / 32768, 1e-9));
    expect(windows[1].last, closeTo(8 / 32768, 1e-9));
  });

  test('a sample split across two chunks is reassembled', () {
    final accumulator = PcmWindowAccumulator(windowSamples: 3, hopSamples: 3);
    final windows = <Float32List>[];
    final bytes = pcm([100, -200, 300]);

    accumulator.add(Uint8List.fromList(bytes.sublist(0, 3)), windows.add);
    accumulator.add(Uint8List.fromList(bytes.sublist(3)), windows.add);

    expect(accumulator.totalSamples, 3);
    expect(windows.single.map((s) => (s * 32768).round()), [100, -200, 300]);
  });

  test('a chunk that starts at an odd byte offset is read correctly', () {
    // Platform channels can hand over a view into a larger buffer.
    final backing = Uint8List(7)..setRange(1, 7, pcm([10, -20, 30]));
    final view = Uint8List.sublistView(backing, 1);
    final accumulator = PcmWindowAccumulator(windowSamples: 3, hopSamples: 3);
    final windows = <Float32List>[];

    accumulator.add(view, windows.add);

    expect(windows.single.map((s) => (s * 32768).round()), [10, -20, 30]);
  });

  test('when a chunk makes several hops due, only the latest window is analysed', () {
    final accumulator = PcmWindowAccumulator(windowSamples: 4, hopSamples: 1);
    final windows = <Float32List>[];

    accumulator.add(pcm([1, 2, 3, 4, 5, 6, 7, 8]), windows.add);

    expect(windows, hasLength(1));
    expect(windows.single.map((s) => (s * 32768).round()), [5, 6, 7, 8]);

    accumulator.add(pcm([9]), windows.add);
    expect(windows, hasLength(2));
    expect(windows[1].map((s) => (s * 32768).round()), [6, 7, 8, 9]);
  });

  test('reset starts a fresh stream', () {
    final accumulator = PcmWindowAccumulator(windowSamples: 2, hopSamples: 2);
    final windows = <Float32List>[];
    accumulator.add(pcm([1]), windows.add);
    accumulator.reset();
    accumulator.add(pcm([2]), windows.add);
    expect(windows, isEmpty);
    accumulator.add(pcm([3]), windows.add);
    expect(windows.single.map((s) => (s * 32768).round()), [2, 3]);
  });
}
