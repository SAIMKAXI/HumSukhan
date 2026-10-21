import 'dart:typed_data';

/// Turns a 16-bit little-endian mono PCM stream, delivered in chunks of any
/// size, into overlapping analysis windows: the most recent [windowSamples]
/// samples, once every [hopSamples].
///
/// When a single chunk makes several hops due at once, only the latest window
/// is emitted. The earlier ones describe audio that has already been
/// superseded, and classifying them would only spend battery to repeat work.
class PcmWindowAccumulator {
  PcmWindowAccumulator({this.windowSamples = 48000, this.hopSamples = 16000})
      : assert(windowSamples > 0),
        assert(hopSamples > 0),
        _buffer = Int16List(windowSamples),
        _nextWindowAt = windowSamples;

  final int windowSamples;
  final int hopSamples;
  final Int16List _buffer;
  int _writePos = 0;
  int _totalSamples = 0;
  int _nextWindowAt;
  int _windowsEmitted = 0;
  int? _pendingByte;

  int get totalSamples => _totalSamples;
  int get windowsEmitted => _windowsEmitted;

  void reset() {
    _writePos = 0;
    _totalSamples = 0;
    _nextWindowAt = windowSamples;
    _windowsEmitted = 0;
    _pendingByte = null;
  }

  void add(Uint8List data, void Function(Float32List window) onWindow) {
    if (data.isEmpty) return;
    // Read through ByteData: a Uint8List from a platform channel can start at
    // an odd offset, which an Int16List view would reject.
    final bytes = ByteData.sublistView(data);
    var index = 0;
    final pending = _pendingByte;
    if (pending != null) {
      _push((data[0] << 8 | pending).toSigned(16));
      _pendingByte = null;
      index = 1;
    }
    for (; index + 1 < data.length; index += 2) {
      _push(bytes.getInt16(index, Endian.little));
    }
    if (index < data.length) _pendingByte = data[index];

    if (_totalSamples < _nextWindowAt) return;
    final window = Float32List(windowSamples);
    for (var i = 0; i < windowSamples; i++) {
      window[i] = _buffer[(_writePos + i) % windowSamples] / 32768.0;
    }
    while (_nextWindowAt <= _totalSamples) {
      _nextWindowAt += hopSamples;
    }
    _windowsEmitted++;
    onWindow(window);
  }

  void _push(int sample) {
    _buffer[_writePos] = sample;
    _writePos = (_writePos + 1) % windowSamples;
    _totalSamples++;
  }
}
