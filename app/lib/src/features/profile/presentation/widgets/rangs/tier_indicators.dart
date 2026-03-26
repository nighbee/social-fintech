import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class TierIndicators extends StatelessWidget {
  const TierIndicators({
    super.key,
    required this.tiers,
    this.activeTiers = const [],
    this.accentColor = Colors.white,
  });

  final List<String> tiers;
  final List<String> activeTiers;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 18,
      runSpacing: 10,
      children: tiers.map((tier) {
        final isActive = activeTiers.contains(tier);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? accentColor
                    : AppColors.whiteBackground.withValues(alpha: 0.18),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
            const Gap(6),
            Text(
              tier,
              style: TextStyles.titleTag.copyWith(
                color: AppColors.whiteBackground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
