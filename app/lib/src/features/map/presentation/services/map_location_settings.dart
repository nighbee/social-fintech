import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:geolocator/geolocator.dart';

/// Настройки под iOS: Core Location при [LocationAccuracy.medium] чаще отдаёт
/// смешанный фикс (Wi‑Fi/соты), чем «чистый» симулированный GPS симулятора (часто SF).
class MapGeo {
  MapGeo._();

  static bool get _ios =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Первый запрос координат (в т.ч. до стрима).
  static Future<Position?> getBestCurrentPosition() async {
    Future<Position?> tryGet(LocationSettings settings) async {
      try {
        return await Geolocator.getCurrentPosition(locationSettings: settings);
      } catch (_) {
        return null;
      }
    }

    if (_ios) {
      final medium = await tryGet(
        AppleSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 15),
          activityType: ActivityType.other,
          distanceFilter: 0,
        ),
      );
      if (medium != null) {
        return medium;
      }
      final high = await tryGet(
        AppleSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 12),
          activityType: ActivityType.other,
        ),
      );
      if (high != null) {
        return high;
      }
    } else {
      final pos = await tryGet(
        const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (pos != null) {
        return pos;
      }
    }

    final last = await Geolocator.getLastKnownPosition();
    if (last != null && _isFresh(last)) {
      return last;
    }
    return null;
  }

  /// Стрим для маркера «я».
  static LocationSettings streamSettings() {
    if (_ios) {
      return AppleSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 0,
        activityType: ActivityType.other,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 8,
    );
  }

  static bool _isFresh(Position p, {Duration maxAge = const Duration(minutes: 20)}) {
    final age = DateTime.now().toUtc().difference(p.timestamp.toUtc());
    return !age.isNegative && age <= maxAge;
  }
}
