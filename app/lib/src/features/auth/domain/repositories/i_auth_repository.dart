import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/auth/domain/entities/login_entity.dart';
import 'package:app/src/features/auth/domain/entities/user_search_entity.dart';
import 'package:app/src/features/auth/domain/requests/login_request.dart';
import 'package:app/src/features/auth/domain/requests/phone_code_request.dart';
import 'package:app/src/features/auth/domain/requests/register_request.dart';

abstract interface class IAuthRepository {
  Future<Either<DomainException, LoginEntity>> login(LoginRequest request);
  Future<Either<DomainException, bool>> checkEmailExists({
    required String email,
  });
  Future<Either<DomainException, LoginEntity>> register(RegisterRequest request);
  Future<Either<DomainException, void>> requestPhoneCode(PhoneCodeRequest request);
  Future<Either<DomainException, String>> startPhoneVerification({
    required String phoneNumber,
  });
  Future<Either<DomainException, String>> verifyOtpAndGetToken({
    required String verificationId,
    required String code,
  });
  Future<Either<DomainException, List<UserSearchEntity>>> searchUsers({
    required String firstName,
    required String lastName,
    int limit,
  });
  Future<Either<DomainException, void>> logout();
}
