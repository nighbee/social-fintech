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
}

// MARK: - ViewModel
@freezed
class AuthViewModel with _$AuthViewModel {
  factory AuthViewModel({
    @Default(false) bool isLoading,
    @Default(false) bool isLoggedIn,
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
    String? dateOfBirth,
    String? referral,
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
                dateOfBirth,
                referral,
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
    String? dateOfBirth,
    String? referral,
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
}
