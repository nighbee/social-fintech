import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/home/domain/entities/feed_state_entity.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class FeedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FeedAppBar({
    super.key,
    this.onCreatePostTap,
    this.feedState = const FeedStateEntity.empty(),
  });

  final VoidCallback? onCreatePostTap;
  final FeedStateEntity feedState;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final maxAllowedSeconds = feedState.maxAllowedSeconds > 0
        ? feedState.maxAllowedSeconds
        : 20 * 60;
    final remainingSeconds =
        (maxAllowedSeconds - feedState.accumulatedActiveSeconds).clamp(
      0,
      maxAllowedSeconds,
    );
    final remainingMinutes = (remainingSeconds / 60).ceil();
    final isBreak = feedState.isInCooldown;
    final isTimeEnding = !isBreak && remainingSeconds <= 60;
    final breakRemainingSeconds =
        (maxAllowedSeconds - feedState.accumulatedActiveSeconds).clamp(
      0,
      maxAllowedSeconds,
    );
    final breakRemainingMinutes = (breakRemainingSeconds / 60).ceil();
    final timerLabel = isBreak
        ? '${breakRemainingMinutes <= 0 ? 1 : breakRemainingMinutes} min break'
        : '${remainingMinutes <= 0 ? 1 : remainingMinutes} min';

    final endingGradient = const LinearGradient(
      colors: [
        Color(0xFFFFE3C8),
        Color(0xFFB18D67),
        Color(0xFFD6A673),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final breakGradient = const LinearGradient(
      colors: [
        Color(0xFFCEAC89),
        Color(0xFFB4814A),
        Color(0xFF72410A),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

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
            child: (isTimeEnding || isBreak)
                ? ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) {
                      final gradient =
                          isBreak ? breakGradient : endingGradient;
                      return gradient.createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Assets.icons.timer.svg(
                          width: 24,
                          height: 24,
                          color: Colors.white,
                        ),
                        const Gap(4),
                        Text(
                          timerLabel,
                          style: TextStyles.titleHeadline.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Assets.icons.timer.svg(width: 24, height: 24),
                      const Gap(4),
                      Text(
                        timerLabel,
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
