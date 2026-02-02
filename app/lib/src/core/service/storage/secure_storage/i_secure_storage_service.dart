part of 'secure_storage_service_impl.dart';

abstract interface class ISecureStorageService {
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> setAccessToken(String token);
  Future<void> setRefreshToken(String token);
  Future<void> deleteAccessToken();
  Future<void> deleteRefreshToken();
  Future<void> clearStorage();
}
