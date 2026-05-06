import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/auth/data/models/login_dto.dart';
import 'package:app/src/features/auth/data/models/phone_code_response_dto.dart';
import 'package:app/src/features/auth/data/models/user_search_dto.dart';

abstract interface class IAuthRemote {
  Future<Either<DomainException, LoginDto>> loginWithGoogle({
    required String providerToken,
  });
  Future<Either<DomainException, LoginDto>> loginWithApple({
    required String providerToken,
  });
  Future<Either<DomainException, bool>> checkEmailExists({
    required String email,
  });
  Future<Either<DomainException, LoginDto>> loginWithEmail({
    required String email,
    required String password,
  });
  Future<Either<DomainException, LoginDto>> registerWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    String? referral,
  });
  Future<Either<DomainException, PhoneCodeResponseDto>> requestPhoneCode({
    required String countryCode,
    required String phoneNumber,
    required String purpose,
  });
  Future<Either<DomainException, LoginDto>> verifyPhoneCode({
    required String verificationId,
    required String code,
  });
  Future<Either<DomainException, LoginDto>> registerWithPhone({
    required String verificationId,
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    String? referral,
  });
  Future<Either<DomainException, LoginDto>> firebasePhoneLogin({
    required String firebaseIdToken,
  });
  Future<Either<DomainException, LoginDto>> firebasePhoneRegister({
    required String firebaseIdToken,
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    String? referral,
  });
  Future<Either<DomainException, LoginDto>> firebaseEmailLogin({
    required String firebaseIdToken,
  });
  Future<Either<DomainException, LoginDto>> firebaseEmailRegister({
    required String firebaseIdToken,
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    String? referral,
  });
  Future<Either<DomainException, List<UserSearchDto>>> searchUsers({
    required String firstName,
    required String lastName,
    int limit,
  });
  Future<Either<DomainException, void>> logout();
}
