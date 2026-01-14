part of 'theme.dart';

class AppColors {
  // app colors
  static const backgroundGray = Color(0xffd9d9d9);
  static const whiteBackground = Color(0xffffffff);
  static const blackBackground = Color(0xff000000);

  static const textGray1 = Color(0xffcacaca);
  static const textGray2 = Color(0xff838383);
  static const textGray3 = Color(0xff87898f);

  static const btnGray = Color(0xffdbdbdb);
  static const redText = Color(0xffa43337);

  static const blueText1 = Color(0xff74afe3);
  static const blueText2 = Color(0xff819dff);

  static const yellowText = Color(0xffb39600);
  static const greenText = Color(0xff028a66);
}

extension ColorThemeDataExtension on ThemeData {
  // background colors
  Color get backgroundGray => AppColors.backgroundGray;
  Color get whiteBackground => AppColors.whiteBackground;
  Color get blackBackground => AppColors.blackBackground;

  // text colors
  Color get textGray1 => AppColors.textGray1;
  Color get textGray2 => AppColors.textGray2;
  Color get textGray3 => AppColors.textGray3;
  Color get redText => AppColors.redText;
  Color get blueText1 => AppColors.blueText1;
  Color get blueText2 => AppColors.blueText2;
  Color get yellowText => AppColors.yellowText;
  Color get greenText => AppColors.greenText;

  // button colors
  Color get btnGray => AppColors.btnGray;
}
