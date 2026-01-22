import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/core/utils/device_id.dart';
import 'package:app/src/features/auth/data/sources/local/i_auth_local.dart';
import 'package:app/src/features/auth/data/sources/remote/i_auth_remote.dart';
import 'package:app/src/features/auth/domain/entities/login_entity.dart';
import 'package:app/src/features/auth/domain/repositories/i_auth_repository.dart';

@named
@LazySingleton(as: IAuthRepository)
class AuthRepositoryImpl implements IAuthRepository {
  AuthRepositoryImpl(
    @Named('AuthRemoteImpl') this._authRemote,
    @Named('AuthLocalImpl') this._authLocal,
  );

  final IAuthRemote _authRemote;
  final IAuthLocal _authLocal;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  final DeviceId _deviceId = DeviceId();

  @override
  Future<Either<DomainException, LoginEntity>> loginWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return Left(
          GoogleSignInException(message: 'User cancelled Google Sign In'),
        );
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.accessToken == null) {
        return Left(
          GoogleSignInException(message: 'Failed to get Google access token'),
        );
      }

      final deviceId = await _deviceId.getDeviceId();
      final result = await _authRemote.loginWithGoogle(
        providerToken: googleAuth.accessToken!,
        deviceId: deviceId,
      );

      return await result.fold((error) => Left(error), (dto) async {
        final entity = dto.toEntity();
        await _authLocal.saveTokens(
          accessToken: entity.accessToken,
          refreshToken: entity.refreshToken,
        );
        return Right(entity);
      });
    } catch (e) {
      return Left(GoogleSignInException(message: 'Google Sign In failed: $e'));
    }
  }

  @override
  Future<Either<DomainException, LoginEntity>> loginWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      if (credential.identityToken == null) {
        return Left(
          AppleSignInException(message: 'Failed to get Apple identity token'),
        );
      }

      final deviceId = await _deviceId.getDeviceId();
      final result = await _authRemote.loginWithApple(
        providerToken: credential.identityToken!,
        deviceId: deviceId,
      );

      return await result.fold((error) => Left(error), (dto) async {
        final entity = dto.toEntity();
        await _authLocal.saveTokens(
          accessToken: entity.accessToken,
          refreshToken: entity.refreshToken,
        );
        return Right(entity);
      });
    } catch (e) {
      return Left(AppleSignInException(message: 'Apple Sign In failed: $e'));
    }
  }

  @override
  Future<Either<DomainException, LoginEntity>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final deviceId = await _deviceId.getDeviceId();
    final result = await _authRemote.loginWithEmail(
      email: email,
      password: password,
      deviceId: deviceId,
    );

    return await result.fold((error) => Left(error), (dto) async {
      final entity = dto.toEntity();
      await _authLocal.saveTokens(
        accessToken: entity.accessToken,
        refreshToken: entity.refreshToken,
      );
      return Right(entity);
    });
  }

  @override
  Future<Either<DomainException, LoginEntity>> registerWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String referral,
  }) async {
    final deviceId = await _deviceId.getDeviceId();
    final result = await _authRemote.registerWithEmail(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      deviceId: deviceId,
      dateOfBirth: dateOfBirth,
      referral: referral,
    );

    return await result.fold((error) => Left(error), (dto) async {
      final entity = dto.toEntity();
      await _authLocal.saveTokens(
        accessToken: entity.accessToken,
        refreshToken: entity.refreshToken,
      );
      return Right(entity);
    });
  }

  @override
  Future<Either<DomainException, void>> requestPhoneCode({
    required String countryCode,
    required String phoneNumber,
    required String purpose,
  }) async {
    final result = await _authRemote.requestPhoneCode(
      countryCode: countryCode,
      phoneNumber: phoneNumber,
      purpose: purpose,
    );

    return result.fold((error) => Left(error), (_) => const Right(null));
  }

  @override
  Future<Either<DomainException, LoginEntity>> verifyPhoneCode({
    required String verificationId,
    required String code,
  }) async {
    final deviceId = await _deviceId.getDeviceId();
    final result = await _authRemote.verifyPhoneCode(
      verificationId: verificationId,
      code: code,
      deviceId: deviceId,
    );

    return await result.fold((error) => Left(error), (dto) async {
      final entity = dto.toEntity();
      await _authLocal.saveTokens(
        accessToken: entity.accessToken,
        refreshToken: entity.refreshToken,
      );
      return Right(entity);
    });
  }

  @override
  Future<Either<DomainException, LoginEntity>> registerWithPhone({
    required String verificationId,
    required String firstName,
    required String lastName,
    String? dateOfBirth,
    String? referral,
  }) async {
    final deviceId = await _deviceId.getDeviceId();
    final result = await _authRemote.registerWithPhone(
      verificationId: verificationId,
      firstName: firstName,
      lastName: lastName,
      deviceId: deviceId,
      dateOfBirth: dateOfBirth,
      referral: referral,
    );

    return await result.fold((error) => Left(error), (dto) async {
      final entity = dto.toEntity();
      await _authLocal.saveTokens(
        accessToken: entity.accessToken,
        refreshToken: entity.refreshToken,
      );
      return Right(entity);
    });
  }

  @override
  Future<Either<DomainException, void>> logout() async {
    await _googleSignIn.signOut();
    await _authRemote.logout();
    await _authLocal.clearTokens();
    return const Right(null);
  }
}
