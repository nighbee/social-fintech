import 'package:app/src/core/service/injectable/service_register_proxy.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:app/src/core/base/base_bloc/bloc/base_bloc.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:app/src/features/auth/domain/entities/login_entity.dart';
import 'package:app/src/features/auth/domain/entities/user_search_entity.dart';
import 'package:app/src/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:app/src/features/auth/domain/requests/login_request.dart';
import 'package:app/src/features/auth/domain/requests/phone_code_request.dart';
import 'package:app/src/features/auth/domain/requests/register_request.dart';
import 'package:app/src/features/auth/domain/requests/search_users_request.dart';
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
      login: (_) => _login(event as _Login, emit),
      register: (_) => _register(event as _Register, emit),
      requestPhoneCode: (_) =>
          _requestPhoneCode(event as _RequestPhoneCode, emit),
      startPhoneVerification: (_) =>
          _startPhoneVerification(event as _StartPhoneVerification, emit),
      checkEmail: (_) => _checkEmail(event as _CheckEmail, emit),
      verifyOtpCode: (_, __, ___) =>
          _verifyOtpCode(event as _VerifyOtpCode, emit),
      sendEmailMagicLink: (_) =>
          _sendEmailMagicLink(event as _SendEmailMagicLink, emit),
      completeEmailMagicLink: (_) =>
          _completeEmailMagicLink(event as _CompleteEmailMagicLink, emit),
      searchUsers: (_) => _searchUsers(event as _SearchUsers, emit),
      logout: () => _logout(event as _Logout, emit),
    );
  }

  Future<void> _login(_Login event, Emitter emit) async {
    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final result = await _repository.login(event.request);

    viewModel = viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        final firebaseIdToken = event.request.maybeWhen(
          firebasePhone: (firebaseIdToken) => firebaseIdToken,
          firebaseEmail: (firebaseIdToken) => firebaseIdToken,
          orElse: () => null,
        );
        final firebaseAuthProvider = event.request.maybeWhen(
          firebasePhone: (_) => 'phone',
          firebaseEmail: (_) => 'email',
          orElse: () => null,
        );
        final socialProviderToken = error is SocialRegisterRequiredException
            ? error.providerToken
            : null;

        if ((firebaseIdToken != null || socialProviderToken != null) &&
            (error.message.toLowerCase().contains('not found') ||
                error.message.toLowerCase().contains('user does not exist') ||
                error.message.toLowerCase().contains('no user') ||
                error.message.toLowerCase().contains('please register') ||
                error.message.toLowerCase().contains('register first') ||
                error is SocialRegisterRequiredException)) {
          viewModel = viewModel.copyWith(
            firebaseIdToken: socialProviderToken ?? firebaseIdToken,
            firebaseAuthProvider:
                socialProviderToken != null ? 'social' : firebaseAuthProvider,
          );
          emit(AuthState.goRegister());
          return;
        }
        emit(AuthState.loadingFailure(error.message));
      },
      (loginEntity) {
        viewModel = viewModel.copyWith(isLoggedIn: true);
        emit(AuthState.authenticated(loginEntity: loginEntity));
      },
    );
  }

  Future<void> _register(_Register event, Emitter emit) async {
    final dateOfBirth = event.request.when(
      email: (_, __, ___, ____, dateOfBirth, _____) => dateOfBirth,
      phone: (_, __, ___, dateOfBirth, ____) => dateOfBirth,
      firebasePhone: (_, __, ___, dateOfBirth, ____) => dateOfBirth,
      firebaseEmail: (_, __, ___, dateOfBirth, ____) => dateOfBirth,
    );

    if (dateOfBirth.trim().isEmpty) {
      emit(const AuthState.loadingFailure('Date of birth is required'));
      return;
    }

    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final result = await _repository.register(event.request);

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

  Future<void> _checkEmail(_CheckEmail event, Emitter emit) async {
    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final result = await _repository.checkEmailExists(email: event.email);

    viewModel = viewModel.copyWith(isLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (exists) {
        viewModel = viewModel.copyWith(email: event.email);
        emit(AuthState.emailChecked(exists: exists, email: event.email));
      },
    );
  }

  Future<void> _requestPhoneCode(_RequestPhoneCode event, Emitter emit) async {
    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final result = await _repository.requestPhoneCode(event.request);

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

  Future<void> _logout(_Logout event, Emitter emit) async {
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

  Future<void> _startPhoneVerification(
    _StartPhoneVerification event,
    Emitter emit,
  ) async {
    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final result = await _repository.startPhoneVerification(
      phoneNumber: event.phoneNumber,
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
            phoneNumber: event.phoneNumber,
          ),
        );
      },
    );
  }

  Future<void> _verifyOtpCode(_VerifyOtpCode event, Emitter emit) async {
    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final tokenResult = await _repository.verifyOtpAndGetToken(
      verificationId: event.verificationId,
      code: event.code,
    );

    await tokenResult.fold(
      (error) async {
        viewModel = viewModel.copyWith(isLoading: false);
        emit(AuthState.loadingFailure(error.message));
      },
      (firebaseIdToken) async {
        if (event.isLogin) {
          await _login(
            _Login(
              request: LoginRequest.firebasePhone(
                firebaseIdToken: firebaseIdToken,
              ),
            ),
            emit,
          );
        } else {
          viewModel = viewModel.copyWith(
            isLoading: false,
            firebaseIdToken: firebaseIdToken,
            firebaseAuthProvider: 'phone',
          );
          emit(AuthState.goRegister());
        }
      },
    );
  }

  Future<void> _searchUsers(_SearchUsers event, Emitter emit) async {
    viewModel = viewModel.copyWith(
      isUserSearchLoading: true,
      userSearchResults: [],
    );
    emit(AuthState.loaded(viewModel: viewModel));

    final result = await _repository.searchUsers(
      firstName: event.request.firstName,
      lastName: event.request.lastName,
      limit: event.request.limit,
    );

    viewModel = viewModel.copyWith(isUserSearchLoading: false);
    result.fold(
      (error) {
        emit(AuthState.loadingFailure(error.message));
      },
      (users) {
        viewModel = viewModel.copyWith(userSearchResults: users);
        emit(AuthState.loaded(viewModel: viewModel));
      },
    );
  }

  Future<void> _sendEmailMagicLink(
    _SendEmailMagicLink event,
    Emitter emit,
  ) async {
    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final result = await _repository.sendEmailMagicLink(email: event.email);

    viewModel = viewModel.copyWith(isLoading: false, email: event.email);
    result.fold(
      (error) => emit(AuthState.loadingFailure(error.message)),
      (_) => emit(AuthState.magicLinkSent(email: event.email)),
    );
  }

  Future<void> _completeEmailMagicLink(
    _CompleteEmailMagicLink event,
    Emitter emit,
  ) async {
    viewModel = viewModel.copyWith(isLoading: true);
    emit(AuthState.loaded(viewModel: viewModel));

    final tokenResult = await _repository.completeEmailMagicLink(
      emailLink: event.emailLink,
    );

    await tokenResult.fold(
      (error) async {
        viewModel = viewModel.copyWith(isLoading: false);
        emit(AuthState.loadingFailure(error.message));
      },
      (firebaseIdToken) async {
        await _login(
          _Login(
            request: LoginRequest.firebaseEmail(firebaseIdToken: firebaseIdToken),
          ),
          emit,
        );
      },
    );
  }

  @override
  Future<void> close() {
    getIt.resetBloc(this);
    return super.close();
  }
}
