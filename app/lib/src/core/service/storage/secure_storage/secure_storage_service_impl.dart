import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app/src/core/service/storage/app_storage/storage_service.dart';
import 'package:app/src/core/service/storage/key_store.dart';
import 'package:app/src/core/utils/loggers/log.dart';

part 'i_secure_storage_service.dart';

const _tag = 'SecureStorageServiceImpl';

class SecureStorageServiceImpl implements ISecureStorageService {
  static final SecureStorageServiceImpl _instance =
      SecureStorageServiceImpl._internal();
  factory SecureStorageServiceImpl() => _instance;
  SecureStorageServiceImpl._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<String?> getAccessToken() async {
    Log.debug(_tag, 'getAccessToken');
    /*
    * Сделано для чтобы после переустановки сбрасывать авторизационные данные из KeyChain
    */
    if (prefsInstance.get<bool>(KeyStore.isInitialLaunch) ?? true) {
      await deleteAccessToken();
      await deleteRefreshToken();
      await prefsInstance.set<bool>(KeyStore.isInitialLaunch, false);
    }
    return await _secureStorage.read(key: KeyStore.accessToken);
  }

  @override
  Future<String?> getRefreshToken() async {
    Log.debug(_tag, 'getRefreshToken');
    return await _secureStorage.read(key: KeyStore.refreshToken);
  }

  @override
  Future<void> setAccessToken(String token) async {
    Log.debug(_tag, 'setAccessToken');
    await _secureStorage.write(key: KeyStore.accessToken, value: token);
  }

  @override
  Future<void> setRefreshToken(String token) async {
    Log.debug(_tag, 'setRefreshToken');
    await _secureStorage.write(key: KeyStore.refreshToken, value: token);
  }

  @override
  Future<void> deleteAccessToken() async {
    Log.debug(_tag, 'deleteAccessToken');
    await _secureStorage.delete(key: KeyStore.accessToken);
  }

  @override
  Future<void> deleteRefreshToken() async {
    Log.debug(_tag, 'deleteRefreshToken');
    await _secureStorage.delete(key: KeyStore.refreshToken);
  }

  @override
  Future<void> clearStorage() async {
    Log.debug(_tag, 'clearStorage');
    await _secureStorage.deleteAll();
  }
}
