part of 'theme.dart';

abstract class TextStyles {
  static const titleXBig = TextStyle(
    fontSize: 30,
    fontFamily: FontFamily.canelaDeckTrial,
    fontWeight: FontWeight.w500,
    color: AppColors.textGray3,
    height: 36 / 30,
  );
  static const titleBig = TextStyle(
    fontSize: 24,
    fontFamily: FontFamily.canelaDeckTrial,
    fontWeight: FontWeight.w500,
    color: AppColors.textGray3,
    height: 26 / 24,
  );

  static const titleMain = TextStyle(
    fontSize: 20,
    fontFamily: FontFamily.canelaDeckTrial,
    fontWeight: FontWeight.w500,
    color: AppColors.textGray3,
    height: 22 / 20,
  );

  static const titleHeadline = TextStyle(
    fontSize: 18,
    fontFamily: FontFamily.canelaDeckTrial,
    fontWeight: FontWeight.w500,
    color: AppColors.textGray3,
    height: 20 / 18,
  );

  static const titleTag = TextStyle(
    fontSize: 16,
    fontFamily: FontFamily.canelaDeckTrial,
    fontWeight: FontWeight.w400,
    color: AppColors.textGray3,
    height: 18 / 16,
  );

  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontFamily: FontFamily.lora,
    fontWeight: FontWeight.w400,
    color: AppColors.textGray3,
    height: 18 / 16,
  );

  static const bodyMain = TextStyle(
    fontSize: 13,
    fontFamily: FontFamily.lora,
    fontWeight: FontWeight.w400,
    color: AppColors.textGray3,
    height: 15 / 13,
  );

  static const bodySecondary = TextStyle(
    fontSize: 12,
    fontFamily: FontFamily.canelaDeckTrial,
    fontWeight: FontWeight.w400,
    color: AppColors.textGray3,
    height: 14 / 12,
  );
}
