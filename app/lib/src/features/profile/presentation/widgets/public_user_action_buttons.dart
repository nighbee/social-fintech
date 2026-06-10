import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/profile/domain/entities/relationship_status_entity.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Matches [ProfileActionButtons] pill metrics; "Add to favorites" (not following) stays white per Figma.
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

  static const Color _primaryBtnFill = Color.fromRGBO(109, 109, 109, 0.35);
  static const Color _primaryBtnBorder = Color.fromRGBO(101, 101, 101, 0.25);
  static const double _pillHeight = 30;
  static const double _radius = 6;

  static TextStyle _pillTextStyle(Color color) {
    return TextStyles.titleTag.copyWith(
      color: color,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 14 / 12,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBlocked = relationshipStatus?.iBlockedThem ?? false;
    final wasBlockedByUser = relationshipStatus?.theyBlockedMe ?? false;

    if (wasBlockedByUser) {
      return const _UnavailableButton();
    }

    if (isBlocked) {
      return _UnblockButton(onUnblock: onUnblock);
    }

    return _NormalButtons(
      relationshipStatus: relationshipStatus,
      onFollow: onFollow,
      onUnfollow: onUnfollow,
      onMessage: onMessage,
    );
  }
}

class _UnavailableButton extends StatelessWidget {
  const _UnavailableButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: PublicUserActionButtons._pillHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF303030),
        borderRadius: BorderRadius.circular(PublicUserActionButtons._radius),
        border: Border.all(
          color: PublicUserActionButtons._primaryBtnBorder,
          width: 0.8,
        ),
      ),
      child: Text(
        'Profile unavailable',
        style: PublicUserActionButtons._pillTextStyle(
          const Color(0xFF838383),
        ),
      ),
    );
  }
}

class _UnblockButton extends StatelessWidget {
  const _UnblockButton({this.onUnblock});

  final VoidCallback? onUnblock;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onUnblock,
      child: Container(
        width: double.infinity,
        height: PublicUserActionButtons._pillHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(PublicUserActionButtons._radius),
          border: Border.all(
            color: PublicUserActionButtons._primaryBtnBorder,
            width: 0.8,
          ),
        ),
        child: Text(
          'Unblock',
          style: PublicUserActionButtons._pillTextStyle(
            const Color(0xFF191919),
          ).copyWith(fontWeight: FontWeight.w600),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
              height: PublicUserActionButtons._pillHeight,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isFollowing
                    ? PublicUserActionButtons._primaryBtnFill
                    : Colors.white,
                borderRadius:
                    BorderRadius.circular(PublicUserActionButtons._radius),
                border: Border.all(
                  color: PublicUserActionButtons._primaryBtnBorder,
                  width: 0.8,
                ),
              ),
              child: Text(
                isFollowing ? 'Added to favorites' : 'Add to favorites',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: PublicUserActionButtons._pillTextStyle(
                  isFollowing
                      ? const Color(0xFFCACACA)
                      : const Color(0xFF191919),
                ),
              ),
            ),
          ),
        ),
        const Gap(6),
        Expanded(
          child: GestureDetector(
            onTap: onMessage,
            child: Container(
              height: PublicUserActionButtons._pillHeight,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isRestricted
                    ? const Color(0xFFFF3B30).withValues(alpha: 0.2)
                    : PublicUserActionButtons._primaryBtnFill,
                borderRadius:
                    BorderRadius.circular(PublicUserActionButtons._radius),
                border: Border.all(
                  color: isRestricted
                      ? const Color(0xFFFF3B30)
                      : PublicUserActionButtons._primaryBtnBorder,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isRestricted) ...[
                    const Icon(
                      Icons.block,
                      size: 14,
                      color: Color(0xFFFF3B30),
                    ),
                    const Gap(4),
                  ],
                  Flexible(
                    child: Text(
                      'Message',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: PublicUserActionButtons._pillTextStyle(
                        isRestricted
                            ? const Color(0xFFFF3B30)
                            : const Color(0xFFCACACA),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
