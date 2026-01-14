part of 'theme.dart';

abstract class TextStyles {
  // ====================================================
}

class AppTextStyles {}

extension TextStyleThemeDataExtension on ThemeData {
  AppTextStyles get textStyles => AppTextStyles();
}
