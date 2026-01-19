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
  });

  final String text;
  final VoidCallback onTap;
  final double? width;
  final TextStyle? textStyle;
  final EdgeInsets? padding;
  final double borderRadius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      text: text,
      onTap: onTap,
      width: width,
      backgroundColor: Colors.transparent,
      textStyle:
          textStyle ??
          context.theme.textStyles.bodyMediumBold.copyWith(
            fontSize: 17,
            color: AppColors.whiteBackground,
          ),
      padding: padding ?? const EdgeInsets.symmetric(vertical: 10),
      borderRadius: borderRadius,
      border: Border.all(color: borderColor ?? AppColors.textGray2),
    );
  }
}
