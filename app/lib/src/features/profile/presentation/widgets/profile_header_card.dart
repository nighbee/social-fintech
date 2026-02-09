import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/features/profile/domain/entities/profile_entity.dart';
import 'package:app/src/features/profile/presentation/widgets/profile_action_buttons.dart';
import 'package:app/src/features/profile/presentation/widgets/public_user_action_buttons.dart';
import 'package:app/src/features/profile/presentation/widgets/profile_stats_row.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    required this.profile,
    this.isPublicProfile = false,
    super.key,
  });

  final ProfileEntity profile;
  final bool isPublicProfile;

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
                imageUrl: profile.avatarUrl.isNotEmpty
                    ? profile.avatarUrl
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
                      profile.displayName.isNotEmpty
                          ? profile.displayName
                          : '@${profile.userId}', // Fallback to ID/Username
                      style: TextStyles.titleHeadline.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const Gap(10),
                    Text(
                      '${profile.city} | ${profile.country}',
                      style: TextStyles.bodyMain.copyWith(color: Colors.grey),
                    ),
                    const Gap(10),
                    // Tags/Bio placeholder
                    Text(
                      profile.rankTier.isNotEmpty
                          ? profile.rankTier
                          : 'No rank tier yet.',
                      style: TextStyles.bodySecondary.copyWith(
                        color: const Color(
                          0xFF6C9EFF,
                        ), // Blueish tint link color
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(10),

                    ProfileStatsRow(reputationScore: profile.reputationScore),
                  ],
                ),
              ),
            ],
          ),
          const Gap(16),
          // Action Buttons
          isPublicProfile
              ? const PublicUserActionButtons()
              : const ProfileActionButtons(),
        ],
      ),
    );
  }
}
