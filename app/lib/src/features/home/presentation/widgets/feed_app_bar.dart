import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class FeedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FeedAppBar({
    super.key,
    this.onCreatePostTap,
    this.onNotificationsTap,
  });

  final VoidCallback? onCreatePostTap;
  final VoidCallback? onNotificationsTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Assets.icons.silverCoin.svg(width: 24, height: 24),
                const Gap(4),
                Text(
                  '27',
                  style: TextStyles.titleTag.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Assets.icons.timer.svg(width: 24, height: 24),
                const Gap(4),
                Text(
                  '20 min',
                  style: TextStyles.titleHeadline.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: onCreatePostTap,
          child: Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border, width: 1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Assets.icons.plusIcon.svg(width: 24, height: 24),
          ),
        ),
        Gap(14),
        GestureDetector(
          onTap: onNotificationsTap,
          child: Container(
            padding: EdgeInsets.all(6),
            child: Assets.icons.bell.svg(width: 24, height: 24),
          ),
        ),
        Gap(7),
        GestureDetector(
          onTap: () {},
          child: Container(
            padding: EdgeInsets.all(6),
            child: Assets.icons.search.svg(width: 24, height: 24),
          ),
        ),
      ],
    );
  }
}
