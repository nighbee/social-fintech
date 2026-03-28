import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapUiPalette {
  const MapUiPalette._();

  static const String mapStyleUri = MapboxStyles.DARK;

  static const Color panelBackground = Color(0x66363D4D);
  static const Color panelBorder = Color(0x8A7A869B);
  static const Color panelTopGlow = Color(0x26FFFFFF);
  static const Color panelDropShadow = Color(0x8A000000);
  static const Color controlPanelBackground = Color(0x33303030);
  static const Color controlPanelBorder = Color(0x4D8A8A8A);

  static const Color controlIcon = Color(0xFFE3E8F2);
  static const Color subtleText = Color(0xB3FFFFFF);
  static const Color mutedText = Color(0x8AFFFFFF);
  static const Color bannerGradientInner = Color(0x0A444444);
  static const Color bannerGradientOuter = Color(0x0AAAAAAA);
  static const Color bannerShadow = Color(0x59B0B0B0);

  static const Color ctaBackground = Color(0xFF101010);
  static const Color ctaBorder = Color(0x1AFFFFFF);
  static const Color ctaDisabledBackground = Color(0xB0101010);
}
