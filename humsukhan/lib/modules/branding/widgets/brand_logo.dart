import 'package:flutter/widgets.dart';

class BrandLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  const BrandLogo({super.key, this.width, this.height, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/logo.png',
        width: width,
        height: height,
        fit: fit,
      );
}
