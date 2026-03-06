import 'package:flutter/material.dart';
import 'package:app/gen/fonts.gen.dart';

import '../constants/ui_constants.dart';

part 'colors.dart';
part 'shadows.dart';
part 'text_styles.dart';
part 'theme_context_extension.dart';

class MaterialAppTheme {
  static final theme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.colorffffffff,
    splashFactory: InkSparkle.splashFactory,
    splashColor: AppColors.colorff74afe3.withOpacity(0.3),
    highlightColor: AppColors.colorff74afe3.withOpacity(0.2),
    dividerTheme: const DividerThemeData(
      color: AppColors.colorffd9d9,
      thickness: 1,
      space: 36,
    ),
    textSelectionTheme: TextSelectionThemeData(
      selectionColor: AppColors.colorff028a66.withOpacity(0.3),
      selectionHandleColor: AppColors.colorff74afe3,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      modalBackgroundColor: AppColors.colorffffffff,
      backgroundColor: AppColors.colorffffffff,
      surfaceTintColor: AppColors.colorffffffff,
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
        backgroundColor: AppColors.colorffa43337,
        foregroundColor: AppColors.colorffffffff,
        disabledBackgroundColor: AppColors.colorffd9d9,
        disabledForegroundColor: AppColors.colorff838383,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.defaultRadius),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.colorffffffff,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
      errorStyle: const TextStyle(height: 0),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.colorffd9d9),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.colorff74afe3),
        borderRadius: BorderRadius.circular(12),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.colorffa43337),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.colorffa43337),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    colorScheme: ColorScheme.light(
      primary: AppColors.colorff74afe3,
      secondary: AppColors.colorff819dff,
      error: AppColors.colorffa43337,
      surface: AppColors.colorffffffff,
      background: AppColors.colorffffffff,
      onPrimary: AppColors.colorffffffff,
      onSecondary: AppColors.colorffffffff,
      onError: AppColors.colorffffffff,
      onSurface: AppColors.colorff000000,
      onBackground: AppColors.colorff000000,
    ),
  );

  static final light = theme.copyWith(brightness: Brightness.light);

  static final dark = theme.copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.colorff000000,
    colorScheme: ColorScheme.dark(
      primary: AppColors.colorff74afe3,
      secondary: AppColors.colorff819dff,
      error: AppColors.colorffa43337,
      surface: AppColors.colorff000000,
      background: AppColors.colorff000000,
      onPrimary: AppColors.colorffffffff,
      onSecondary: AppColors.colorffffffff,
      onError: AppColors.colorffffffff,
      onSurface: AppColors.colorffffffff,
      onBackground: AppColors.colorffffffff,
    ),
  );
}
