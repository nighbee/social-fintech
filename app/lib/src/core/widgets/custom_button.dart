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
    this.icon,
    this.isDisabled = false,
  });

  final String text;
  final VoidCallback onTap;
  final double? width;
  final Color? backgroundColor;
  final TextStyle? textStyle;
  final EdgeInsets? padding;
  final double borderRadius;
  final Border? border;
  final Widget? icon;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = isDisabled
        ? const Color.fromARGB(255, 111, 111, 111)
        : (backgroundColor ?? AppColors.colorffdbdbdb);

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
                    if (icon != null) icon!,
                    Text(text, style: textStyle ?? TextStyles.titleMain),
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
