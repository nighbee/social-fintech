import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({required this.goldenSeals, super.key});

  final int goldenSeals;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFF0C14D).withValues(alpha: 0.25),
                  const Color(0xFF7A4F11).withValues(alpha: 0.22),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFF0C14D).withValues(alpha: 0.28),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Assets.icons.rewardIndicator.svg(
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFFF6D46B),
                    BlendMode.srcIn,
                  ),
                ),
                const Gap(8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goldenSeals.toString(),
                      style: TextStyles.titleHeadline.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Golden Seals',
                      style: TextStyles.bodySecondary.copyWith(
                        color: const Color(0xFFF6D46B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Gap(12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Assets.icons.statsIcon.svg(
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFFCACACA),
                    BlendMode.srcIn,
                  ),
                ),
                const Gap(8),
                Flexible(
                  child: Text(
                    'Profile Stats',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyles.titleTag.copyWith(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
