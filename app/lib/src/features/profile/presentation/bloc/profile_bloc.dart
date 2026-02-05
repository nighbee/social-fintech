import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:app/src/core/base/base_bloc/bloc/base_bloc.dart';
import 'package:app/src/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:app/src/features/profile/domain/entities/user.dart';
import 'package:app/src/features/profile/domain/repositories/i_profile_repository.dart';

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
    );
  }

  Future<void> _loadProfile(_LoadProfile event, Emitter emit) async {
    try {
      emit(ProfileState.loading(viewModel: _viewModel));
      final result = await _repository.getCurrentUser();

      result.fold(
        (error) => emit(ProfileState.loadingError(error.message)),
        (user) => emit(
          ProfileState.loaded(viewModel: _viewModel.copyWith(user: user)),
        ),
      );
    } catch (e) {
      emit(ProfileState.loadingError(e.toString()));
    }
  }
}
