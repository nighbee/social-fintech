import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:flutter/material.dart';

class CustomOutlinedButton extends StatelessWidget {
  const CustomOutlinedButton({
    super.key,
    required this.text,
    required this.onTap,
    this.width,
    this.textStyle,
    this.padding,
    this.borderRadius = 6,
    this.borderColor,
    this.backgroundColor,
  });

  final String text;
  final VoidCallback onTap;
  final double? width;
  final TextStyle? textStyle;
  final EdgeInsets? padding;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      text: text,
      onTap: onTap,
      width: width,
      backgroundColor: backgroundColor ?? context.theme.mainBackground,
      textStyle:
          textStyle ??
          TextStyles.titleMain.copyWith(
            fontSize: 17,
            color: AppColors.colorffffffff,
          ),
      padding: padding ?? const EdgeInsets.symmetric(vertical: 10),
      borderRadius: borderRadius,
      border: Border.all(color: borderColor ?? AppColors.colorff838383),
    );
  }
}
