import 'package:flutter/material.dart';

/// The original praying-hands and cross logo supplied in the storyboard.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '아멘모아 로고',
    image: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * .24),
      child: Image.asset(
        'assets/brand/amenmoa-logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
      ),
    ),
  );
}
