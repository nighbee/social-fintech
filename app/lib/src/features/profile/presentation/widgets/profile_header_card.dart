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
    final resolvedBio = bio.trim();

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
                    if (locationParts.isNotEmpty) ...[
                      Text(
                        locationParts.join(' | '),
                        style: TextStyles.bodyMain.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      const Gap(10),
                    ],
                    if (rankTier.trim().isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF6C9EFF),
                              Color(0xFF9B7BFF),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          rankTier,
                          style: TextStyles.bodySecondary.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Gap(10),
                    ],
                    if (resolvedBio.isNotEmpty) ...[
                      Text(
                        resolvedBio,
                        style: TextStyles.bodyMain.copyWith(
                          color: const Color(0xFFD9D9D9),
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(12),
                    ],
                    ProfileStatsRow(goldenSeals: reputationScore),
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
