import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The logos are WebP, sized for the largest place each is drawn: the
  // onboarding lockup at 200dp, the badge mark at 108dp, both at 4x.
  for (final (asset, size) in [('assets/logo.webp', 800), ('assets/icon_mark.webp', 432)]) {
    test('$asset decodes at $size px and stays small', () async {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, lessThan(100 * 1024));
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      expect(frame.image.width, size);
      expect(frame.image.height, size);
    });
  }

  test('the Android icon is a single xxxhdpi WebP, not a full-size mdpi bitmap', () {
    // In the unqualified drawable folder Android treats a bitmap as mdpi and
    // scales it up for the screen; the 1254 px logo became a 3762 px bitmap
    // in memory on a typical phone. As xxxhdpi it is scaled down instead.
    final res = Directory('android/app/src/main/res');
    final logos = res
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.uri.pathSegments.last.startsWith('humsukhan_logo.'))
        .map((f) => f.path.substring(res.path.length + 1))
        .toList();
    expect(logos, ['drawable-xxxhdpi/humsukhan_logo.webp']);
    expect(File('${res.path}/${logos.single}').lengthSync(), lessThan(200 * 1024));
  });
}
