import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:app/src/core/base/base_bloc/bloc/base_bloc.dart';
import 'package:app/src/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:app/src/features/auth/domain/entities/login_entity.dart';
import 'package:app/src/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';

part 'auth_bloc.freezed.dart';
part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends BaseBloc<AuthEvent, AuthState> {
  AuthBloc(@Named.from(AuthRepositoryImpl) this._repository)
    : super(const _Initial());

  final IAuthRepository _repository;
  AuthViewModel viewModel = AuthViewModel();

  @override
  Future<void> onEventHandler(AuthEvent event, Emitter emit) async {
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
      firebasePhoneRegister:
          (firebaseIdToken, firstName, lastName, dateOfBirth, referral) =>
              _firebasePhoneRegister(
                firebaseIdToken,
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
    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final result = await _repository.loginWithEmail(
      email: email,
      password: password,
    );

    viewModel = viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (loginEntity) {
        viewModel = viewModel.copyWith(isLoggedIn: true);
        emit(AuthState.authenticated(loginEntity: loginEntity));
      },
    );
  }

  Future<void> _loginWithGoogle(Emitter emit) async {
    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final result = await _repository.loginWithGoogle();

    viewModel = viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (loginEntity) {
        viewModel = viewModel.copyWith(isLoggedIn: true);
        emit(AuthState.authenticated(loginEntity: loginEntity));
      },
    );
  }

  Future<void> _loginWithApple(Emitter emit) async {
    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final result = await _repository.loginWithApple();

    viewModel = viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (loginEntity) {
        viewModel = viewModel.copyWith(isLoggedIn: true);
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
    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final result = await _repository.registerWithEmail(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      referral: referral,
    );

    viewModel = viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (loginEntity) {
        viewModel = viewModel.copyWith(isLoggedIn: true);
        emit(AuthState.authenticated(loginEntity: loginEntity));
      },
    );
  }

  Future<void> _checkEmail(String email, Emitter emit) async {
    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final result = await _repository.checkEmailExists(email: email);

    viewModel = viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (exists) {
        viewModel = viewModel.copyWith(email: email);
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
    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final result = await _repository.requestPhoneCode(
      countryCode: countryCode,
      phoneNumber: phoneNumber,
      purpose: purpose,
    );

    viewModel = viewModel.copyWith(isLoading: false);
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
    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final result = await _repository.verifyPhoneCode(
      verificationId: verificationId,
      code: code,
    );

    viewModel = viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (loginEntity) {
        viewModel = viewModel.copyWith(isLoggedIn: true);
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
    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final result = await _repository.registerWithPhone(
      verificationId: verificationId,
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      referral: referral,
    );

    viewModel = viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (loginEntity) {
        viewModel = viewModel.copyWith(isLoggedIn: true);
        emit(AuthState.authenticated(loginEntity: loginEntity));
      },
    );
  }

  Future<void> _logout(Emitter emit) async {
    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final result = await _repository.logout();

    viewModel = viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (_) {
        getIt<ProfileBloc>().add(const ProfileEvent.logout());
        viewModel = viewModel.copyWith(isLoggedIn: false);
        emit(AuthState.loaded(viewModel: viewModel));
      },
    );
  }

  Future<void> _startPhoneVerification(String phoneNumber, Emitter emit) async {
    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final result = await _repository.startPhoneVerification(
      phoneNumber: phoneNumber,
    );

    viewModel = viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (verificationId) {
        emit(
          AuthState.phoneVerificationStarted(
            verificationId: verificationId,
            phoneNumber: phoneNumber,
          ),
        );
      },
    );
  }

  Future<void> _verifyOtpCode(
    String verificationId,
    String code,
    bool isLogin,
    Emitter emit,
  ) async {
    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final tokenResult = await _repository.verifyOtpAndGetToken(
      verificationId: verificationId,
      code: code,
    );

    await tokenResult.fold(
      (error) async {
        viewModel = viewModel.copyWith(isLoading: false);
        emit(AuthState.loadingFailure(error.message));
      },
      (firebaseIdToken) async {
        if (isLogin) {
          await _firebasePhoneLogin(firebaseIdToken, emit);
        } else {
          viewModel = viewModel.copyWith(
            isLoading: false,
            firebaseIdToken: firebaseIdToken,
          );
          emit(AuthState.goRegister());
        }
      },
    );
  }

  Future<void> _firebasePhoneLogin(String firebaseIdToken, Emitter emit) async {
    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final result = await _repository.firebasePhoneLogin(
      firebaseIdToken: firebaseIdToken,
    );

    viewModel = viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        // If user not found, redirect to registration
        if (error.message.toLowerCase().contains('not found') ||
            error.message.toLowerCase().contains('user does not exist') ||
            error.message.toLowerCase().contains('no user') ||
            error.message.toLowerCase().contains('please register') ||
            error.message.toLowerCase().contains('register first')) {
          viewModel = viewModel.copyWith(firebaseIdToken: firebaseIdToken);
          emit(AuthState.goRegister());
        } else {
          emit(AuthState.loadingFailure(error.message));
        }
      },
      (loginEntity) {
        viewModel = viewModel.copyWith(isLoggedIn: true);
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
    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final result = await _repository.firebasePhoneRegister(
      firebaseIdToken: firebaseIdToken,
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      referral: referral,
    );

    viewModel = viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (loginEntity) {
        viewModel = viewModel.copyWith(isLoggedIn: true);
        emit(AuthState.authenticated(loginEntity: loginEntity));
      },
    );
  }
}
