part of 'auth_bloc.dart';

@freezed
class AuthEvent with _$AuthEvent {
  const factory AuthEvent.login({required LoginRequest request}) = _Login;
  const factory AuthEvent.register({required RegisterRequest request}) =
      _Register;
  const factory AuthEvent.requestPhoneCode({
    required PhoneCodeRequest request,
  }) = _RequestPhoneCode;
  const factory AuthEvent.startPhoneVerification({
    required String phoneNumber,
  }) = _StartPhoneVerification;
  const factory AuthEvent.checkEmail({required String email}) = _CheckEmail;
  const factory AuthEvent.verifyOtpCode({
    required String verificationId,
    required String code,
    required bool isLogin,
  }) = _VerifyOtpCode;
  const factory AuthEvent.sendEmailMagicLink({
    required String email,
  }) = _SendEmailMagicLink;
  const factory AuthEvent.completeEmailMagicLink({
    required String emailLink,
  }) = _CompleteEmailMagicLink;
  const factory AuthEvent.searchUsers({
    required SearchUsersRequest request,
  }) = _SearchUsers;
  const factory AuthEvent.logout() = _Logout;
}
