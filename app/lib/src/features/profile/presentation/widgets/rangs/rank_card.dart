import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/profile/presentation/models/rank_card_item.dart';
import 'package:app/src/features/profile/presentation/widgets/rangs/gemstone_sphere.dart';
import 'package:app/src/features/profile/presentation/widgets/rangs/tier_indicators.dart';
import 'package:flutter/material.dart';

class RankCard extends StatelessWidget {
  const RankCard({super.key, required this.rank, this.nextRank});

  final RankCardItem rank;
  final RankCardItem? nextRank;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.height < 760;
    final gradient = _gradientFor(rank.name);
    final accentColor = gradient.first;
    final sphereSize = isCompact ? 180.0 : 220.0;
    const tiers = ['C', 'B', 'A', 'S'];
    final activeCount = rank.filledTierCount.clamp(0, tiers.length).toInt();
    final activeTiers = tiers.take(activeCount);

    return Container(
      padding: EdgeInsets.all(isCompact ? 18 : 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gradient.first.withValues(alpha: 0.38),
            gradient.last.withValues(alpha: 0.2),
            const Color(0xFF12151C),
          ],
          stops: const [0.0, 0.34, 1.0],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.18),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: _InfoChip(
                  icon: Assets.icons.ratingIcon.svg(
                    width: 16,
                    height: 16,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                  label: rank.headline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoChip(
                  icon: Assets.icons.rewardIndicator.svg(
                    width: 16,
                    height: 16,
                    colorFilter: ColorFilter.mode(
                      accentColor,
                      BlendMode.srcIn,
                    ),
                  ),
                  label: '${rank.requiredHonorLabel} seals',
                  alignment: Alignment.centerRight,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 22 : 28),
          Text(
            rank.name,
            style: TextStyles.titleHeadline.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: isCompact ? 28 : 34,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            rank.tier.toUpperCase(),
            style: TextStyles.titleTag.copyWith(
              color: accentColor,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isCompact ? 24 : 30),
          Container(
            width: sphereSize + 30,
            height: sphereSize + 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accentColor.withValues(alpha: 0.28),
                  Colors.transparent,
                ],
              ),
            ),
            child: Center(
              child: GemstoneSphere(
                image: rank.image,
                style: rank.gemStyle,
                size: sphereSize,
              ),
            ),
          ),
          SizedBox(height: isCompact ? 24 : 30),
          Text(
            rank.description,
            style: TextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isCompact ? 20 : 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Assets.icons.statsIcon.svg(
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(accentColor, BlendMode.srcIn),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Next milestone',
                        style: TextStyles.bodySecondary.copyWith(
                          color: Colors.white60,
                        ),
                      ),
                      Text(
                        nextRank == null
                            ? 'Legendary peak reached'
                            : nextRank!.name,
                        style: TextStyles.bodyMain.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isCompact ? 20 : 24),
          TierIndicators(
            tiers: tiers,
            activeTiers: activeTiers.toList(growable: false),
            accentColor: accentColor,
          ),
        ],
      ),
    );
  }

  List<Color> _gradientFor(String rankName) {
    switch (rankName.toLowerCase()) {
      case 'pearl':
        return const [Color(0xFFE6DCCF), Color(0xFFB8A6A2)];
      case 'moonstone':
        return const [Color(0xFF8FB0FF), Color(0xFF5362D8)];
      case 'jade':
        return const [Color(0xFF57D38A), Color(0xFF0D7B5D)];
      case 'lapis lazuli':
        return const [Color(0xFF6FA0FF), Color(0xFF2144B2)];
      case 'ammolite':
        return const [Color(0xFFFF9E66), Color(0xFFB63D72)];
      case 'onyx':
        return const [Color(0xFF9EA7B4), Color(0xFF404958)];
      case 'sunstone':
        return const [Color(0xFFFFC75A), Color(0xFFFF6A2A)];
      case 'diamond':
        return const [Color(0xFFC6F1FF), Color(0xFF7D8BFF)];
      default:
        return const [Color(0xFF9D8BFF), Color(0xFF5567FF)];
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.alignment = Alignment.centerLeft,
  });

  final Widget icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyles.bodySecondary.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
