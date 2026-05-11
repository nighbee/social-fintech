import 'package:flutter/material.dart';

extension BuildContextExt on BuildContext {
  Future<T?> showRoundedModalBottomSheet<T>({
    required Widget child,
    bool isScrollControlled = true,
    bool useRootNavigator = true,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    Color? barrierColor,
    double? maxHeightFactor,
    VoidCallback? whenDismissed,
  }) {
    return showModalBottomSheet<T>(
      context: this,
      backgroundColor: backgroundColor,
      barrierColor: barrierColor,
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
      builder: (sheetContext) {
        // Иначе Material 3 подмешивает surface / modalBackground из темы — «стекло» становится плотной плашкой.
        return Material(
          type: MaterialType.transparency,
          elevation: 0,
          shadowColor: Colors.transparent,
          child: Theme(
            data: Theme.of(this).copyWith(
              bottomSheetTheme: Theme.of(this).bottomSheetTheme.copyWith(
                modalBackgroundColor: Colors.transparent,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
              ),
            ),
            child: child,
          ),
        );
      },
    ).then((result) {
      whenDismissed?.call();
      return result;
    });
  }
}
