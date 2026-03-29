import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_outlined_button.dart';
import 'package:app/src/core/widgets/glass_container.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

Future<T?> showStyledMessageDialog<T>({
  required BuildContext context,
  String? title,
  String? message,
  Widget? content,
  String actionText = 'Ok',
  VoidCallback? onActionTap,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  assert(title != null || message != null || content != null);

  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    builder: (dialogContext) {
      return StyledMessageDialog(
        title: title,
        message: message,
        content: content,
        actionText: actionText,
        onActionTap: onActionTap ?? () => Navigator.of(dialogContext).pop(),
      );
    },
  );
}

class StyledMessageDialog extends StatelessWidget {
  const StyledMessageDialog({
    super.key,
    this.title,
    this.message,
    this.content,
    this.actionText = 'Ok',
    this.onActionTap,
  }) : assert(title != null || message != null || content != null);

  final String? title;
  final String? message;
  final Widget? content;
  final String actionText;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: GlassContainer(
        borderRadius: 12,
        blurSigma: 24,
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
        backgroundColor: AppColors.colorff202020.withValues(alpha: 0.88),
        borderColor: Colors.white.withValues(alpha: 0.04),
        borderWidth: 1,
        enableWhiteGlow: false,
        dropShadowColor: Colors.black.withValues(alpha: 0.48),
        dropShadowBlurRadius: 32,
        dropShadowOffset: const Offset(0, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Text(
                title!,
                textAlign: TextAlign.center,
                style: TextStyles.titleMain.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                  color: AppColors.textBrand,
                ),
              ),
            if (title != null && (message != null || content != null))
              const Gap(12),
            if (message != null)
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: AppColors.textBrand,
                ),
              ),
            if (content != null) content!,
            const Gap(20),
            CustomOutlinedButton(
              text: actionText,
              onTap: onActionTap ?? () => Navigator.of(context).pop(),
              width: double.infinity,
              borderRadius: 12,
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
  }
}
