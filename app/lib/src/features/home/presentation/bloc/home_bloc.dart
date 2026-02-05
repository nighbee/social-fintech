import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:app/src/core/base/base_bloc/bloc/base_bloc.dart';
import 'package:app/src/features/home/data/repositories/home_repository_impl.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';
import 'package:app/src/features/home/domain/repositories/i_home_repository.dart';

part 'home_bloc.freezed.dart';
part 'home_event.dart';
part 'home_state.dart';

@injectable
class HomeBloc extends BaseBloc<HomeEvent, HomeState> {
  HomeBloc(@Named.from(HomeRepositoryImpl) this._repository)
    : super(const _Initial());

  final IHomeRepository _repository;
  HomeViewModel _viewModel = HomeViewModel();

  @override
  Future<void> onEventHandler(HomeEvent event, Emitter emit) async {
    await event.when(loadPosts: () => _loadPosts(event as _LoadPosts, emit));
  }

  Future<void> _loadPosts(_LoadPosts event, Emitter emit) async {
    try {
      emit(HomeState.loading(viewModel: _viewModel));
      final result = await _repository.getPosts();

      result.fold(
        (error) => emit(HomeState.loadingError(error.message)),
        (posts) => emit(
          HomeState.loaded(viewModel: _viewModel.copyWith(posts: posts)),
        ),
      );
    } catch (e) {
      emit(HomeState.loadingError(e.toString()));
    }
  }
}
