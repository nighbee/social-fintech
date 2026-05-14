import 'package:flutter/material.dart';

abstract final class ChatSapphireStyles {
  static const double listCornerRadius = 6;

  /// Сетка строки чата (Figma: сверху 12, снизу 44; аватар 48; hug-высота ряда 12+48+44=104).
  static const double threadCardPaddingTop = 12;
  static const double threadCardPaddingBottom = 44;
  static const double threadCardPaddingHorizontal = 14;

  /// Минимальная высота карточки (Figma hug ≈ 104 для короткой строки).
  /// Верхнюю границу 104 в макете не дублируем как `maxHeight`: при имени + ранге
  /// + превью строка выше, иначе текст обрежется при отступах 12 / 44.
  static const double threadCardMinHeight = 104;

  /// Горизонтально между правым краем аватарки и текстом.
  static const double threadCardGapAfterAvatar = 12;
  static const double threadCardAvatarSize = 48;

  static double get threadCardAvatarRadius => threadCardAvatarSize / 2;

  /// Зона времени и бейджа справа (достаточно ширины для «Yesterday» в одну строку).
  static const double threadCardRightRailWidth = 80;
  static const double threadCardGapBeforeRightRail = 8;
  static double get threadCardRightContentReserve =>
      threadCardGapBeforeRightRail + threadCardRightRailWidth;

  /// Мягкий сапфир с лёгкой прозрачностью (фон страницы слегка просвечивает).
  static const LinearGradient threadCardSapphireFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xD81C2D4E),
      Color(0xD0131C32),
      Color(0xC80A101C),
    ],
    stops: <double>[0.0, 0.48, 1.0],
  );

  /// Лёгкий блик сверху слева.
  static const LinearGradient threadCardGlassLightFill = LinearGradient(
    begin: Alignment(-0.92, -0.92),
    end: Alignment(0.55, 0.72),
    colors: <Color>[
      Color(0x0CFFFFFF),
      Color(0x00FFFFFF),
    ],
    stops: <double>[0.0, 0.55],
  );

  /// Обводка в духе moonstone-виджетов приложения.
  static const Color threadCardBorderColor = Color(0x26D7E1EA);

  /// Акцент «Moonstone» в строке ранга.
  static const Color rankLineColor = Color(0xFF96BCDE);

  /// Остаток строки ранга после префикса ранга.
  static const Color rankLineMutedColor = Color(0xFF8A93A3);

  static const Color searchFieldFill = Color(0xFF212125);

  /// Figma: Y 4, blur 32, #000 48%.
  static final List<BoxShadow> threadCardShadows = <BoxShadow>[
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.48),
      blurRadius: 32,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];
}
