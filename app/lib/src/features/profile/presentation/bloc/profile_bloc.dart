import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

import 'package:app/src/core/base/base_bloc/bloc/base_bloc.dart';
import 'package:app/src/features/profile/data/repos/profile_repo_impl.dart';
import 'package:app/src/features/profile/domain/entities/user.dart';
import 'package:app/src/features/profile/domain/repos/i_profile_repo.dart';

part 'profile_bloc.freezed.dart';
part 'profile_event.dart';
part 'profile_state.dart';

@injectable
class ProfileBloc extends BaseBloc<ProfileEvent, ProfileState> {
  ProfileBloc(@Named.from(ProfileRepositoryImpl) this._repository)
    : super(const _Initial());

  final IProfileRepo _repository;

  @override
  Future<void> onEventHandler(ProfileEvent event, Emitter emit) async {
    await event.when(loadProfile: () => _loadProfile(emit));
  }

  Future<void> _loadProfile(Emitter emit) async {
    try {
      emit(const _Loading());
      final result = await _repository.getProfile();

      result.fold(
        (error) => emit(_LoadingError(error.message)),
        (User user) => emit(_Loaded(user: user)),
      );
    } catch (e) {
      emit(_LoadingError(e.toString()));
    }
  }
}
