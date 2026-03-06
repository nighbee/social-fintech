import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/profile/domain/entities/rank_entity.dart';
import 'package:app/src/features/profile/presentation/widgets/rangs/gemstone_sphere.dart';
import 'package:app/src/features/profile/presentation/widgets/rangs/tier_indicators.dart';
import 'package:flutter/material.dart';

class RankCard extends StatelessWidget {
  const RankCard({super.key, required this.rank, this.nextRank});

  final RankEntity rank;
  final RankEntity? nextRank;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color.fromARGB(0, 45, 36, 64).withValues(),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Color.fromARGB(0, 45, 36, 64).withValues(alpha: 0.45),
                blurRadius: 20,
                spreadRadius: 0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rank level number

              // Rank name and tier
              Text(
                '${rank.name} | ${rank.tier}',
                style: TextStyles.titleTag.copyWith(
                  color: AppColors.colorff74afe3,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Gemstone sphere
              GemstoneSphere(imagePath: rank.imagePath, size: 220),
              const SizedBox(height: 40),

              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  rank.description,
                  style: TextStyles.bodyLarge.copyWith(
                    color: AppColors.colorff9CA3AF,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // Required XP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Required: ${rank.requiredExp} ',
                    style: TextStyles.bodyMain.copyWith(
                      color: AppColors.colorffffffff,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'seals',
                    style: TextStyles.bodyMain.copyWith(
                      color: AppColors.colorff9CA3AF,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Tier indicators
              TierIndicators(
                tiers: rank.tierBadges,
                activeTiers: ['C', 'B', 'A', 'S'],
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),

        Text(
          '${rank.level}',
          style: TextStyles.titleTag.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
