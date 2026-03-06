import 'dart:ui';

import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    required this.child,
    super.key,
    this.borderRadius = 12.0,
    this.blurSigma = 20.0,
    this.padding,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.5,
    this.enableWhiteGlow = true,
    this.enableDropShadow = true,
    this.whiteGlowColor,
    this.whiteGlowBlurRadius = 12,
    this.whiteGlowOffset = const Offset(0, -3),
    this.dropShadowColor,
    this.dropShadowBlurRadius = 25,
    this.dropShadowOffset = const Offset(0, 8),
  });

  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final bool enableWhiteGlow;
  final bool enableDropShadow;
  final Color? whiteGlowColor;
  final double whiteGlowBlurRadius;
  final Offset whiteGlowOffset;
  final Color? dropShadowColor;
  final double dropShadowBlurRadius;
  final Offset dropShadowOffset;

  @override
  Widget build(BuildContext context) {
    final defaultBackgroundColor = Colors.white.withValues(alpha: 0.4);
    final defaultBorderColor = Colors.white.withValues(alpha: 0.25);
    final defaultWhiteGlowColor = Colors.white.withValues(alpha: 0.15);
    final defaultDropShadowColor = Colors.black.withValues(alpha: 0.4);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor ?? defaultBackgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? defaultBorderColor,
              width: borderWidth,
            ),
            boxShadow: [
              if (enableWhiteGlow)
                BoxShadow(
                  color: whiteGlowColor ?? defaultWhiteGlowColor,
                  blurRadius: whiteGlowBlurRadius,
                  offset: whiteGlowOffset,
                  spreadRadius: 0,
                ),
              if (enableDropShadow)
                BoxShadow(
                  color: dropShadowColor ?? defaultDropShadowColor,
                  blurRadius: dropShadowBlurRadius,
                  offset: dropShadowOffset,
                  spreadRadius: 0,
                ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
