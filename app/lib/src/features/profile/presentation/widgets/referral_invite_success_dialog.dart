import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_outlined_button.dart';
import 'package:app/src/core/widgets/glass_container.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

Future<void> showReferralInviteActivatedDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: GlassContainer(
          borderRadius: 14,
          blurSigma: 28,
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
          backgroundColor: AppColors.colorff202020.withValues(alpha: 0.92),
          borderColor: Colors.white.withValues(alpha: 0.06),
          borderWidth: 1,
          enableWhiteGlow: false,
          dropShadowColor: Colors.black.withValues(alpha: 0.5),
          dropShadowBlurRadius: 40,
          dropShadowOffset: const Offset(0, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  Assets.images.goldenHonor.image(
                    width: 64,
                    height: 64,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
              const Gap(20),
              Text(
                'Invite activated',
                textAlign: TextAlign.center,
                style: TextStyles.titleMain.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                  color: AppColors.textBrand,
                ),
              ),
              const Gap(10),
              Text(
                'Golden Honor credited.',
                textAlign: TextAlign.center,
                style: TextStyles.bodyLarge.copyWith(
                  fontSize: 15,
                  height: 1.3,
                  color: const Color(0xFFB0B0B0),
                ),
              ),
              const Gap(24),
              CustomOutlinedButton(
                text: 'Ok',
                onTap: () => Navigator.of(dialogContext).pop(),
                width: double.infinity,
                borderRadius: 10,
                borderColor: AppColors.textBrand,
                backgroundColor: Colors.transparent,
                textStyle: TextStyles.titleMain.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                  color: AppColors.textBrand,
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ],
          ),
        ),
      );
    },
  );
}
