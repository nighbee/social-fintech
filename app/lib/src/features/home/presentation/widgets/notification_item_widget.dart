import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/enums/notification_type.dart';
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

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} h ago';
    } else {
      return '${difference.inDays} day ago';
    }
  }

  Widget _buildStatusIcon() {
    switch (notification.notificationType) {
      case NotificationType.like:
        return const Icon(Icons.favorite_border, size: 12, color: Colors.white);
      case NotificationType.comment:
        return Assets.icons.message.svg(width: 12, height: 12);
      case NotificationType.subscriptions:
        return Assets.icons.personFavourites.svg(width: 12, height: 12);
      case NotificationType.help:
        if (notification.type == 'rejected') {
          return Assets.icons.requestClosed.svg(width: 12, height: 12);
        }
        if (notification.type == 'approved') {
          return const Icon(Icons.check, size: 12, color: Colors.white);
        }
        return Assets.icons.silverCoin.svg(width: 12, height: 12);
      case NotificationType.post:
        if (notification.type == 'rejected') {
          return Assets.icons.close.svg(width: 12, height: 12);
        }
        return const Icon(Icons.check, size: 12, color: Colors.white);
      case NotificationType.all:
      case NotificationType.unknown:
        return Assets.icons.message.svg(width: 12, height: 12);
    }
  }

  void _showReasonDialog(BuildContext context) {
    if (notification.ctaValue.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF232324),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
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
                      color: AppColors.colorffffffff,
                    ),
                  ),
                  const Gap(8),
                  Text(
                    notification.ctaValue,
                    style: TextStyles.bodyMain.copyWith(
                      color: AppColors.colorffcacaca,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(32),
                  CustomOutlinedButton(
                    backgroundColor: Colors.transparent,
                    text: "Clear",
                    onTap: () {
                      context.pop();
                    },
                  )
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    context.pop();
                  },
                  child: Assets.icons.close.svg(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAccent = notification.accentText.isNotEmpty;
    final hasRightImage = notification.rightImageUrl.isNotEmpty;
    final showViewButton = notification.ctaLabel.toLowerCase() == 'view';
    final showReasonLink = notification.accentText.toLowerCase() == 'reason';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Assets.images.moonstone.image(
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              bottom: -7,
              right: -7,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF232324),
                  shape: BoxShape.circle,
                ),
                child: _buildStatusIcon(),
              ),
            ),
          ],
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${notification.userName}',
                style: TextStyles.titleTag.copyWith(color: AppColors.colorffcacaca),
              ),
              if (notification.userMeta.isNotEmpty) ...[
                const Gap(2),
                Text(
                  notification.userMeta,
                  style: TextStyles.bodySecondary.copyWith(
                    color: const Color(0xFF819DFF),
                  ),
                ),
              ],
              const Gap(4),
              RichText(
                text: TextSpan(
                  style: TextStyles.bodyLarge.copyWith(
                    color: const Color(0xFF87898F),
                  ),
                  children: [
                    TextSpan(text: notification.message),
                    if (hasAccent) const TextSpan(text: ' '),
                    if (hasAccent)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: GestureDetector(
                          onTap: showReasonLink
                              ? () => _showReasonDialog(context)
                              : null,
                          child: Text(
                            notification.accentText,
                            style: TextStyles.bodyLarge.copyWith(
                              color: showReasonLink
                                  ? AppColors.colorff74afe3
                                  : AppColors.colorffffffff,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                _getTimeAgo(notification.createdAt),
                style: TextStyles.bodyMain.copyWith(
                  color: const Color(0xFF7E8086),
                ),
              ),
            ],
          ),
        ),
        if (showViewButton)
          Container(
            margin: const EdgeInsets.only(left: 12),
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2D31),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                notification.ctaLabel,
                style: TextStyles.bodyMain.copyWith(
                  color: AppColors.colorffffffff,
                ),
              ),
            ),
          )
        else if (hasRightImage)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Assets.images.jade.image(
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
          ),
      ],
    );
  }
}
