import 'package:flutter/material.dart';
import 'package:app/src/core/theme/theme.dart';

class CustomListItem extends StatelessWidget {
  const CustomListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.isSecondary = false,
    this.isStroke = false,
    this.iconLeft = false,
    this.iconRight = false,
    this.onTap,
    this.widgetLeft,
    this.widgetRight,
    this.backgroundColor,
    this.color,
    this.maxlines,
  });

  final String title;
  final String? subtitle;
  final bool isSecondary;
  final bool isStroke;
  final bool iconLeft;
  final bool iconRight;
  final VoidCallback? onTap;
  final Widget? widgetLeft;
  final Widget? widgetRight;
  final Color? backgroundColor;
  final Color? color;
  final int? maxlines;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.transparent,
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 8,
            ), // Adjusted padding
            child: Row(
              children: [
                if (iconLeft) ...[
                  widgetLeft ?? const Icon(Icons.keyboard_arrow_down),
                  const SizedBox(width: 15),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: isSecondary
                            ? TextStyles
                                  .titleMain // Adopting brightbund styles
                                  .copyWith(
                                    color: color ?? Colors.black,
                                    fontSize: 16,
                                  )
                            : TextStyles.titleMain.copyWith(
                                color: color ?? Colors.black,
                              ),
                        maxLines: maxlines ?? 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle!,
                          style: TextStyles.bodyMain.copyWith(
                            color: color ?? Colors.black54,
                            fontSize: 14,
                          ),
                          maxLines: maxlines ?? 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (iconRight || widgetRight != null) ...[
                  const SizedBox(width: 15),
                  widgetRight ??
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                ],
              ],
            ),
          ),
          if (isStroke)
            Container(
              width: double.infinity,
              height: 1,
              color: Colors.grey.withOpacity(
                0.2,
              ), // AppColors.stroke50 equivalent
            ),
        ],
      ),
    );
  }
}
