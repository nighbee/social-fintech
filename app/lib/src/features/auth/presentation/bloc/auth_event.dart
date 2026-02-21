part of 'auth_bloc.dart';

@freezed
class AuthEvent with _$AuthEvent {
  const factory AuthEvent.loginWithEmail({
    required String email,
    required String password,
  }) = _LoginWithEmail;
  const factory AuthEvent.loginWithGoogle() = _LoginWithGoogle;
  const factory AuthEvent.loginWithApple() = _LoginWithApple;
  const factory AuthEvent.registerWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String referral,
  }) = _RegisterWithEmail;
  const factory AuthEvent.requestPhoneCode({
    required String countryCode,
    required String phoneNumber,
    required String purpose,
  }) = _RequestPhoneCode;
  const factory AuthEvent.verifyPhoneCode({
    required String verificationId,
    required String code,
  }) = _VerifyPhoneCode;
  const factory AuthEvent.registerWithPhone({
    required String verificationId,
    required String firstName,
    required String lastName,
    String? dateOfBirth,
    String? referral,
  }) = _RegisterWithPhone;
  const factory AuthEvent.startPhoneVerification({
    required String phoneNumber,
  }) = _StartPhoneVerification;
  const factory AuthEvent.checkEmail({required String email}) = _CheckEmail;
  const factory AuthEvent.verifyOtpCode({
    required String verificationId,
    required String code,
    required bool isLogin,
  }) = _VerifyOtpCode;
  const factory AuthEvent.firebasePhoneLogin({
    required String firebaseIdToken,
  }) = _FirebasePhoneLogin;
  const factory AuthEvent.firebasePhoneRegister({
    required String firebaseIdToken,
    required String firstName,
    required String lastName,
    String? dateOfBirth,
    String? referral,
  }) = _FirebasePhoneRegister;
  const factory AuthEvent.logout() = _Logout;
}
