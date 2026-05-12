import 'package:flutter/material.dart';

/// Лента сообщений: фон и пузыри (ориентир — макеты Figma, без «кричащих» пятен).
abstract final class ChatConversationStyles {
  /// База экрана: почти чёрный, лёгкая глубина по вертикали/диагонали.
  static const LinearGradient viewportGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF09090B),
      Color(0xFF0E0E10),
      Color(0xFF121214),
    ],
    stops: <double>[0.0, 0.48, 1.0],
  );

  /// Очень слабый «mesh»: слева холодный синий, справа чуть теплее (teal), как в макете.
  static const Color meshBlobLeft = Color(0x061A2C48);
  static const Color meshBlobRight = Color(0x05152024);

  static const double meshBlobLeftSize = 340;
  static const double meshBlobRightSize = 300;

  // —— Пузыри ——

  static const double bubbleRadiusLarge = 10;
  static const double bubbleRadiusSmall = 3;

  static const double systemBubbleRadius = 8;

  static const Color bubbleIncomingFill = Color(0xFF2A2A2E);
  static const Color bubbleIncomingBorder = Color(0x14FFFFFF);

  static const Color bubbleOutgoingFill = Color(0xFFECECEF);
  static const Color bubbleOutgoingBorder = Color(0x22000000);

  static const Color bubbleOutgoingText = Color(0xFF121418);
  static const Color bubbleOutgoingMeta = Color(0xFF5C6168);

  static const Color bubbleIncomingMeta = Color(0xFF9AA1AC);

  static const Color bubbleSystemFill = Color(0xFF232328);
  static const Color bubbleSystemBorder = Color(0x22FFFFFF);
  static const Color bubbleSystemText = Color(0xFFC9CED6);

  static const Color dateChipFill = Color(0xFF1C1C20);
  static const Color dateChipBorder = Color(0x14FFFFFF);
}
