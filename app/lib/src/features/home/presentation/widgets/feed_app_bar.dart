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
    this.onSilverTap,
    this.silverCount = 0,
    this.timerLabel = '20 min',
    this.timerTone = FeedTimerTone.normal,
  });

  final VoidCallback? onCreatePostTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onTimerTap;
  final VoidCallback? onSilverTap;
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
      titleSpacing: 12,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onSilverTap,
                    child: SilverBalanceChip(count: silverCount),
                  ),
                  const Gap(12),
                  Flexible(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTimerTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  _timerGradient().createShader(bounds),
                              blendMode: BlendMode.srcIn,
                              child:
                                  Assets.icons.timer.svg(width: 24, height: 24),
                            ),
                            const Gap(6),
                            Flexible(
                              child: ShaderMask(
                                shaderCallback: (bounds) =>
                                    _timerGradient().createShader(bounds),
                                blendMode: BlendMode.srcIn,
                                child: Text(
                                  timerLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                  style: TextStyles.titleHeadline.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(8),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onCreatePostTap,
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0x405F5F5F),
                        Color(0x33535252),
                        Color(0x262A2A2B),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF5F5F5F),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Assets.icons.plusIcon.svg(width: 24, height: 24),
                ),
              ),
              const Gap(8),
              _FeedHeaderIconButton(
                onTap: onNotificationsTap,
                icon: Assets.icons.bell.svg(width: 24, height: 24),
              ),
              const Gap(4),
              _FeedHeaderIconButton(
                onTap: onSearchTap,
                icon: Assets.icons.search.svg(width: 24, height: 24),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedHeaderIconButton extends StatelessWidget {
  const _FeedHeaderIconButton({
    required this.onTap,
    required this.icon,
  });

  final VoidCallback? onTap;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: icon,
        ),
      ),
    );
  }
}
