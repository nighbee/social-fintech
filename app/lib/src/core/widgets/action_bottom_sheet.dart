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
    /// Set false for heavy sheets (e.g. long lists) — [BackdropFilter] is costly on emulators.
    this.useBackdropBlur = true,
    /// Hairline under rounded top; off for solid dark sheets (grabber is [ActionBottomSheetDivider]).
    this.showTopBorder = true,
    /// Drag handle pill; null = light gray (glass sheets). Use darker on `#161616`.
    this.grabberColor,
    this.clipBehavior = Clip.antiAlias,
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
  final bool useBackdropBlur;
  final bool showTopBorder;
  final Color? grabberColor;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final blur = glassBlurSigma ??
        (enableGlassEffect ? 20.0 : 15.0);

    const sheetTopRadius = Radius.circular(24);

    final decoration = BoxDecoration(
      color: backgroundColor.withValues(
        alpha: backgroundOpacity ?? (enableGlassEffect ? 0.4 : 0.3),
      ),
      borderRadius: const BorderRadius.vertical(top: sheetTopRadius),
      border: showTopBorder
          ? Border(
              top: BorderSide(
                color: Colors.white
                    .withValues(alpha: enableGlassEffect ? 0.25 : 0.1),
                width: enableGlassEffect ? 1.5 : 1,
              ),
            )
          : null,
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
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackH = MediaQuery.sizeOf(context).height * 0.92;
        final maxH = constraints.maxHeight;
        final sheetHeight = maxH.isFinite ? maxH : fallbackH;

        final columnChildren = <Widget>[
          // Иначе при crossAxisAlignment.stretch полоска растягивается на всю ширину шита.
          if (showDivider)
            Center(child: ActionBottomSheetDivider(color: grabberColor)),
          if (appBar != null) appBar!,
          if (isExpanded) Expanded(child: child) else child,
        ];

        final sheetBody = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
          children: columnChildren,
        );

        final sheet = Container(
          decoration: decoration,
          child: isExpanded
              ? SizedBox(height: sheetHeight, child: sheetBody)
              : sheetBody,
        );

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: sheetTopRadius),
          clipBehavior: clipBehavior,
          child: useBackdropBlur
              ? BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: blur,
                    sigmaY: blur,
                  ),
                  child: sheet,
                )
              : sheet,
        );
      },
    );
  }
}

class ActionBottomSheetDivider extends StatelessWidget {
  const ActionBottomSheetDivider({super.key, this.color});

  static const Color _defaultGrabber = Color(0xFFD9D9D9);

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 38,
      height: 4.5,
      decoration: BoxDecoration(
        color: color ?? _defaultGrabber,
        borderRadius: BorderRadius.circular(4.5 / 2),
      ),
    );
  }
}
