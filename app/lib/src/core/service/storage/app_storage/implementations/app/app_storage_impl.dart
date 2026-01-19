part of '../../storage_service.dart';

@LazySingleton(as: IAppStorage)
class AppStorageImpl implements IAppStorage {
  @override
  Future<void> setLocale(String locale) =>
      prefsInstance.set<String>(KeyStore.locale, locale);

  @override
  String getLocale() => prefsInstance.get<String>(KeyStore.locale) ?? 'ru';

  @override
  Future<void> setEnvironment(String env) =>
      prefsInstance.set<String>(KeyStore.environmentType, env);

  @override
  String getEnvironment(String defaultValue) =>
      prefsInstance.get<String>(KeyStore.environmentType) ?? defaultValue;
}
