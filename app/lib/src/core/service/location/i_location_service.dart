abstract interface class ILocationService {
  Future<LocationServiceResult> resolveCurrentLocation();
}

class LocationServiceResult {
  const LocationServiceResult._({
    required this.isSuccess,
    required this.latitude,
    required this.longitude,
    this.message,
  });

  const LocationServiceResult.success({
    required double latitude,
    required double longitude,
  }) : this._(
          isSuccess: true,
          latitude: latitude,
          longitude: longitude,
        );

  const LocationServiceResult.failure({
    required String message,
  }) : this._(
          isSuccess: false,
          latitude: 0,
          longitude: 0,
          message: message,
        );

  final bool isSuccess;
  final double latitude;
  final double longitude;
  final String? message;
}
