part of 'theme.dart';

abstract class TextStyles {
  // CanelaDeckTrial styles
  static const titleLarge = TextStyle(
    fontSize: 24,
    fontFamily: FontFamily.canelaDeckTrial,
    fontWeight: FontWeight.bold,
    color: AppColors.whiteBackground,
  );

  static const inputText = TextStyle(
    fontSize: 19,
    fontFamily: FontFamily.canelaDeckTrial,
    fontWeight: FontWeight.w400,
    color: AppColors.textGray1,
  );

  static const hintText = TextStyle(
    fontSize: 17,
    fontFamily: FontFamily.canelaDeckTrial,
    fontWeight: FontWeight.w300,
    color: AppColors.textGray2,
  );

  static const buttonText = TextStyle(
    fontSize: 20,
    fontFamily: FontFamily.canelaDeckTrial,
    fontWeight: FontWeight.w500,
    color: AppColors.blackBackground,
  );

  // Lora styles
  static const labelText = TextStyle(
    fontSize: 12,
    fontFamily: FontFamily.lora,
    color: AppColors.textGray2,
  );

  static const dividerText = TextStyle(
    fontSize: 17,
    fontFamily: FontFamily.lora,
    fontWeight: FontWeight.bold,
    color: AppColors.textGray2,
  );

  // Code page styles
  static const mainTitle = TextStyle(
    fontSize: 30,
    fontFamily: FontFamily.canelaDeckTrial,
    fontWeight: FontWeight.w500,
    height: 1.2, // 36/30 = 1.2
    letterSpacing: 0.4,
    color: AppColors.textGray1,
  );

  static const bodyMain = TextStyle(
    fontSize: 17,
    fontFamily: FontFamily.lora,
    fontWeight: FontWeight.w500,
    height: 1.235, // 21/17 = 1.235
    letterSpacing: 0,
    color: AppColors.textGray3,
  );

  // Info page styles
  static const sectionHeading = TextStyle(
    fontSize: 20,
    fontFamily: FontFamily.lora,
    fontWeight: FontWeight.w500,
    color: AppColors.whiteBackground,
  );
}

class AppTextStyles {
  TextStyle get titleLarge => TextStyles.titleLarge;
  TextStyle get inputText => TextStyles.inputText;
  TextStyle get hintText => TextStyles.hintText;
  TextStyle get buttonText => TextStyles.buttonText;
  TextStyle get labelText => TextStyles.labelText;
  TextStyle get dividerText => TextStyles.dividerText;
  TextStyle get codePageTitle => TextStyles.mainTitle;
  TextStyle get codePageSubtitle => TextStyles.bodyMain;
  TextStyle get sectionHeading => TextStyles.sectionHeading;
}

extension TextStyleThemeDataExtension on ThemeData {
  AppTextStyles get textStyles => AppTextStyles();
}
