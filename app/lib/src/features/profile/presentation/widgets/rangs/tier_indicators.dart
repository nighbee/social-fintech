import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class TierIndicators extends StatelessWidget {
  const TierIndicators({
    super.key,
    this.tiers = const ['C', 'B', 'A', 'S'],
    this.filledTierCount = 0,
  });

  final List<String> tiers;
  final int filledTierCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 164,
      child: Column(
        children: [
          Row(
            children: [
              for (var index = 0; index < tiers.length; index++)
                Expanded(
                  child: Text(
                    tiers[index],
                    textAlign: TextAlign.center,
                    style: TextStyles.bodyLarge.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: index < filledTierCount
                          ? AppColors.textBrand
                          : const Color(0xFFA3A3A3),
                    ),
                  ),
                ),
            ],
          ),
          const Gap(6),
          Row(
            children: [
              for (var index = 0; index < tiers.length; index++) ...[
                _TierMarker(
                  isActive: index < filledTierCount,
                ),
                if (index < tiers.length - 1)
                  Expanded(
                    child: Container(
                      height: 1,
                      color: const Color(0xFF444444),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TierMarker extends StatelessWidget {
  const _TierMarker({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF444444),
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? const Color(0xFF757576) : Colors.transparent,
        ),
      ),
    );
  }
}
