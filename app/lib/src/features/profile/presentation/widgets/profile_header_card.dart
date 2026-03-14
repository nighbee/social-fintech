import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';

import 'package:app/src/features/profile/domain/entities/relationship_status_entity.dart';
import 'package:app/src/features/profile/presentation/widgets/profile_action_buttons.dart';
import 'package:app/src/features/profile/presentation/widgets/public_user_action_buttons.dart';
import 'package:app/src/features/profile/presentation/widgets/profile_stats_row.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    required this.displayName,
    required this.userId,
    required this.avatarUrl,
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
    this.onOpenStats,
    super.key,
  });

  final String displayName;
  final String userId;
  final String avatarUrl;
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
  final VoidCallback? onOpenStats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark card background
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CustomNetworkImage(
                imageUrl: avatarUrl.isNotEmpty
                    ? avatarUrl
                    : 'https://i.pravatar.cc/150',
                width: 126,
                height: 126,
                borderRadius: BorderRadius.circular(12),
              ),
              const Gap(16),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName.isNotEmpty
                          ? displayName
                          : '@$userId', // Fallback to ID/Username
                      style: TextStyles.titleHeadline.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const Gap(10),
                    Text(
                      region.isNotEmpty
                          ? '$city, $region | $country'
                          : '$city | $country',
                      style: TextStyles.bodyMain.copyWith(color: Colors.grey),
                    ),
                    const Gap(10),
                    // Tags/Bio placeholder
                    Text(
                      rankTier.isNotEmpty ? rankTier : 'No rank tier yet.',
                      style: TextStyles.bodySecondary.copyWith(
                        color: const Color(
                          0xFF6C9EFF,
                        ), // Blueish tint link color
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(10),

                    ProfileStatsRow(
                      reputationScore: reputationScore,
                      onStatsTap: onOpenStats,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(16),
          // Action Buttons
          isPublicProfile
              ? PublicUserActionButtons(
                  userId: userId,
                  relationshipStatus: relationshipStatus,
                  onFollow: onFollow,
                  onUnfollow: onUnfollow,
                  onUnblock: onUnblock,
                  onMessage: () {}, // TODO: Implement message callback
                )
              : const ProfileActionButtons(),
        ],
      ),
    );
  }
}
