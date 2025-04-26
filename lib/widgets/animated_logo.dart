import 'package:flutter/material.dart';

class AnimatedLogo extends StatelessWidget {
  final Animation<double> scaleAnimation;
  final double size;

  const AnimatedLogo({
    super.key,
    required this.scaleAnimation,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: scaleAnimation,
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
      ),
    );
  }
}
