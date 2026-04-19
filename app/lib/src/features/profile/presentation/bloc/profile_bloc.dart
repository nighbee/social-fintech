import 'dart:async';
import 'dart:typed_data';
import 'package:app/src/core/service/injectable/service_register_proxy.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/features/profile/domain/entities/relationship_status_entity.dart';
import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:app/src/core/base/base_bloc/bloc/base_bloc.dart';
import 'package:app/src/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:app/src/features/profile/domain/entities/ally_profile_entity.dart';
import 'package:app/src/features/profile/domain/entities/profile_entity.dart';
import 'package:app/src/features/profile/domain/entities/public_profile_entity.dart';
import 'package:app/src/features/profile/domain/repositories/i_profile_repository.dart';
import 'package:app/src/features/profile/domain/requests/update_profile_request.dart';
import 'package:app/src/features/profile/domain/requests/user_id_request.dart';

part 'profile_bloc.freezed.dart';
part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends BaseBloc<ProfileEvent, ProfileState> {
  ProfileBloc(@Named.from(ProfileRepositoryImpl) this._repository)
      : super(_Initial());

  final IProfileRepository _repository;
  ProfileViewModel _viewModel = ProfileViewModel();
  bool _isProfileLoadInProgress = false;

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
      loadRelationship: (userId) =>
          _loadRelationship(event as _LoadRelationship, emit),
      updateProfile: (request) => _updateProfile(event as _UpdateProfile, emit),
      updateProfilePhoto: (bytes, name) =>
          _updateProfilePhoto(event as _UpdateProfilePhoto, emit),
      logout: () => _logout(emit),
    );
  }

  Future<void> _updateProfilePhoto(
    _UpdateProfilePhoto event,
    Emitter emit,
  ) async {
    try {
      emit(ProfileState.loading(viewModel: _viewModel));

      final FormData formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          event.fileAsBytes,
          filename: event.fileName,
        ),
      });

      final result = await _repository.uploadAvatar(formData);

      await result.fold(
        (error) async {
          if (emit.isDone) return;
          emit(ProfileState.loadingError(error.message));
        },
        (profile) async {
          final previousAvatarUrl = _viewModel.profile.avatarUrl;
          _viewModel = _viewModel.copyWith(profile: profile);

          await _evictAvatarCache(previousAvatarUrl);
          await _evictAvatarCache(profile.avatarUrl);

          if (emit.isDone) return;
          emit(ProfileState.loaded(viewModel: _viewModel));
        },
      );
    } catch (e) {
      if (emit.isDone) return;
      emit(ProfileState.loadingError(e.toString()));
    }
  }

  Future<void> _evictAvatarCache(String url) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) return;

    await NetworkImage(normalizedUrl).evict();

    if (normalizedUrl.contains('localhost')) {
      await NetworkImage(
        normalizedUrl.replaceAll('localhost', '10.0.2.2'),
      ).evict();
    }
  }

  Future<void> _loadProfile(_LoadProfile event, Emitter emit) async {
    if (_isProfileLoadInProgress) return;
    _isProfileLoadInProgress = true;
    try {
      emit(ProfileState.loading(viewModel: _viewModel));
      final result = await _repository.getCurrentUser().timeout(
            const Duration(seconds: 15),
          );

      result.fold((error) => emit(ProfileState.loadingError(error.message)), (
        profile,
      ) {
        _viewModel = _viewModel.copyWith(profile: profile);
        emit(ProfileState.loaded(viewModel: _viewModel));
      });
    } on TimeoutException {
      emit(
        const ProfileState.loadingError(
          'Profile loading timeout. Please try again.',
        ),
      );
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    } finally {
      _isProfileLoadInProgress = false;
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

      result.fold((error) => emit(ProfileState.loadingError(error.message)), (
        publicProfile,
      ) {
        _viewModel = _viewModel.copyWith(publicProfile: publicProfile);
        emit(ProfileState.loaded(viewModel: _viewModel));
      });
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    }
  }

  Future<void> _becomeAlly(_BecomeAlly event, Emitter emit) async {
    try {
      final request = UserIdRequest(userId: event.userId);
      final result = await _repository.becomeAlly(request);

      final followResult = result.fold((error) => error, (_) => null);

      if (followResult != null) {
        emit(ProfileState.loadingError(followResult.message));
        return;
      }

      // Reload relationship status after successful follow
      final relationshipResult = await _repository.getRelationship(request);
      relationshipResult.fold(
        (error) => emit(ProfileState.loadingError(error.message)),
        (relationship) {
          _viewModel = _viewModel.copyWith(relationshipStatus: relationship);
          emit(ProfileState.loaded(viewModel: _viewModel));
        },
      );
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    }
  }

  Future<void> _removeAlly(_RemoveAlly event, Emitter emit) async {
    try {
      final request = UserIdRequest(userId: event.userId);
      final result = await _repository.removeAlly(request);

      final removeResult = result.fold((error) => error, (_) => null);

      if (removeResult != null) {
        emit(ProfileState.loadingError(removeResult.message));
        return;
      }

      // Reload relationship status after successful remove
      final relationshipResult = await _repository.getRelationship(request);
      relationshipResult.fold(
        (error) => emit(ProfileState.loadingError(error.message)),
        (relationship) {
          _viewModel = _viewModel.copyWith(relationshipStatus: relationship);
          emit(ProfileState.loaded(viewModel: _viewModel));
        },
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

      result.fold((error) => emit(ProfileState.loadingError(error.message)), (
        allies,
      ) {
        _viewModel = _viewModel.copyWith(allies: allies);
        emit(ProfileState.loaded(viewModel: _viewModel));
      });
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

      result.fold((error) => emit(ProfileState.loadingError(error.message)), (
        allies,
      ) {
        _viewModel = _viewModel.copyWith(allies: allies);
        emit(ProfileState.loaded(viewModel: _viewModel));
      });
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    }
  }

  Future<void> _blockUser(_BlockUser event, Emitter emit) async {
    try {
      final request = UserIdRequest(userId: event.userId);
      final result = await _repository.blockUser(request);

      final blockResult = result.fold((error) => error, (_) => null);

      if (blockResult != null) {
        emit(ProfileState.loadingError(blockResult.message));
        return;
      }

      // Reload relationship status after successful block
      final relationshipResult = await _repository.getRelationship(request);
      relationshipResult.fold(
        (error) => emit(ProfileState.loadingError(error.message)),
        (relationship) {
          _viewModel = _viewModel.copyWith(relationshipStatus: relationship);
          emit(ProfileState.loaded(viewModel: _viewModel));
        },
      );
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    }
  }

  Future<void> _unblockUser(_UnblockUser event, Emitter emit) async {
    try {
      final request = UserIdRequest(userId: event.userId);
      final result = await _repository.unblockUser(request);

      final unblockResult = result.fold((error) => error, (_) => null);

      if (unblockResult != null) {
        emit(ProfileState.loadingError(unblockResult.message));
        return;
      }

      // Reload relationship status after successful unblock
      final relationshipResult = await _repository.getRelationship(request);
      relationshipResult.fold(
        (error) => emit(ProfileState.loadingError(error.message)),
        (relationship) {
          _viewModel = _viewModel.copyWith(relationshipStatus: relationship);
          emit(ProfileState.loaded(viewModel: _viewModel));
        },
      );
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    }
  }

  Future<void> _restrictUser(_RestrictUser event, Emitter emit) async {
    try {
      final request = UserIdRequest(userId: event.userId);
      final result = await _repository.restrictUser(request);

      final restrictResult = result.fold((error) => error, (_) => null);

      if (restrictResult != null) {
        emit(ProfileState.loadingError(restrictResult.message));
        return;
      }

      // Reload relationship status after successful restrict
      final relationshipResult = await _repository.getRelationship(request);
      relationshipResult.fold(
        (error) => emit(ProfileState.loadingError(error.message)),
        (relationship) {
          _viewModel = _viewModel.copyWith(relationshipStatus: relationship);
          emit(ProfileState.loaded(viewModel: _viewModel));
        },
      );
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    }
  }

  Future<void> _unrestrictUser(_UnrestrictUser event, Emitter emit) async {
    try {
      final request = UserIdRequest(userId: event.userId);
      final result = await _repository.unrestrictUser(request);

      final unrestrictResult = result.fold((error) => error, (_) => null);

      if (unrestrictResult != null) {
        emit(ProfileState.loadingError(unrestrictResult.message));
        return;
      }

      // Reload relationship status after successful unrestrict
      final relationshipResult = await _repository.getRelationship(request);
      relationshipResult.fold(
        (error) => emit(ProfileState.loadingError(error.message)),
        (relationship) {
          _viewModel = _viewModel.copyWith(relationshipStatus: relationship);
          emit(ProfileState.loaded(viewModel: _viewModel));
        },
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

  Future<void> _loadRelationship(_LoadRelationship event, Emitter emit) async {
    try {
      final request = UserIdRequest(userId: event.userId);
      final result = await _repository.getRelationship(request);

      result.fold((error) => emit(ProfileState.loadingError(error.message)), (
        relationship,
      ) {
        _viewModel = _viewModel.copyWith(relationshipStatus: relationship);
        emit(ProfileState.loaded(viewModel: _viewModel));
      });
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    }
  }

  Future<void> _updateProfile(_UpdateProfile event, Emitter emit) async {
    try {
      final result = await _repository.updateProfile(event.request);

      result.fold((error) => emit(ProfileState.loadingError(error.message)), (
        profile,
      ) {
        _viewModel = _viewModel.copyWith(profile: profile);
        emit(ProfileState.loaded(viewModel: _viewModel));
      });
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    }
  }

  Future<void> _logout(Emitter emit) async {
    _isProfileLoadInProgress = false;
    _viewModel = ProfileViewModel();
    emit(ProfileState.initial());
  }

  @override
  Future<void> close() {
    getIt.resetBloc(this);
    return super.close();
  }
}
