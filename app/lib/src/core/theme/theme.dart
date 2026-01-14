import 'package:flutter/material.dart';

import '../constants/ui_constants.dart';

part 'colors.dart';
part 'shadows.dart';
part 'text_styles.dart';
part 'theme_context_extension.dart';

class MaterialAppTheme {
  static final theme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.whiteBackground,
    splashFactory: InkSparkle.splashFactory,
    splashColor: AppColors.blueText1.withOpacity(0.3),
    highlightColor: AppColors.blueText1.withOpacity(0.2),
    dividerTheme: const DividerThemeData(
      color: AppColors.backgroundGray,
      thickness: 1,
      space: 36,
    ),
    textSelectionTheme: TextSelectionThemeData(
      selectionColor: AppColors.greenText.withOpacity(0.3),
      selectionHandleColor: AppColors.blueText1,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      modalBackgroundColor: AppColors.whiteBackground,
      backgroundColor: AppColors.whiteBackground,
      surfaceTintColor: AppColors.whiteBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(UIConstants.defaultGap3),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        fixedSize: const Size.fromHeight(44),
        maximumSize: const Size.fromHeight(44),
        backgroundColor: AppColors.redText,
        foregroundColor: AppColors.whiteBackground,
        disabledBackgroundColor: AppColors.backgroundGray,
        disabledForegroundColor: AppColors.textGray2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.defaultRadius),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.whiteBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
      errorStyle: const TextStyle(height: 0),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.backgroundGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.blueText1),
        borderRadius: BorderRadius.circular(12),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.redText),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.redText),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    colorScheme: ColorScheme.light(
      primary: AppColors.blueText1,
      secondary: AppColors.blueText2,
      error: AppColors.redText,
      surface: AppColors.whiteBackground,
      background: AppColors.whiteBackground,
      onPrimary: AppColors.whiteBackground,
      onSecondary: AppColors.whiteBackground,
      onError: AppColors.whiteBackground,
      onSurface: AppColors.blackBackground,
      onBackground: AppColors.blackBackground,
    ),
  );

  static final light = theme.copyWith(brightness: Brightness.light);

  static final dark = theme.copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.blackBackground,
    colorScheme: ColorScheme.dark(
      primary: AppColors.blueText1,
      secondary: AppColors.blueText2,
      error: AppColors.redText,
      surface: AppColors.blackBackground,
      background: AppColors.blackBackground,
      onPrimary: AppColors.whiteBackground,
      onSecondary: AppColors.whiteBackground,
      onError: AppColors.whiteBackground,
      onSurface: AppColors.whiteBackground,
      onBackground: AppColors.whiteBackground,
    ),
  );
}
