import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/silver_balance_chip.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

enum FeedTimerTone { normal, breakTime, warning }

class FeedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FeedAppBar({
    super.key,
    this.onCreatePostTap,
    this.onNotificationsTap,
    this.onSearchTap,
    this.onTimerTap,
    this.silverCount = 0,
    this.timerLabel = '20 min',
    this.timerTone = FeedTimerTone.normal,
  });

  final VoidCallback? onCreatePostTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onTimerTap;
  final int silverCount;
  final String timerLabel;
  final FeedTimerTone timerTone;

  LinearGradient _timerGradient() {
    switch (timerTone) {
      case FeedTimerTone.breakTime:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.2057, 0.6084, 1.0],
          colors: [
            Color(0xFFCEAC89),
            Color(0xFFB4814A),
            Color(0xFF72410A),
          ],
          transform: GradientRotation(185.95 * 3.1415926535 / 180),
        );
      case FeedTimerTone.warning:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.2975, 0.7728, 1.0],
          colors: [
            Color(0xFFFFE3C8),
            Color(0xFFB18D67),
            Color(0xFFD6A673),
          ],
          transform: GradientRotation(173.28 * 3.1415926535 / 180),
        );
      case FeedTimerTone.normal:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9E0D2), Color(0xFFB8A48A)],
        );
    }
  }

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
          SilverBalanceChip(count: silverCount),
          const Gap(12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTimerTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        _timerGradient().createShader(bounds),
                    blendMode: BlendMode.srcIn,
                    child: Assets.icons.timer.svg(width: 24, height: 24),
                  ),
                  const Gap(4),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        _timerGradient().createShader(bounds),
                    blendMode: BlendMode.srcIn,
                    child: Text(
                      timerLabel,
                      style: TextStyles.titleHeadline.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
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
          onTap: onSearchTap,
          child: Container(
            padding: EdgeInsets.all(6),
            child: Assets.icons.search.svg(width: 24, height: 24),
          ),
        ),
      ],
    );
  }
}
