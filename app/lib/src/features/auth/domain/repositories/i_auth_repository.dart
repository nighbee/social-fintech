import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/auth/domain/entities/login_entity.dart';

abstract interface class IAuthRepository {
  Future<Either<DomainException, LoginEntity>> loginWithGoogle();
  Future<Either<DomainException, LoginEntity>> loginWithApple();
  Future<Either<DomainException, bool>> checkEmailExists({
    required String email,
  });
  Future<Either<DomainException, LoginEntity>> loginWithEmail({
    required String email,
    required String password,
  });
  Future<Either<DomainException, LoginEntity>> registerWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String referral,
  });
  Future<Either<DomainException, void>> requestPhoneCode({
    required String countryCode,
    required String phoneNumber,
    required String purpose, // 'login' or 'register'
  });
  Future<Either<DomainException, LoginEntity>> verifyPhoneCode({
    required String verificationId,
    required String code,
  });
  Future<Either<DomainException, LoginEntity>> registerWithPhone({
    required String verificationId,
    required String firstName,
    required String lastName,
    String? dateOfBirth,
    String? referral,
  });
  Future<Either<DomainException, String>> startPhoneVerification({
    required String phoneNumber,
  });
  Future<Either<DomainException, String>> verifyOtpAndGetToken({
    required String verificationId,
    required String code,
  });
  Future<Either<DomainException, LoginEntity>> firebasePhoneLogin({
    required String firebaseIdToken,
  });
  Future<Either<DomainException, LoginEntity>> firebasePhoneRegister({
    required String firebaseIdToken,
    required String firstName,
    required String lastName,
    String? dateOfBirth,
    String? referral,
  });
  Future<Either<DomainException, void>> logout();
}
