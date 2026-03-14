import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/profile/presentation/models/rank_card_item.dart';
import 'package:app/src/features/profile/presentation/widgets/rangs/gemstone_sphere.dart';
import 'package:app/src/features/profile/presentation/widgets/rangs/tier_indicators.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class RankCard extends StatelessWidget {
  const RankCard({super.key, required this.rank});

  final RankCardItem rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA9A9A9).withValues(alpha: 0.16),
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Column(
            children: [
              Text(
                '${rank.name} | ${rank.tier}',
                textAlign: TextAlign.center,
                style: TextStyles.bodyLarge.copyWith(
                  fontSize: 18,
                  height: 1,
                  color: AppColors.textBrand.withValues(alpha: 0.7),
                ),
              ),
              const Gap(20),
              Text(
                '${rank.headline}\n${rank.description}',
                textAlign: TextAlign.center,
                style: TextStyles.bodyMain.copyWith(
                  fontSize: 12,
                  height: 1.2,
                  color: const Color(0xFFA3A3A3).withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
          const Gap(32),
          SizedBox(
            width: 230,
            child: Column(
              children: [
                GemstoneSphere(
                  image: rank.image,
                  style: rank.gemStyle,
                ),
                const Gap(16),
                Text(
                  'Required: ${rank.requiredHonorLabel} honor',
                  textAlign: TextAlign.center,
                  style: TextStyles.bodyMain.copyWith(
                    fontSize: 12,
                    height: 1,
                    color: AppColors.textBrand.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: TierIndicators(
              filledTierCount: rank.filledTierCount,
            ),
          ),
        ],
      ),
    );
  }
}
