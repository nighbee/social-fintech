import 'dart:ui';

import 'package:flutter/material.dart';

class HonorComposeSurface extends StatelessWidget {
  const HonorComposeSurface({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            color: const Color(0x33202020),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x6632363F),
                Color(0x3D111418),
                Color(0x6622262D),
              ],
              stops: [0.0, 0.52, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -16,
                left: 40,
                child: _blob(const Color(0x52A8672A), 150),
              ),
              Positioned(
                top: 88,
                right: -28,
                child: _blob(const Color(0x3C84552A), 120),
              ),
              Positioned(
                bottom: -24,
                left: 60,
                child: _blob(const Color(0x2B5D6B80), 130),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}
