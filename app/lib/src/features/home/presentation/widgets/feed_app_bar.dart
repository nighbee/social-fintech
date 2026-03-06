import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class FeedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FeedAppBar({
    super.key,
    this.onCreatePostTap,
  });

  final VoidCallback? onCreatePostTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.colorff19191A,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.colorff2A2A2B,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.colorff3F3F40, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Assets.icons.silverCoin.svg(width: 24, height: 24),
                const Gap(4),
                Text(
                  '27',
                  style: TextStyles.titleTag.copyWith(
                    color: AppColors.colorffE5E5E5,
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
                    color: AppColors.colorffE5E5E5,
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
              color: AppColors.colorff2A2A2B,
              border: Border.all(color: AppColors.colorff3F3F40, width: 1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Assets.icons.plusIcon.svg(width: 24, height: 24),
          ),
        ),
        const Gap(14),
        GestureDetector(
          onTap: () {
            context.push(RoutePaths.notifications);
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            child: Assets.icons.bell.svg(width: 24, height: 24),
          ),
        ),
        const Gap(7),
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
