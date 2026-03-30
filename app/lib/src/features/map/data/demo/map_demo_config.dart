import 'package:flutter/foundation.dart';


bool get mapDemoMocksEnabled {
  if (!kDebugMode) {
    return false;
  }
  return const bool.fromEnvironment('MAP_DEMO_MOCKS', defaultValue: true);
}

const double mapDemoAlmatyLatitude = 43.2567;
const double mapDemoAlmatyLongitude = 76.9286;
