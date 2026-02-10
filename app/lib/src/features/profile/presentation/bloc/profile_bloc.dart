import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:app/src/core/base/base_bloc/bloc/base_bloc.dart';
import 'package:app/src/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:app/src/features/profile/domain/entities/ally_profile_entity.dart';
import 'package:app/src/features/profile/domain/entities/profile_entity.dart';
import 'package:app/src/features/profile/domain/repositories/i_profile_repository.dart';
import 'package:app/src/features/profile/domain/requests/user_id_request.dart';

part 'profile_bloc.freezed.dart';
part 'profile_event.dart';
part 'profile_state.dart';

@injectable
class ProfileBloc extends BaseBloc<ProfileEvent, ProfileState> {
  ProfileBloc(@Named.from(ProfileRepositoryImpl) this._repository)
    : super(_Initial());

  final IProfileRepository _repository;
  final ProfileViewModel _viewModel = ProfileViewModel();

  @override
  Future<void> onEventHandler(ProfileEvent event, Emitter emit) async {
    await event.when(
      loadProfile: () => _loadProfile(event as _LoadProfile, emit),
      loadPublicProfile: (userId) =>
          _loadPublicProfile(event as _LoadPublicProfile, emit),
      becomeAlly: (userId) => _becomeAlly(event as _BecomeAlly, emit),
      removeAlly: (userId) => _removeAlly(event as _RemoveAlly, emit),
      loadAllies: (userId) => _loadAllies(event as _LoadAllies, emit),
      loadCurrentUserAllies: () =>
          _loadCurrentUserAllies(event as _LoadCurrentUserAllies, emit),
      blockUser: (userId) => _blockUser(event as _BlockUser, emit),
      unblockUser: (userId) => _unblockUser(event as _UnblockUser, emit),
      restrictUser: (userId) => _restrictUser(event as _RestrictUser, emit),
      unrestrictUser: (userId) =>
          _unrestrictUser(event as _UnrestrictUser, emit),
      reportUser: (userId) => _reportUser(event as _ReportUser, emit),
    );
  }

  Future<void> _loadProfile(_LoadProfile event, Emitter emit) async {
    try {
      emit(ProfileState.loading(viewModel: _viewModel));
      final result = await _repository.getCurrentUser();

      result.fold(
        (error) => emit(ProfileState.loadingError(error.message)),
        (profile) => emit(
          ProfileState.loaded(viewModel: _viewModel.copyWith(profile: profile)),
        ),
      );
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    }
  }

  Future<void> _loadPublicProfile(
    _LoadPublicProfile event,
    Emitter emit,
  ) async {
    try {
      emit(ProfileState.loading(viewModel: _viewModel));
      final request = UserIdRequest(userId: event.userId);
      final result = await _repository.getPublicProfile(request);

      result.fold(
        (error) => emit(ProfileState.loadingError(error.message)),
        (profile) => emit(
          ProfileState.loaded(viewModel: _viewModel.copyWith(profile: profile)),
        ),
      );
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    }
  }

  Future<void> _becomeAlly(_BecomeAlly event, Emitter emit) async {
    try {
      final request = UserIdRequest(userId: event.userId);
      final result = await _repository.becomeAlly(request);

      result.fold(
        (error) => emit(ProfileState.loadingError(error.message)),
        (_) => emit(ProfileState.loaded(viewModel: _viewModel)),
      );
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    }
  }

  Future<void> _removeAlly(_RemoveAlly event, Emitter emit) async {
    try {
      final request = UserIdRequest(userId: event.userId);
      final result = await _repository.removeAlly(request);

      result.fold(
        (error) => emit(ProfileState.loadingError(error.message)),
        (_) => emit(ProfileState.loaded(viewModel: _viewModel)),
      );
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    }
  }

  Future<void> _loadAllies(_LoadAllies event, Emitter emit) async {
    try {
      emit(ProfileState.loading(viewModel: _viewModel));
      final request = UserIdRequest(userId: event.userId);
      final result = await _repository.getAllies(request);

      result.fold(
        (error) => emit(ProfileState.loadingError(error.message)),
        (allies) => emit(
          ProfileState.loaded(viewModel: _viewModel.copyWith(allies: allies)),
        ),
      );
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    }
  }

  Future<void> _loadCurrentUserAllies(
    _LoadCurrentUserAllies event,
    Emitter emit,
  ) async {
    try {
      emit(ProfileState.loading(viewModel: _viewModel));
      final request = UserIdRequest(
        userId: '5ff12d77-0c81-4b73-b168-85515b5d5180',
      );
      final result = await _repository.getAllies(request);

      result.fold(
        (error) => emit(ProfileState.loadingError(error.message)),
        (allies) => emit(
          ProfileState.loaded(viewModel: _viewModel.copyWith(allies: allies)),
        ),
      );
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    }
  }

  Future<void> _blockUser(_BlockUser event, Emitter emit) async {
    try {
      final request = UserIdRequest(userId: event.userId);
      final result = await _repository.blockUser(request);

      result.fold(
        (error) => emit(ProfileState.loadingError(error.message)),
        (_) => emit(ProfileState.loaded(viewModel: _viewModel)),
      );
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    }
  }

  Future<void> _unblockUser(_UnblockUser event, Emitter emit) async {
    try {
      final request = UserIdRequest(userId: event.userId);
      final result = await _repository.unblockUser(request);

      result.fold(
        (error) => emit(ProfileState.loadingError(error.message)),
        (_) => emit(ProfileState.loaded(viewModel: _viewModel)),
      );
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    }
  }

  Future<void> _restrictUser(_RestrictUser event, Emitter emit) async {
    try {
      final request = UserIdRequest(userId: event.userId);
      final result = await _repository.restrictUser(request);

      result.fold(
        (error) => emit(ProfileState.loadingError(error.message)),
        (_) => emit(ProfileState.loaded(viewModel: _viewModel)),
      );
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    }
  }

  Future<void> _unrestrictUser(_UnrestrictUser event, Emitter emit) async {
    try {
      final request = UserIdRequest(userId: event.userId);
      final result = await _repository.unrestrictUser(request);

      result.fold(
        (error) => emit(ProfileState.loadingError(error.message)),
        (_) => emit(ProfileState.loaded(viewModel: _viewModel)),
      );
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    }
  }

  Future<void> _reportUser(_ReportUser event, Emitter emit) async {
    try {
      final request = UserIdRequest(userId: event.userId);
      final result = await _repository.reportUser(request);

      result.fold(
        (error) => emit(ProfileState.loadingError(error.message)),
        (_) => emit(ProfileState.loaded(viewModel: _viewModel)),
      );
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    }
  }
}
