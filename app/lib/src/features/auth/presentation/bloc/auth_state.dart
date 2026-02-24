part of 'auth_bloc.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = _Initial;
  const factory AuthState.loading() = _Loading;
  const factory AuthState.loadingFailure(String message) = _LoadingFailure;
  const factory AuthState.goRegister() = _GoRegister;
  const factory AuthState.loaded({required AuthViewModel viewModel}) = _Loaded;
  const factory AuthState.authenticated({required LoginEntity loginEntity}) =
      _Authenticated;
  const factory AuthState.phoneVerificationStarted({
    required String verificationId,
    required String phoneNumber,
  }) = _PhoneVerificationStarted;
  const factory AuthState.emailChecked({
    required bool exists,
    required String email,
  }) = _EmailChecked;
}

@freezed
class AuthViewModel with _$AuthViewModel {
  factory AuthViewModel({
    @Default(false) bool isLoading,
    @Default(false) bool isLoggedIn,
    @Default(false) bool isUserSearchLoading,
    @Default([]) List<UserSearchEntity> userSearchResults,
    String? firebaseIdToken,
    String? email,
    String? password,
  }) = _AuthViewModel;
}
