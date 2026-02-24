import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_request.freezed.dart';

enum SocialProvider { google, apple }

@freezed
class LoginRequest with _$LoginRequest {
  const factory LoginRequest.email({
    required String email,
    required String password,
  }) = _EmailLoginRequest;

  const factory LoginRequest.social({
    required SocialProvider provider,
  }) = _SocialLoginRequest;

  const factory LoginRequest.phoneCode({
    required String verificationId,
    required String code,
  }) = _PhoneCodeLoginRequest;

  const factory LoginRequest.firebasePhone({
    required String firebaseIdToken,
  }) = _FirebasePhoneLoginRequest;
}
