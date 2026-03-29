class KeyStore {
  //* Environment
  static const String environmentType = 'ENVIRONMENT_TYPE';

  //* Locale
  static const String locale = 'LOCALE';

  //* Auth Tokens
  static const String accessToken = 'ACCESS_TOKEN';
  static const String refreshToken = 'REFRESH_TOKEN';
  static const String isInitialLaunch = 'IS_INITIAL_LAUNCH';

  //* Map
  static const String mapLastCenterLat = 'MAP_LAST_CENTER_LAT';
  static const String mapLastCenterLon = 'MAP_LAST_CENTER_LON';
  static const String mapActiveExecutorTaskId = 'MAP_ACTIVE_EXECUTOR_TASK_ID';
  static const String mapActiveExecutorApplicationId =
      'MAP_ACTIVE_EXECUTOR_APPLICATION_ID';

  //* Profile — Location access (client-only until API exists)
  static const String locationAccessLabel = 'LOCATION_ACCESS_LABEL';
  static const String locationAccessPrecise = 'LOCATION_ACCESS_PRECISE';
}
