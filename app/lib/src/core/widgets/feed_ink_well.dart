import 'package:flutter/material.dart';

/// Тап по элементам ленты без синего Material ripple (тёмный фон карточки).
class FeedInkWell extends StatelessWidget {
  const FeedInkWell({
    super.key,
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      child: child,
    );
  }
}
