import 'dart:ui';

import 'package:flutter/material.dart';

class ActionBottomSheet extends StatelessWidget {
  const ActionBottomSheet({
    super.key,
    this.appBar,
    required this.child,
    this.backgroundColor = Colors.white,
    this.backgroundOpacity,
    this.isExpanded = false,
    this.enableGlassEffect = true,
    this.enableDropShadow = true,
    this.showDivider = true,
    /// Stronger blur for frosted glass (e.g. profile actions). Defaults match [enableGlassEffect].
    this.glassBlurSigma,
    /// Figma-style soft shadow (Y: 4, blur: 4, black 25%). Implies [enableDropShadow].
    this.subtleBottomShadow = false,
  });

  final PreferredSizeWidget? appBar;
  final Widget child;
  final Color backgroundColor;
  final double? backgroundOpacity;
  final bool isExpanded;
  final bool enableGlassEffect;
  final bool enableDropShadow;
  final bool showDivider;
  final double? glassBlurSigma;
  final bool subtleBottomShadow;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (showDivider) const ActionBottomSheetDivider(),
        if (appBar != null) appBar!,
        if (isExpanded) Expanded(child: child) else child,
      ],
    );

    final blur = glassBlurSigma ??
        (enableGlassEffect ? 20.0 : 15.0);

    const sheetTopRadius = Radius.circular(24);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: sheetTopRadius),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor.withValues(
              alpha: backgroundOpacity ?? (enableGlassEffect ? 0.4 : 0.3),
            ),
            borderRadius: const BorderRadius.vertical(top: sheetTopRadius),
            border: Border(
              top: BorderSide(
                color: Colors.white
                    .withValues(alpha: enableGlassEffect ? 0.25 : 0.1),
                width: enableGlassEffect ? 1.5 : 1,
              ),
            ),
            boxShadow: enableDropShadow || subtleBottomShadow
                ? subtleBottomShadow
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        // Верхняя белая тень (glass glow effect)
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, -3),
                          spreadRadius: 0,
                        ),
                        // Основная drop shadow
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
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
