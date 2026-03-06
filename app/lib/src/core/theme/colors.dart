part of 'theme.dart';

class AppColors {
  // app colors
  static const colorffd9d9 = Color(0xffd9d9d9);
  static const colorffffffff = Color(0xffffffff);
  static const colorff000000 = Color(0xff000000);
  static const colorff19191A = Color(0xff19191A);

  static const colorffcacaca = Color(0xffcacaca);
  static const colorff838383 = Color(0xff838383);
  static const colorff87898f = Color(0xff87898f);

  static const colorffdbdbdb = Color(0xffdbdbdb);
  static const colorffa9a9a9 = Color(0xffa9a9a9);
  static const colorffa43337 = Color(0xffa43337);

  static const colorff74afe3 = Color(0xff74afe3);
  static const colorff819dff = Color(0xff819dff);

  static const colorffb39600 = Color(0xffb39600);
  static const colorff028a66 = Color(0xff028a66);

  // Additional colors for feed page
  static const colorffE5E5E5 = Color(0xffE5E5E5);
  static const colorff9CA3AF = Color(0xff9CA3AF);
  static const colorff2A2A2B = Color(0xff2A2A2B);
  static const colorff3F3F40 = Color(0xff3F3F40);
  static const colorffEF4444 = Color(0xffEF4444);

  // Additional colors for notifications page
  static const colorff232324 = Color(0xff232324);
  static const colorff7E8086 = Color(0xff7E8086);
  static const colorff2C2D31 = Color(0xff2C2D31);

  // Compatibility aliases for existing semantic usage
  static const backgroundGray = colorffd9d9;
  static const whiteBackground = colorffffffff;
  static const blackBackground = colorff000000;
  static const mainBackground = colorff19191A;

  static const textGray1 = colorffcacaca;
  static const textGray2 = colorff838383;
  static const textGray3 = colorff87898f;

  static const btnGray1 = colorffdbdbdb;
  static const btnGray2 = colorffa9a9a9;
  static const redText = colorffa43337;

  static const blueText1 = colorff74afe3;
  static const blueText2 = colorff819dff;

  static const yellowText = colorffb39600;
  static const greenText = colorff028a66;

  static const textPrimary = colorffE5E5E5;
  static const textSecondary = colorff9CA3AF;
  static const surface = colorff2A2A2B;
  static const border = colorff3F3F40;
  static const error = colorffEF4444;
}

extension ColorThemeDataExtension on ThemeData {
  // background colors
  Color get backgroundGray => AppColors.colorffd9d9;
  Color get whiteBackground => AppColors.colorffffffff;
  Color get blackBackground => AppColors.colorff000000;
  Color get mainBackground => AppColors.colorff19191A;

  // text colors
  Color get textGray1 => AppColors.colorffcacaca;
  Color get textGray2 => AppColors.colorff838383;
  Color get textGray3 => AppColors.colorff87898f;
  Color get redText => AppColors.colorffa43337;
  Color get blueText1 => AppColors.colorff74afe3;
  Color get blueText2 => AppColors.colorff819dff;
  Color get yellowText => AppColors.colorffb39600;
  Color get greenText => AppColors.colorff028a66;

  // button colors
  Color get btnGray => AppColors.colorffdbdbdb;
}
