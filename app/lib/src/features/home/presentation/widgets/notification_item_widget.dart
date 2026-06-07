import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_outlined_button.dart';
import 'package:app/src/features/home/domain/entities/notification_entity.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class NotificationItemWidget extends StatelessWidget {
  const NotificationItemWidget({
    required this.notification,
    super.key,
  });

  final NotificationEntity notification;

  @override
  Widget build(BuildContext context) {
    final isGrouped = notification.groupCount > 1;
    final showAsCard =
        notification.isImportant || notification.badgeStatus.isNotEmpty;
    final content = isGrouped
        ? _GroupedNotificationContent(notification: notification)
        : _NotificationContent(notification: notification);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleTap(context),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            showAsCard ? 14 : 4,
            showAsCard ? 12 : 8,
            showAsCard ? 14 : 4,
            showAsCard ? 12 : 8,
          ),
          decoration: showAsCard
              ? BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.34),
                  ),
                )
              : null,
          child: content,
        ),
      ),
    );
  }

  Color get _cardColor {
    final badge = notification.badgeStatus.toUpperCase();
    if (badge == 'MEDAL_UNLOCKED') {
      return const Color(0xFF352F29).withValues(alpha: 0.72);
    }
    if (badge == 'ACCEPTED' || badge == 'COMPLETED') {
      return const Color(0xFF253128).withValues(alpha: 0.68);
    }
    return Colors.white.withValues(alpha: 0.035);
  }

  void _handleTap(BuildContext context) {
    if (notification.accentText.toLowerCase() == 'reason' &&
        notification.ctaValue.isNotEmpty) {
      _showReasonDialog(context);
      return;
    }

    final link = notification.deepLink.trim();
    if (link.isEmpty) return;

    final uri = Uri.tryParse(link);
    if (uri == null || uri.scheme != 'app') return;
    final segments = <String>[
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments,
    ];
    if (segments.isEmpty) return;

    switch (segments.first) {
      case 'chat':
        if (segments.length > 1) {
          context.pushNamed(
            RouteNames.chatConversation,
            pathParameters: <String, String>{'chatId': segments[1]},
          );
        }
      case 'leaderboard':
        context.go(RoutePaths.rating);
      case 'profile':
        if (segments.contains('medals')) {
          context.pushNamed(
            RouteNames.profileStats,
            extra: const <String, dynamic>{'isCurrentUser': true},
          );
        } else {
          context.go(RoutePaths.profile);
        }
      case 'tasks':
        context.go(RoutePaths.map);
      case 'post':
        // There is no dedicated post-details route yet.
        return;
    }
  }

  void _showReasonDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.colorff232324,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Assets.images.image.image(width: 72, height: 72),
                  const Gap(14),
                  Text(
                    'Reason for refusal',
                    style: TextStyles.titleBig.copyWith(
                      color: AppColors.textBrand,
                    ),
                  ),
                  const Gap(8),
                  Text(
                    notification.ctaValue,
                    style: TextStyles.bodyMain.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(28),
                  CustomOutlinedButton(
                    backgroundColor: Colors.transparent,
                    text: 'Close',
                    onTap: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textBrand,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationContent extends StatelessWidget {
  const _NotificationContent({required this.notification});

  final NotificationEntity notification;

  @override
  Widget build(BuildContext context) {
    final presenter = _NotificationPresenter(notification);
    final hasRightImage = notification.rightImageUrl.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NotificationAvatar(
          imageUrl: notification.userAvatarUrl,
          kind: notification.kind,
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: presenter.header.isEmpty
                        ? const SizedBox.shrink()
                        : Text(
                            presenter.header,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyles.titleTag.copyWith(
                              color: AppColors.textBrand,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const Gap(8),
                  Text(
                    presenter.timeAgo,
                    style: TextStyles.bodyMain.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (notification.userMeta.isNotEmpty) ...[
                const Gap(2),
                Text(
                  notification.userMeta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyles.bodySecondary.copyWith(
                    color: const Color(0xFF74AFE3),
                    fontSize: 12,
                  ),
                ),
              ],
              if (presenter.action.isNotEmpty) ...[
                const Gap(5),
                Text(
                  presenter.action,
                  style: TextStyles.bodyMain.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ],
              if (presenter.detail.isNotEmpty) ...[
                const Gap(5),
                Text(
                  presenter.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyles.bodyLarge.copyWith(
                    color: const Color(0xFF8A8C92),
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ],
              if (presenter.badgeLabel.isNotEmpty) ...[
                const Gap(8),
                _NotificationBadge(
                  label: presenter.badgeLabel,
                  badgeStatus: notification.badgeStatus,
                  kind: notification.kind,
                ),
              ],
            ],
          ),
        ),
        if (hasRightImage) ...[
          const Gap(10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.network(
              notification.rightImageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Assets.images.jade.image(
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GroupedNotificationContent extends StatelessWidget {
  const _GroupedNotificationContent({required this.notification});

  final NotificationEntity notification;

  @override
  Widget build(BuildContext context) {
    final presenter = _NotificationPresenter(notification);
    final avatarCount = notification.groupCount.clamp(2, 3);

    return Row(
      children: [
        SizedBox(
          width: 36 + ((avatarCount - 1) * 18),
          height: 38,
          child: Stack(
            children: [
              for (var index = 0; index < avatarCount; index++)
                Positioned(
                  left: index * 18,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.mainBackground,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: _fallbackImageForIndex(index).image(
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Gap(12),
        Expanded(
          child: Text(
            presenter.groupedMessage,
            style: TextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        const Gap(8),
        Text(
          presenter.timeAgo,
          style: TextStyles.bodyMain.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  AssetGenImage _fallbackImageForIndex(int index) {
    return switch (index) {
      0 => Assets.images.jade,
      1 => Assets.images.moonstone,
      _ => Assets.images.pearl,
    };
  }
}

class _NotificationAvatar extends StatelessWidget {
  const _NotificationAvatar({
    required this.imageUrl,
    required this.kind,
  });

  final String imageUrl;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final fallback = _fallbackAsset;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: imageUrl.isEmpty
          ? fallback.image(width: 52, height: 52, fit: BoxFit.cover)
          : Image.network(
              imageUrl,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  fallback.image(width: 52, height: 52, fit: BoxFit.cover),
            ),
    );
  }

  AssetGenImage get _fallbackAsset {
    if (kind == 'medal_issued' || kind.startsWith('rank_')) {
      return Assets.images.ammolite;
    }
    if (kind.startsWith('task_') ||
        kind == 'proof_submitted' ||
        kind == 'verification_required' ||
        kind == 'reward_delivered') {
      return Assets.images.pearl;
    }
    return Assets.images.moonstone;
  }
}

class _NotificationBadge extends StatelessWidget {
  const _NotificationBadge({
    required this.label,
    required this.badgeStatus,
    required this.kind,
  });

  final String label;
  final String badgeStatus;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final isRank = kind.contains('rank') || kind.contains('leader');
    final isComplete = badgeStatus.toUpperCase() == 'ACCEPTED' ||
        badgeStatus.toUpperCase() == 'COMPLETED';
    final color = isRank
        ? const Color(0xFF819DFF)
        : isComplete
            ? const Color(0xFFCACACA)
            : const Color(0xFFE5C367);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRank
                ? Icons.bolt_rounded
                : isComplete
                    ? Icons.check_rounded
                    : Icons.circle,
            size: 13,
            color: color,
          ),
          const Gap(5),
          Text(
            label,
            style: TextStyles.bodyMain.copyWith(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationPresenter {
  const _NotificationPresenter(this.notification);

  final NotificationEntity notification;

  String get header {
    if (notification.userName.isNotEmpty) {
      return '@${notification.userName}';
    }

    final title = notification.title.trim();
    const suffixes = <String>[
      ' liked your post',
      ' commented on your post',
      ' replied to your comment',
      ' recognized your post',
      ' sent you silver',
      ' applied to your task',
    ];
    for (final suffix in suffixes) {
      if (title.endsWith(suffix)) {
        return '@${title.substring(0, title.length - suffix.length)}';
      }
    }
    return '';
  }

  String get action {
    switch (notification.kind) {
      case 'post_liked':
        return 'liked your post.';
      case 'post_commented':
        return 'commented on your post.';
      case 'post_replied':
        return 'replied to your comment.';
      case 'seal_received':
        return 'recognized your post.';
      case 'silver_received':
        return 'sent you silver.';
      case 'medal_issued':
        return notification.title;
      default:
        if (header.isEmpty) return notification.title;
        return _titleWithoutHeader;
    }
  }

  String get detail {
    final body = notification.body.trim();
    if (body.isEmpty || body == action) return '';
    if (notification.kind == 'post_commented' ||
        notification.kind == 'post_replied') {
      return '“$body”';
    }
    return body;
  }

  String get badgeLabel {
    final status = notification.badgeStatus.toUpperCase();
    if (status == 'MEDAL_UNLOCKED') return 'Medal unlocked';
    if (status == 'AREA_LEADER') return 'Area leader';
    if (status == 'ACCEPTED') return 'Completed';
    if (status == 'UNDER_REVIEW') return 'Under review';
    if (status == 'REJECTED') return 'Rejected';
    if (notification.kind == 'rank_advanced') return 'Rank advanced';
    if (notification.kind == 'task_completed' ||
        notification.kind == 'reward_delivered') {
      return 'Completed';
    }
    return '';
  }

  String get groupedMessage {
    final count = notification.groupCount;
    switch (notification.kind) {
      case 'post_liked':
      case 'seal_received':
        return '$count people reacted to your post.';
      case 'post_commented':
      case 'post_replied':
        return '$count people joined the conversation.';
      default:
        return '$count people interacted with you.';
    }
  }

  String get timeAgo {
    final difference = DateTime.now().difference(notification.createdAt);
    if (difference.inMinutes < 1) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} m';
    if (difference.inHours < 24) return '${difference.inHours} h';
    return '${difference.inDays} d';
  }

  String get _titleWithoutHeader {
    final value = notification.title.trim();
    final visibleHeader = header.replaceFirst('@', '');
    if (visibleHeader.isEmpty || !value.startsWith(visibleHeader)) return value;
    return value.substring(visibleHeader.length).trim();
  }
}
