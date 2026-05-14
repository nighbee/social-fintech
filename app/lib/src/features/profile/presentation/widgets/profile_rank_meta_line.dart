import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';

/// Строка ранга в стиле [rating_page] (`Moonstone · Intention · A` + глобус).
class ProfileRankMetaLine extends StatelessWidget {
  const ProfileRankMetaLine({
    required this.rankTier,
    super.key,
    /// Если задан — подставляется вместо стандартного голубого акцента (например на карточках поиска).
    this.accentColor,
  });

  final String rankTier;
  final Color? accentColor;

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

    final color = accentColor ?? const Color(0xFF74AFE3);
    final textStyle = TextStyles.bodyMain.copyWith(
      fontFamily: 'CanelaDeckTrial',
      fontWeight: FontWeight.w400,
      fontSize: 12,
      height: 20 / 12,
      color: color,
    );

    const iconSize = 12.0;
    final rankLine = parts.join(' \u2022 ');

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: textStyle,
        children: [
          TextSpan(text: rankLine),
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(width: 6),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Assets.icons.global.svg(
              width: iconSize,
              height: iconSize,
              colorFilter: ColorFilter.mode(
                color,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
