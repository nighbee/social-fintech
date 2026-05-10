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
    required this.firstName,
    required this.lastName,
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
  final String firstName;
  final String lastName;
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
    final normalizedDisplayName = displayName.trim();
    final normalizedFirstName = firstName.trim();
    final normalizedLastName = lastName.trim();
    final normalizedUserId = userId.trim();
    final fullName = [normalizedFirstName, normalizedLastName]
        .where((item) => item.isNotEmpty)
        .join(' ');
    final bestName = normalizedDisplayName.isNotEmpty
        ? normalizedDisplayName
        : (fullName.isNotEmpty ? fullName : normalizedUserId);
    final title = bestName.isEmpty
        ? '@unknown'
        : (bestName.startsWith('@') ? bestName : '@$bestName');
    final rankText =
        rankTier.trim().isNotEmpty ? rankTier : 'Moonstone · Intention · A';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
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
          color: Colors.white.withValues(alpha: 0.16),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 320;
              final avatarSize = isCompact ? 108.0 : 125.0;
              final horizontalGap = isCompact ? 10.0 : 16.0;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  avatarUrl.trim().isNotEmpty
                      ? CustomNetworkImage(
                          imageUrl: avatarUrl,
                          width: avatarSize,
                          height: avatarSize,
                          borderRadius: BorderRadius.circular(8),
                          errorIcon: Icons.person_outline,
                          errorIconSize: 36,
                        )
                      : Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            color: AppColors.colorff2A2A2B,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.28),
                                blurRadius: 4,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: const Alignment(0.12, 0.2),
                          child: const Icon(
                            Icons.person_outline,
                            size: 36,
                            color: AppColors.colorff9CA3AF,
                          ),
                        ),
                  Gap(horizontalGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyles.titleHeadline.copyWith(
                            fontFamily: 'CanelaDeckTrial',
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFFCACACA),
                            fontSize: 18,
                            height: 16 / 18,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Gap(6),
                        ProfileRankMetaLine(rankTier: rankText),
                        const Gap(4),
                        ProfileExpandableBio(text: bio),
                        const Gap(8),
                        ProfileStatsRow(
                          goldenSeals: reputationScore,
                          statsLabel:
                              isPublicProfile ? 'User Stats' : 'Your Stats',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
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
