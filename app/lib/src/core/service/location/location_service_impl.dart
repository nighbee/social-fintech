import 'package:app/src/core/service/location/i_location_service.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:injectable/injectable.dart';

@named
@LazySingleton(as: ILocationService)
class LocationServiceImpl implements ILocationService {
  @override
  Future<LocationServiceResult> resolveCurrentLocation() async {
    final locationEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!locationEnabled) {
      await geo.Geolocator.openLocationSettings();
      return const LocationServiceResult.failure(
        message: 'Location services are disabled. Enable GPS and try again.',
      );
    }

    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }

    if (permission == geo.LocationPermission.denied) {
      return const LocationServiceResult.failure(
        message:
            'Location permission denied. Grant permission to use current location.',
      );
    }

    if (permission == geo.LocationPermission.deniedForever) {
      await geo.Geolocator.openAppSettings();
      return const LocationServiceResult.failure(
        message:
            'Location permission denied. Grant permission to use current location.',
      );
    }

    geo.Position? position = await geo.Geolocator.getLastKnownPosition();
    position ??= await geo.Geolocator.getCurrentPosition(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.medium,
      ),
      timeLimit: const Duration(seconds: 8),
    );

    return LocationServiceResult.success(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
