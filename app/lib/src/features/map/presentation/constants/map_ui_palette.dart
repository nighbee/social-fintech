import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapUiPalette {
  const MapUiPalette._();

  static const String mapStyleUri = MapboxStyles.DARK;

  static const Color panelBackground = Color(0x4029292D);
  static const Color panelBorder = Color(0x4D777780);
  static const Color panelTopGlow = Color(0x14FFFFFF);
  static const Color panelDropShadow = Color(0x33454545);
  static const Color controlPanelBackground = Color(0x662A2D34);
  static const Color controlPanelBorder = Color(0xFF3D3D3D);
  static const Color panelGradientTop = Color(0x4A4A4A4E);
  static const Color panelGradientBottom = Color(0x332A2A2D);

  static const Color controlIcon = Color(0xFFD2D7E0);
  static const Color subtleText = Color(0xCCFFFFFF);
  static const Color mutedText = Color(0x94FFFFFF);
  static const Color bannerGradientInner = Color(0x2AAAAAAA);
  static const Color bannerGradientOuter = Color(0x24444444);
  static const Color bannerShadow = Color(0x33B0B0B0);

  static const Color ctaBackground = Color(0xFF101010);
  static const Color ctaBorder = Color(0x1AFFFFFF);
  static const Color ctaDisabledBackground = Color(0xB0101010);

  /// Create request screen (Figma)
  static const Color createRequestScaffoldBackground = Color(0xFF19191A);
  static const Color createRequestFieldFill = Color(0xFF19191A);

  /// Primary CTA when form is valid — var(--white)
  static const Color createRequestPrimaryEnabled = Color(0xFFFFFFFF);
  static const Color createRequestPrimaryOnEnabled = Color(0xFF12161F);
  static const Color createRequestPrimaryDisabled = Color(0xFF4A4A4E);
  static const Color createRequestPrimaryOnDisabled = Color(0xFF9A9A9C);
  static const Color createRequestDialogBuyBackground = Color(0xFFDBDBDB);
  static const Color createRequestDialogCancelBorder = Color(0xFFCACACA);
}
