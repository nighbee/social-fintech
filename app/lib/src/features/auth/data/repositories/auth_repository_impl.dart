import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/auth/data/models/login_dto.dart';
import 'package:app/src/features/auth/data/sources/local/i_auth_local.dart';
import 'package:app/src/features/auth/data/sources/remote/firebase_auth_service.dart';
import 'package:app/src/features/auth/data/sources/remote/i_auth_remote.dart';
import 'package:app/src/features/auth/domain/entities/login_entity.dart';
import 'package:app/src/features/auth/domain/entities/user_search_entity.dart';
import 'package:app/src/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:app/src/features/auth/domain/requests/login_request.dart';
import 'package:app/src/features/auth/domain/requests/phone_code_request.dart';
import 'package:app/src/features/auth/domain/requests/register_request.dart';

@named
@LazySingleton(as: IAuthRepository)
class AuthRepositoryImpl implements IAuthRepository {
  AuthRepositoryImpl(
    @Named('AuthRemoteImpl') this._authRemote,
    @Named('AuthLocalImpl') this._authLocal,
  );

  final IAuthRemote _authRemote;
  final IAuthLocal _authLocal;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
        '493875542368-vi58p07f5006e1pnobc40eub1406df2d.apps.googleusercontent.com',
  );
  final FirebaseAuthService _firebaseAuth = FirebaseAuthService();

  @override
  Future<Either<DomainException, LoginEntity>> login(LoginRequest request) async {
    return request.when(
      email: _loginWithEmail,
      social: _loginWithSocial,
      phoneCode: _verifyPhoneCode,
      firebasePhone: _firebasePhoneLogin,
    );
  }

  @override
  Future<Either<DomainException, bool>> checkEmailExists({
    required String email,
  }) async {
    return _authRemote.checkEmailExists(email: email);
  }

  @override
  Future<Either<DomainException, LoginEntity>> register(
    RegisterRequest request,
  ) async {
    return request.when(
      email: _registerWithEmail,
      phone: _registerWithPhone,
      firebasePhone: _firebasePhoneRegister,
    );
  }

  @override
  Future<Either<DomainException, void>> requestPhoneCode(
    PhoneCodeRequest request,
  ) async {
    final result = await _authRemote.requestPhoneCode(
      countryCode: request.countryCode,
      phoneNumber: request.phoneNumber,
      purpose: request.purpose,
    );

    return result.fold((error) => Left(error), (_) => const Right(null));
  }

  @override
  Future<Either<DomainException, void>> logout() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
    await _authRemote.logout();
    await _authLocal.clearTokens();
    return const Right(null);
  }

  @override
  Future<Either<DomainException, List<UserSearchEntity>>> searchUsers({
    required String firstName,
    required String lastName,
    int limit = 20,
  }) async {
    final result = await _authRemote.searchUsers(
      firstName: firstName,
      lastName: lastName,
      limit: limit,
    );

    return result.fold(
      (error) => Left(error),
      (dtoList) {
        final List<UserSearchEntity> entities =
            dtoList.map((dto) => dto.toEntity()).toList();
        return Right(entities);
      },
    );
  }

  @override
  Future<Either<DomainException, String>> startPhoneVerification({
    required String phoneNumber,
  }) async {
    try {
      final verificationId = await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (String verificationId) {},
        onError: (String error) {},
      );
      return Right(verificationId);
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  @override
  Future<Either<DomainException, String>> verifyOtpAndGetToken({
    required String verificationId,
    required String code,
  }) async {
    try {
      final idToken = await _firebaseAuth.verifyOtpCode(
        verificationId: verificationId,
        smsCode: code,
      );
      return Right(idToken);
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }

  Future<Either<DomainException, LoginEntity>> _loginWithEmail(
    String email,
    String password,
  ) async {
    final result = await _authRemote.loginWithEmail(
      email: email,
      password: password,
    );

    return _mapLoginResult(result);
  }

  Future<Either<DomainException, LoginEntity>> _loginWithSocial(
    SocialProvider provider,
  ) async {
    try {
      switch (provider) {
        case SocialProvider.google:
          final googleUser = await _googleSignIn.signIn();
          if (googleUser == null) {
            return Left(
              GoogleSignInException(message: 'User cancelled Google Sign In'),
            );
          }

          final googleAuth = await googleUser.authentication;
          final idToken = googleAuth.idToken;
          if (idToken == null) {
            return Left(
              GoogleSignInException(message: 'Failed to get Google ID token'),
            );
          }

          final loginResult = await _authRemote.loginWithGoogle(
            providerToken: idToken,
          );
          final shouldGoRegister = loginResult.fold(
            (error) => _isRegisterRequiredMessage(error.message),
            (_) => false,
          );
          if (shouldGoRegister) {
            return Left(
              SocialRegisterRequiredException(
                provider: 'google',
                providerToken: idToken,
                message: loginResult.fold(
                  (error) => error.message,
                  (_) => 'Social register required',
                ),
              ),
            );
          }

          return _mapLoginResult(loginResult);

        case SocialProvider.apple:
          final credential = await SignInWithApple.getAppleIDCredential(
            scopes: [
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
          );

          final identityToken = credential.identityToken;
          if (identityToken == null) {
            return Left(
              AppleSignInException(
                message: 'Failed to get Apple identity token',
              ),
            );
          }

          return _mapLoginResult(
            await _authRemote.loginWithApple(providerToken: identityToken),
          );
      }
    } catch (e) {
      if (provider == SocialProvider.google) {
        return Left(
          GoogleSignInException(message: 'Google Sign In failed: $e'),
        );
      }
      return Left(AppleSignInException(message: 'Apple Sign In failed: $e'));
    }
  }

  Future<Either<DomainException, LoginEntity>> _verifyPhoneCode(
    String verificationId,
    String code,
  ) async {
    final result = await _authRemote.verifyPhoneCode(
      verificationId: verificationId,
      code: code,
    );

    return _mapLoginResult(result);
  }

  Future<Either<DomainException, LoginEntity>> _firebasePhoneLogin(
    String firebaseIdToken,
  ) async {
    final result = await _authRemote.firebasePhoneLogin(
      firebaseIdToken: firebaseIdToken,
    );

    return _mapLoginResult(result);
  }

  Future<Either<DomainException, LoginEntity>> _registerWithEmail(
    String email,
    String password,
    String firstName,
    String lastName,
    String dateOfBirth,
    String? referral,
  ) async {
    final result = await _authRemote.registerWithEmail(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      referral: referral,
    );

    return _mapLoginResult(result);
  }

  Future<Either<DomainException, LoginEntity>> _registerWithPhone(
    String verificationId,
    String firstName,
    String lastName,
    String dateOfBirth,
    String? referral,
  ) async {
    final result = await _authRemote.registerWithPhone(
      verificationId: verificationId,
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      referral: referral,
    );

    return _mapLoginResult(result);
  }

  Future<Either<DomainException, LoginEntity>> _firebasePhoneRegister(
    String firebaseIdToken,
    String firstName,
    String lastName,
    String dateOfBirth,
    String? referral,
  ) async {
    final result = await _authRemote.firebasePhoneRegister(
      firebaseIdToken: firebaseIdToken,
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      referral: referral,
    );

    return _mapLoginResult(result);
  }

  Future<Either<DomainException, LoginEntity>> _mapLoginResult(
    Either<DomainException, LoginDto> result,
  ) async {
    return result.fold((error) => Left(error), (dto) async {
      final entity = dto.toEntity();
      await _authLocal.saveTokens(
        accessToken: entity.accessToken,
        refreshToken: entity.refreshToken,
      );
      return Right(entity);
    });
  }

  bool _isRegisterRequiredMessage(String message) {
    final value = message.toLowerCase();
    return value.contains('not found') ||
        value.contains('user does not exist') ||
        value.contains('no user') ||
        value.contains('please register') ||
        value.contains('register first');
  }
}
