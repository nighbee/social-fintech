import 'package:freezed_annotation/freezed_annotation.dart';

part 'register_request.freezed.dart';

@freezed
class RegisterRequest with _$RegisterRequest {
  const factory RegisterRequest.email({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String referral,
  }) = _EmailRegisterRequest;

  const factory RegisterRequest.phone({
    required String verificationId,
    required String firstName,
    required String lastName,
    String? dateOfBirth,
    String? referral,
  }) = _PhoneRegisterRequest;

  const factory RegisterRequest.firebasePhone({
    required String firebaseIdToken,
    required String firstName,
    required String lastName,
    String? dateOfBirth,
    String? referral,
  }) = _FirebasePhoneRegisterRequest;
}
