import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({required this.reputationScore, super.key});

  final int reputationScore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Coin/Reputation
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, color: Colors.grey, size: 20),
                const Gap(8),
                Text(
                  reputationScore.toString(),
                  style: TextStyles.titleHeadline.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const Gap(12),
        // Stats Graph Button
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bar_chart, color: Colors.grey, size: 20),
                const Gap(8),
                Text(
                  'Your Stats',
                  style: TextStyles.titleTag.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
