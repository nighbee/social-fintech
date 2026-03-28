import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.text,
    required this.onTap,
    this.width,
    this.backgroundColor,
    this.textStyle,
    this.padding,
    this.borderRadius = 6,
    this.border,
    this.prefixIcon,
    this.suffixIcon,
    this.isDisabled = false,
    this.disabledBackgroundColor,
    this.disabledTextStyle,
  });

  final String text;
  final VoidCallback onTap;
  final double? width;
  final Color? backgroundColor;
  final TextStyle? textStyle;
  /// When [isDisabled] is true, overrides default gray disabled colors.
  final Color? disabledBackgroundColor;
  final TextStyle? disabledTextStyle;
  final EdgeInsets? padding;
  final double borderRadius;
  final Border? border;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = isDisabled
        ? (disabledBackgroundColor ?? AppColors.backgroundDisabledDefault)
        : (backgroundColor ?? AppColors.backgroundBrandLight);

    final effectiveTextStyle = isDisabled
        ? (disabledTextStyle ??
            TextStyles.titleMain.copyWith(
              color: AppColors.textDisabledDefault,
            ))
        : (textStyle ??
            TextStyles.titleMain.copyWith(color: AppColors.textNeutral));

    return Container(
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isDisabled ? null : onTap,
            child: Padding(
              padding: padding ?? const EdgeInsets.symmetric(vertical: 15),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 10,
                  children: [
                    if (prefixIcon != null) prefixIcon!,
                    Text(
                      text,
                      style: effectiveTextStyle,
                    ),
                    if (suffixIcon != null) suffixIcon!,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
