import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';

import 'package:app/src/features/profile/domain/entities/relationship_status_entity.dart';
import 'package:app/src/features/profile/presentation/widgets/profile_action_buttons.dart';
import 'package:app/src/features/profile/presentation/widgets/profile_expandable_bio.dart';
import 'package:app/src/features/profile/presentation/widgets/public_user_action_buttons.dart';
import 'package:app/src/features/profile/presentation/widgets/profile_rank_meta_line.dart';
import 'package:app/src/features/profile/presentation/widgets/profile_stats_row.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    required this.displayName,
    required this.userId,
    required this.avatarUrl,
    required this.bio,
    required this.city,
    required this.country,
    required this.rankTier,
    required this.reputationScore,
    this.region = '',
    this.isPublicProfile = false,
    this.relationshipStatus,
    this.onToggleFavorite,
    this.onMessage,
    this.onFollow,
    this.onUnfollow,
    this.onUnblock,
    super.key,
  });

  final String displayName;
  final String userId;
  final String avatarUrl;
  final String bio;
  final String city;
  final String country;
  final String rankTier;
  final int reputationScore;
  final String region;
  final bool isPublicProfile;
  final RelationshipStatusEntity? relationshipStatus;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onMessage;
  final VoidCallback? onFollow;
  final VoidCallback? onUnfollow;
  final VoidCallback? onUnblock;

  @override
  Widget build(BuildContext context) {
    final locationParts = <String>[
      if (city.trim().isNotEmpty) city.trim(),
      if (region.trim().isNotEmpty) region.trim(),
      if (country.trim().isNotEmpty) country.trim(),
    ];
    final locationLine =
        locationParts.isNotEmpty ? locationParts.join(' | ') : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.feedMoonstoneBase,
        gradient: const RadialGradient(
          center: Alignment(-1.84, -1.0),
          radius: 2.6,
          stops: <double>[0.0, 0.2404, 0.4423, 0.6683, 0.899],
          colors: AppColors.feedMoonstoneGradient,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.feedMoonstoneBorder,
          width: 1,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x29000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatarUrl.trim().isNotEmpty
                  ? CustomNetworkImage(
                      imageUrl: avatarUrl,
                      width: 126,
                      height: 126,
                      borderRadius: BorderRadius.circular(12),
                    )
                  : Container(
                      width: 126,
                      height: 126,
                      decoration: BoxDecoration(
                        color: AppColors.colorff2A2A2B,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        size: 36,
                        color: AppColors.colorff9CA3AF,
                      ),
                    ),
              const Gap(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName.isNotEmpty ? displayName : '@$userId',
                      style: TextStyles.titleHeadline.copyWith(
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (rankTier.trim().isNotEmpty) ...[
                      const Gap(8),
                      ProfileRankMetaLine(rankTier: rankTier),
                    ],
                    if (locationLine != null) ...[
                      const Gap(8),
                      Text(
                        locationLine,
                        style: TextStyles.bodyMain.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                    const Gap(8),
                    ProfileExpandableBio(text: bio),
                    const Gap(8),
                    ProfileStatsRow(goldenSeals: reputationScore),
                  ],
                ),
              ),
            ],
          ),
          const Gap(12),
          isPublicProfile
              ? PublicUserActionButtons(
                  userId: userId,
                  relationshipStatus: relationshipStatus,
                  onFollow: onFollow,
                  onUnfollow: onUnfollow,
                  onUnblock: onUnblock,
                  onMessage: () {},
                )
              : const ProfileActionButtons(),
        ],
      ),
    );
  }
}
