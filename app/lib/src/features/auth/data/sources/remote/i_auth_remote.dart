import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/auth/data/models/login_dto.dart';
import 'package:app/src/features/auth/data/models/phone_code_response_dto.dart';

abstract interface class IAuthRemote {
  Future<Either<DomainException, LoginDto>> loginWithGoogle({
    required String providerToken,
    required String deviceId,
  });
  Future<Either<DomainException, LoginDto>> loginWithApple({
    required String providerToken,
    required String deviceId,
  });
  Future<Either<DomainException, LoginDto>> loginWithEmail({
    required String email,
    required String password,
    required String deviceId,
  });
  Future<Either<DomainException, LoginDto>> registerWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String deviceId,
    required String dateOfBirth,
    required String referral,
  });
  Future<Either<DomainException, PhoneCodeResponseDto>> requestPhoneCode({
    required String countryCode,
    required String phoneNumber,
    required String purpose,
  });
  Future<Either<DomainException, LoginDto>> verifyPhoneCode({
    required String verificationId,
    required String code,
    required String deviceId,
  });
  Future<Either<DomainException, LoginDto>> registerWithPhone({
    required String verificationId,
    required String firstName,
    required String lastName,
    required String deviceId,
    String? dateOfBirth,
    String? referral,
  });
  Future<Either<DomainException, void>> logout();
}
