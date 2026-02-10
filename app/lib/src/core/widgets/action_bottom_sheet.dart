import 'dart:ui';

import 'package:flutter/material.dart';

class ActionBottomSheet extends StatelessWidget {
  const ActionBottomSheet({
    super.key,
    this.appBar,
    required this.child,
    this.backgroundColor = Colors.white,
    this.isExpanded = false,
  });

  final PreferredSizeWidget? appBar;
  final Widget child;
  final Color backgroundColor;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        const ActionBottomSheetDivider(),
        if (appBar != null) appBar!,
        Flexible(child: child),
      ],
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor.withOpacity(0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
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
