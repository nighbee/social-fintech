part of '../../storage_service.dart';

abstract interface class IAppStorage {
  Future<void> setLocale(String locale);
  String getLocale();

  Future<void> setEnvironment(String env);
  String getEnvironment(String defaultValue);
}
