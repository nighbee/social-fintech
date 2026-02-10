import 'package:flutter/material.dart';

extension BuildContextExt on BuildContext {
  Future<T?> showRoundedModalBottomSheet<T>({
    required Widget child,
    bool isScrollControlled = true,
    bool useRootNavigator = true,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    double? maxHeightFactor,
    VoidCallback? whenDismissed,
  }) {
    return showModalBottomSheet<T>(
      context: this,
      backgroundColor: backgroundColor,
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: maxHeightFactor != null
            ? MediaQuery.of(this).size.height * maxHeightFactor
            : double.infinity,
      ),
      builder: (context) {
        return child;
      },
    ).then((result) {
      whenDismissed?.call();
      return result;
    });
  }
}
