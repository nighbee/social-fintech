import 'package:app/gen/assets.gen.dart';
import 'package:app/src/features/profile/presentation/models/rank_card_item.dart';
import 'package:flutter/material.dart';

class GemstoneSphere extends StatelessWidget {
  const GemstoneSphere({
    super.key,
    required this.image,
    required this.style,
    this.size = 230,
  });

  final AssetGenImage image;
  final RankGemStyle style;
  final double size;

  @override
  Widget build(BuildContext context) {
    final config = switch (style) {
      RankGemStyle.pearl => const _GemGlowConfig(
          color: Colors.white,
          blurRadius: 24,
          spreadRadius: 1,
          opacity: 0.08,
        ),
      RankGemStyle.moonstone => const _GemGlowConfig(
          color: Color(0xFF8EB2FF),
          blurRadius: 26,
          spreadRadius: 1,
          opacity: 0.12,
        ),
      RankGemStyle.jade => const _GemGlowConfig(
          color: Color(0xFF406B3B),
          blurRadius: 18,
          spreadRadius: 0,
          opacity: 0.10,
        ),
      RankGemStyle.lapisLazuli => const _GemGlowConfig(
          color: Color(0xFF485FC6),
          blurRadius: 18,
          spreadRadius: 0,
          opacity: 0.10,
        ),
      RankGemStyle.ammolite => const _GemGlowConfig(
          color: Color(0xFFB57A18),
          blurRadius: 22,
          spreadRadius: 1,
          opacity: 0.12,
        ),
      RankGemStyle.onyx => const _GemGlowConfig(
          color: Colors.white,
          blurRadius: 12,
          spreadRadius: 0,
          opacity: 0.07,
        ),
      RankGemStyle.supernova => const _GemGlowConfig(
          color: Colors.white,
          blurRadius: 44,
          spreadRadius: 6,
          opacity: 0.34,
        ),
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: config.color.withValues(alpha: config.opacity),
            blurRadius: config.blurRadius,
            spreadRadius: config.spreadRadius,
          ),
          if (style == RankGemStyle.supernova)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.18),
              blurRadius: 74,
              spreadRadius: 8,
            ),
          if (style == RankGemStyle.supernova)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.10),
              blurRadius: 98,
              spreadRadius: 16,
            ),
          if (style == RankGemStyle.pearl)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.05),
              blurRadius: 42,
              spreadRadius: 6,
            ),
          if (style == RankGemStyle.moonstone)
            BoxShadow(
              color: const Color(0xFFFFCF70).withValues(alpha: 0.08),
              blurRadius: 34,
              spreadRadius: 3,
            ),
          if (style == RankGemStyle.onyx)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.04),
              blurRadius: 24,
              spreadRadius: 0,
            ),
        ],
        gradient: style == RankGemStyle.supernova
            ? const RadialGradient(
                colors: [
                  Color(0xFFF5F6FB),
                  Color(0xFFE8EAF2),
                ],
              )
            : null,
      ),
      child: ClipOval(
        child: image.image(
          width: size,
          height: size,
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}

class _GemGlowConfig {
  const _GemGlowConfig({
    required this.color,
    required this.blurRadius,
    required this.spreadRadius,
    required this.opacity,
  });

  final Color color;
  final double blurRadius;
  final double spreadRadius;
  final double opacity;
}
