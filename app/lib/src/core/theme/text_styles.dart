part of 'theme.dart';

abstract class TextStyles {
  // Title styles - CanelaDeckTrial
  static const titleXLarge = TextStyle(
    fontSize: 30,
    fontFamily: FontFamily.canelaDeckTrial,
    fontWeight: FontWeight.w500,
    height: 1.2, // 36/30 = 1.2
    letterSpacing: 0.4,
    color: AppColors.textGray1,
  );

  static const titleLarge = TextStyle(
    fontSize: 24,
    fontFamily: FontFamily.canelaDeckTrial,
    fontWeight: FontWeight.bold,
    color: AppColors.whiteBackground,
  );

  static const titleMedium = TextStyle(
    fontSize: 20,
    fontFamily: FontFamily.lora,
    fontWeight: FontWeight.w500,
    color: AppColors.whiteBackground,
  );

  static const titleSmall = TextStyle(
    fontSize: 12,
    fontFamily: FontFamily.lora,
    fontWeight: FontWeight.w500,
  );

  // Body styles - CanelaDeckTrial
  static const bodyLarge = TextStyle(
    fontSize: 19,
    fontFamily: FontFamily.canelaDeckTrial,
    fontWeight: FontWeight.w400,
    color: AppColors.textGray1,
  );

  static const bodyMediumBold = TextStyle(
    fontSize: 20,
    fontFamily: FontFamily.canelaDeckTrial,
    fontWeight: FontWeight.w500,
    color: AppColors.blackBackground,
  );

  // Body styles - Lora
  static const bodyMedium = TextStyle(
    fontSize: 17,
    fontFamily: FontFamily.lora,
    fontWeight: FontWeight.w500,
    height: 1.235, // 21/17 = 1.235
    letterSpacing: 0,
    color: AppColors.textGray3,
  );

  static const bodySmall = TextStyle(
    fontSize: 17,
    fontFamily: FontFamily.canelaDeckTrial,
    fontWeight: FontWeight.w300,
    color: AppColors.textGray2,
  );

  static const bodyBold = TextStyle(
    fontSize: 17,
    fontFamily: FontFamily.lora,
    fontWeight: FontWeight.bold,
    color: AppColors.textGray2,
  );

  // Caption styles - Lora
  static const caption = TextStyle(
    fontSize: 12,
    fontFamily: FontFamily.lora,
    color: AppColors.textGray2,
  );
}

class AppTextStyles {
  // Title styles
  TextStyle get titleXLarge => TextStyles.titleXLarge;
  TextStyle get titleLarge => TextStyles.titleLarge;
  TextStyle get titleMedium => TextStyles.titleMedium;
  TextStyle get titleSmall => TextStyles.titleSmall;

  // Body styles
  TextStyle get bodyLarge => TextStyles.bodyLarge;
  TextStyle get bodyMediumBold => TextStyles.bodyMediumBold;
  TextStyle get bodyMedium => TextStyles.bodyMedium;
  TextStyle get bodySmall => TextStyles.bodySmall;
  TextStyle get bodyBold => TextStyles.bodyBold;

  // Caption styles
  TextStyle get caption => TextStyles.caption;

  // Legacy aliases for backward compatibility (deprecated)
  @Deprecated('Use titleXLarge instead')
  TextStyle get codePageTitle => TextStyles.titleXLarge;
  @Deprecated('Use bodyMedium instead')
  TextStyle get codePageSubtitle => TextStyles.bodyMedium;
  @Deprecated('Use titleMedium instead')
  TextStyle get sectionHeading => TextStyles.titleMedium;
  @Deprecated('Use titleSmall instead')
  TextStyle get titleHeadline => TextStyles.titleSmall;
  @Deprecated('Use bodyLarge instead')
  TextStyle get inputText => TextStyles.bodyLarge;
  @Deprecated('Use bodySmall instead')
  TextStyle get hintText => TextStyles.bodySmall;
  @Deprecated('Use bodyMediumBold instead')
  TextStyle get buttonText => TextStyles.bodyMediumBold;
  @Deprecated('Use caption instead')
  TextStyle get labelText => TextStyles.caption;
  @Deprecated('Use bodyBold instead')
  TextStyle get dividerText => TextStyles.bodyBold;
}

extension TextStyleThemeDataExtension on ThemeData {
  AppTextStyles get textStyles => AppTextStyles();
}
