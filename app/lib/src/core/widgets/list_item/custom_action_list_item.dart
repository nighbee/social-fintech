import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';

class CustomActionListItem extends StatelessWidget {
  const CustomActionListItem({
    super.key,
    required this.text,
    this.onTap,
    this.prefixIcon,
    this.color,
    this.hasRightArrow = true,
    this.verticalPadding = 12,
  });

  final String text;
  final VoidCallback? onTap;
  final Widget? prefixIcon;
  final Color? color;
  final bool hasRightArrow;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? AppColors.colorffffffff;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        child: Row(
          children: [
            if (prefixIcon != null) ...[
              IconTheme(
                data: IconThemeData(color: resolvedColor),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: resolvedColor),
                  child: prefixIcon!,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                text,
                style: TextStyles.bodyLarge.copyWith(color: resolvedColor),
              ),
            ),
            if (hasRightArrow)
              Assets.icons.tuiIconChevronRightLarge.svg(
                width: 24,
                height: 24,
                color: const Color(0xFF8E8E93),
              ),
          ],
        ),
      ),
    );
  }
}
