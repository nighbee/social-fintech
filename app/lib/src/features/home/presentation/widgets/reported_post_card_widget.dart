import 'dart:ui';

import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ReportedPostCardWidget extends StatelessWidget {
  const ReportedPostCardWidget({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF202020).withValues(alpha: 0.26),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Assets.icons.close.svg(
                      width: 12,
                      height: 12,
                      color: AppColors.colorffcacaca,
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Assets.icons.checkedCircle.svg(
                    width: 24,
                    height: 24,
                    color: AppColors.colorffffffff,
                  ),
                  const Gap(10),
                  Text(
                    'Thanks for reporting this post',
                    style: TextStyles.bodyMain.copyWith(
                      color: AppColors.colorffffffff,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(10),
                  Text(
                    'Your feedback is important in helping us keep the BrightBud community safe.',
                    style: TextStyles.bodyMain.copyWith(
                      color: AppColors.colorff838383,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
