import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:app/src/core/base/base_bloc/bloc/base_bloc.dart';
import 'package:app/src/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:app/src/features/auth/domain/entities/login_entity.dart';

part 'auth_bloc.freezed.dart';

// MARK: - State
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

// MARK: - ViewModel
@freezed
class AuthViewModel with _$AuthViewModel {
  factory AuthViewModel({
    @Default(false) bool isLoading,
    @Default(false) bool isLoggedIn,
    String? firebaseIdToken,
    String? email,
    String? password,
  }) = _AuthViewModel;
}

// MARK: - Event
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
  const factory AuthEvent.checkEmail({
    required String email,
  }) = _CheckEmail;
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

// MARK: - Bloc
@injectable
class AuthBloc extends BaseBloc<AuthEvent, AuthState> {
  AuthBloc(@Named('AuthRepositoryImpl') this._authRepository)
    : super(AuthState.initial()) {
    _viewModel = AuthViewModel();
  }

  final IAuthRepository _authRepository;
  AuthViewModel _viewModel = AuthViewModel();
  
  AuthViewModel get viewModel => _viewModel;

  @override
  void onEventHandler(AuthEvent event, Emitter emit) async {
    await event.when(
      loginWithEmail: (email, password) =>
          _loginWithEmail(email, password, emit),
      loginWithGoogle: () => _loginWithGoogle(emit),
      loginWithApple: () => _loginWithApple(emit),
      registerWithEmail:
          (email, password, firstName, lastName, dateOfBirth, referral) =>
              _registerWithEmail(
                email,
                password,
                firstName,
                lastName,
                dateOfBirth ?? '2000-01-01',
                referral ?? '',
                emit,
              ),
      requestPhoneCode: (countryCode, phoneNumber, purpose) =>
          _requestPhoneCode(countryCode, phoneNumber, purpose, emit),
      verifyPhoneCode: (verificationId, code) =>
          _verifyPhoneCode(verificationId, code, emit),
      registerWithPhone:
          (verificationId, firstName, lastName, dateOfBirth, referral) =>
              _registerWithPhone(
                verificationId,
                firstName,
                lastName,
                dateOfBirth,
                referral,
                emit,
              ),
      startPhoneVerification: (phoneNumber) =>
          _startPhoneVerification(phoneNumber, emit),
      checkEmail: (email) => _checkEmail(email, emit),
      verifyOtpCode: (verificationId, code, isLogin) =>
          _verifyOtpCode(verificationId, code, isLogin, emit),
      firebasePhoneLogin: (firebaseIdToken) =>
          _firebasePhoneLogin(firebaseIdToken, emit),
      firebasePhoneRegister: (firebaseIdToken, firstName, lastName, dateOfBirth, referral) =>
          _firebasePhoneRegister(firebaseIdToken, firstName, lastName, dateOfBirth, referral, emit),
      logout: () => _logout(emit),
    );
  }

  Future<void> _loginWithEmail(
    String email,
    String password,
    Emitter emit,
  ) async {
    _viewModel = _viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: _viewModel));

    final result = await _authRepository.loginWithEmail(
      email: email,
      password: password,
    );

    _viewModel = _viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (loginEntity) {
        _viewModel = _viewModel.copyWith(isLoggedIn: true);
        emit(AuthState.authenticated(loginEntity: loginEntity));
      },
    );
  }

  Future<void> _loginWithGoogle(Emitter emit) async {
    _viewModel = _viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: _viewModel));

    final result = await _authRepository.loginWithGoogle();

    _viewModel = _viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (loginEntity) {
        _viewModel = _viewModel.copyWith(isLoggedIn: true);
        emit(AuthState.authenticated(loginEntity: loginEntity));
      },
    );
  }

  Future<void> _loginWithApple(Emitter emit) async {
    _viewModel = _viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: _viewModel));

    final result = await _authRepository.loginWithApple();

    _viewModel = _viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (loginEntity) {
        _viewModel = _viewModel.copyWith(isLoggedIn: true);
        emit(AuthState.authenticated(loginEntity: loginEntity));
      },
    );
  }

  Future<void> _registerWithEmail(
    String email,
    String password,
    String firstName,
    String lastName,
    String dateOfBirth,
    String referral,
    Emitter emit,
  ) async {
    _viewModel = _viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: _viewModel));

    final result = await _authRepository.registerWithEmail(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      referral: referral,
    );

    _viewModel = _viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (loginEntity) {
        _viewModel = _viewModel.copyWith(isLoggedIn: true);
        emit(AuthState.authenticated(loginEntity: loginEntity));
      },
    );
  }

  Future<void> _checkEmail(String email, Emitter emit) async {
    _viewModel = _viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: _viewModel));

    final result = await _authRepository.checkEmailExists(email: email);

    _viewModel = _viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (exists) {
        _viewModel = _viewModel.copyWith(email: email);
        emit(AuthState.emailChecked(exists: exists, email: email));
      },
    );
  }

  Future<void> _requestPhoneCode(
    String countryCode,
    String phoneNumber,
    String purpose,
    Emitter emit,
  ) async {
    _viewModel = _viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: _viewModel));

    final result = await _authRepository.requestPhoneCode(
      countryCode: countryCode,
      phoneNumber: phoneNumber,
      purpose: purpose,
    );

    _viewModel = _viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (_) {
        emit(AuthState.loaded(viewModel: AuthViewModel()));
      },
    );
  }

  Future<void> _verifyPhoneCode(
    String verificationId,
    String code,
    Emitter emit,
  ) async {
    _viewModel = _viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: _viewModel));

    final result = await _authRepository.verifyPhoneCode(
      verificationId: verificationId,
      code: code,
    );

    _viewModel = _viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (loginEntity) {
        _viewModel = _viewModel.copyWith(isLoggedIn: true);
        emit(AuthState.authenticated(loginEntity: loginEntity));
      },
    );
  }

  Future<void> _registerWithPhone(
    String verificationId,
    String firstName,
    String lastName,
    String? dateOfBirth,
    String? referral,
    Emitter emit,
  ) async {
    _viewModel = _viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: _viewModel));

    final result = await _authRepository.registerWithPhone(
      verificationId: verificationId,
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      referral: referral,
    );

    _viewModel = _viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (loginEntity) {
        _viewModel = _viewModel.copyWith(isLoggedIn: true);
        emit(AuthState.authenticated(loginEntity: loginEntity));
      },
    );
  }

  Future<void> _logout(Emitter emit) async {
    _viewModel = _viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: _viewModel));

    final result = await _authRepository.logout();

    _viewModel = _viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (_) {
        _viewModel = _viewModel.copyWith(isLoggedIn: false);
        emit(AuthState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _startPhoneVerification(
    String phoneNumber,
    Emitter emit,
  ) async {
    _viewModel = _viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: _viewModel));

    final result = await _authRepository.startPhoneVerification(
      phoneNumber: phoneNumber,
    );

    _viewModel = _viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (verificationId) {
        emit(AuthState.phoneVerificationStarted(
          verificationId: verificationId,
          phoneNumber: phoneNumber,
        ));
      },
    );
  }

  Future<void> _verifyOtpCode(
    String verificationId,
    String code,
    bool isLogin,
    Emitter emit,
  ) async {
    _viewModel = _viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: _viewModel));

    final tokenResult = await _authRepository.verifyOtpAndGetToken(
      verificationId: verificationId,
      code: code,
    );

    await tokenResult.fold(
      (error) async {
        _viewModel = _viewModel.copyWith(isLoading: false);
        emit(AuthState.loadingFailure(error.message));
      },
      (firebaseIdToken) async {
        if (isLogin) {
          await _firebasePhoneLogin(firebaseIdToken, emit);
        } else {
          _viewModel = _viewModel.copyWith(
            isLoading: false,
            firebaseIdToken: firebaseIdToken,
          );
          emit(AuthState.goRegister());
        }
      },
    );
  }

  Future<void> _firebasePhoneLogin(
    String firebaseIdToken,
    Emitter emit,
  ) async {
    _viewModel = _viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: _viewModel));

    final result = await _authRepository.firebasePhoneLogin(
      firebaseIdToken: firebaseIdToken,
    );

    _viewModel = _viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        // If user not found, redirect to registration
        if (error.message.toLowerCase().contains('not found') ||
            error.message.toLowerCase().contains('user does not exist') ||
            error.message.toLowerCase().contains('no user') ||
            error.message.toLowerCase().contains('please register') ||
            error.message.toLowerCase().contains('register first')) {
          _viewModel = _viewModel.copyWith(
            firebaseIdToken: firebaseIdToken,
          );
          emit(AuthState.goRegister());
        } else {
          emit(AuthState.loadingFailure(error.message));
        }
      },
      (loginEntity) {
        _viewModel = _viewModel.copyWith(isLoggedIn: true);
        emit(AuthState.authenticated(loginEntity: loginEntity));
      },
    );
  }

  Future<void> _firebasePhoneRegister(
    String firebaseIdToken,
    String firstName,
    String lastName,
    String? dateOfBirth,
    String? referral,
    Emitter emit,
  ) async {
    _viewModel = _viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: _viewModel));

    final result = await _authRepository.firebasePhoneRegister(
      firebaseIdToken: firebaseIdToken,
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      referral: referral,
    );

    _viewModel = _viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (loginEntity) {
        _viewModel = _viewModel.copyWith(isLoggedIn: true);
        emit(AuthState.authenticated(loginEntity: loginEntity));
      },
    );
  }
}
