import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/profile/domain/entities/relationship_status_entity.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class PublicUserActionButtons extends StatelessWidget {
  const PublicUserActionButtons({
    super.key,
    required this.userId,
    this.relationshipStatus,
    this.onFollow,
    this.onUnfollow,
    this.onUnblock,
    this.onMessage,
  });

  final String userId;
  final RelationshipStatusEntity? relationshipStatus;
  final VoidCallback? onFollow;
  final VoidCallback? onUnfollow;
  final VoidCallback? onUnblock;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final isBlocked = relationshipStatus?.iBlockedThem ?? false;

    // Priority 1: If user is blocked, show ONLY unblock button
    if (isBlocked) {
      return _UnblockButton(onUnblock: onUnblock);
    }

    // Priority 2: Normal state - show follow + message buttons
    return _NormalButtons(
      relationshipStatus: relationshipStatus,
      onFollow: onFollow,
      onUnfollow: onUnfollow,
      onMessage: onMessage,
    );
  }
}

class _UnblockButton extends StatelessWidget {
  const _UnblockButton({this.onUnblock});

  final VoidCallback? onUnblock;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: ElevatedButton(
        onPressed: onUnblock,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6D6D6D).withOpacity(0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFF656565)),
          ),
        ),
        child: Text(
          'Unblock',
          style: TextStyles.titleTag.copyWith(color: const Color(0xFFCACACA)),
        ),
      ),
    );
  }
}

class _NormalButtons extends StatelessWidget {
  const _NormalButtons({
    required this.relationshipStatus,
    this.onFollow,
    this.onUnfollow,
    this.onMessage,
  });

  final RelationshipStatusEntity? relationshipStatus;
  final VoidCallback? onFollow;
  final VoidCallback? onUnfollow;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final isFollowing = relationshipStatus?.iFollowThem ?? false;
    final isRestricted = relationshipStatus?.iRestrictedThem ?? false;

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (isFollowing) {
                  onUnfollow?.call();
                } else {
                  onFollow?.call();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D6D6D).withOpacity(0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF656565)),
                ),
                child: Center(
                  child: Text(
                    isFollowing ? 'Added to favorites' : 'Add to favorites',
                    style: TextStyles.titleTag.copyWith(
                      color: const Color(0xFFCACACA),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Gap(12),
          Expanded(
            child: GestureDetector(
              onTap: onMessage,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isRestricted
                      ? const Color(0xFFFF3B30).withOpacity(0.2)
                      : const Color(0xFF6D6D6D).withOpacity(0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isRestricted
                        ? const Color(0xFFFF3B30)
                        : const Color(0xFF656565),
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isRestricted) ...[
                        const Icon(
                          Icons.block,
                          size: 16,
                          color: Color(0xFFFF3B30),
                        ),
                        const Gap(4),
                      ],
                      Text(
                        'Message',
                        style: TextStyles.titleTag.copyWith(
                          color: isRestricted
                              ? const Color(0xFFFF3B30)
                              : const Color(0xFFCACACA),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
