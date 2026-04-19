import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';

/// Строка ранга в стиле [rating_page] (`Moonstone · Intention · A` + глобус).
class ProfileRankMetaLine extends StatelessWidget {
  const ProfileRankMetaLine({
    required this.rankTier,
    super.key,
  });

  final String rankTier;

  @override
  Widget build(BuildContext context) {
    final trimmed = rankTier.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final parts = trimmed
        .split(RegExp(r'\s*[|·]\s*'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return const SizedBox.shrink();

    final textStyle = TextStyles.bodyMain.copyWith(
      fontSize: 11,
      height: 13 / 11,
      color: const Color(0xFF74AFE3),
    );

    const iconSize = 12.0;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 5,
      runSpacing: 2,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) const _MetaDot(size: 2.5),
          Text(parts[i], style: textStyle),
        ],
        const _MetaDot(size: 2.5),
        Assets.icons.global.svg(
          width: iconSize,
          height: iconSize,
          colorFilter: const ColorFilter.mode(
            Color(0xFF74AFE3),
            BlendMode.srcIn,
          ),
        ),
      ],
    );
  }
}

class _MetaDot extends StatelessWidget {
  const _MetaDot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF74AFE3),
        shape: BoxShape.circle,
      ),
    );
  }
}
