import 'package:injectable/injectable.dart';
import 'package:app/src/core/service/storage/secure_storage/secure_storage_service_impl.dart';
import 'package:app/src/features/auth/data/sources/local/i_auth_local.dart';

@named
@LazySingleton(as: IAuthLocal)
class AuthLocalImpl implements IAuthLocal {
  final ISecureStorageService _storage = SecureStorageServiceImpl();

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.setAccessToken(accessToken);
    await _storage.setRefreshToken(refreshToken);
  }

  @override
  Future<void> clearTokens() async {
    await _storage.deleteAccessToken();
    await _storage.deleteRefreshToken();
  }
}

