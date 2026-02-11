import 'dart:ui';

import 'package:flutter/material.dart';

class ActionBottomSheet extends StatelessWidget {
  const ActionBottomSheet({
    super.key,
    this.appBar,
    required this.child,
    this.backgroundColor = Colors.white,
    this.isExpanded = false,
    this.enableGlassEffect = true,
    this.enableDropShadow = true,
    this.showDivider = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget child;
  final Color backgroundColor;
  final bool isExpanded;
  final bool enableGlassEffect;
  final bool enableDropShadow;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (showDivider) const ActionBottomSheetDivider(),
        if (appBar != null) appBar!,
        Flexible(child: child),
      ],
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: enableGlassEffect ? 20 : 15,
          sigmaY: enableGlassEffect ? 20 : 15,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor.withOpacity(enableGlassEffect ? 0.4 : 0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(enableGlassEffect ? 0.25 : 0.1),
                width: enableGlassEffect ? 1.5 : 1,
              ),
            ),
            boxShadow: enableDropShadow
                ? [
                    // Верхняя белая тень (glass glow effect)
                    BoxShadow(
                      color: Colors.white.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                      spreadRadius: 0,
                    ),
                    // Основная drop shadow
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 25,
                      offset: const Offset(0, -8),
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: isExpanded ? Expanded(child: content) : content,
        ),
      ),
    );
  }
}

class ActionBottomSheetDivider extends StatelessWidget {
  const ActionBottomSheetDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 38,
      height: 4.5,
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
