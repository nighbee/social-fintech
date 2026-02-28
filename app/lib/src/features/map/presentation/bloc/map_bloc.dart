import 'package:app/src/core/base/base_bloc/bloc/base_bloc.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/service/injectable/service_register_proxy.dart';
import 'package:app/src/features/map/data/repositories/map_repository_impl.dart';
import 'package:app/src/features/map/domain/repositories/i_map_repository.dart';
import 'package:app/src/features/map/domain/requests/map_create_task_request.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'map_bloc.freezed.dart';
part 'map_event.dart';
part 'map_state.dart';

class MapBloc extends BaseBloc<MapEvent, MapState> {
  MapBloc(@Named.from(MapRepositoryImpl) this._repository)
      : super(const _Initial());

  final IMapRepository _repository;
  MapViewModel _viewModel = const MapViewModel();
  MapViewModel get viewModel => _viewModel;

  @override
  Future<void> onEventHandler(MapEvent event, Emitter emit) async {
    await event.when(
      loadMap: () => _loadMap(event as _LoadMap, emit),
      createTask: (_, __, ___, ____, _____) =>
          _createTask(event as _CreateTask, emit),
    );
  }

  Future<void> _loadMap(_LoadMap event, Emitter emit) async {
    emit(MapState.loading(viewModel: _viewModel));
    final result = await _repository.getInitialCamera();

    result.fold(
      (error) => emit(MapState.loadingError(error.message)),
      (camera) {
        _viewModel = _viewModel.copyWith(
          centerLatitude: camera.centerLatitude,
          centerLongitude: camera.centerLongitude,
          zoom: camera.zoom,
        );
        emit(MapState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _createTask(_CreateTask event, Emitter emit) async {
    // Validate input
    if (event.title.trim().isEmpty) {
      _viewModel = _viewModel.copyWith(
        taskCreateError: 'Please enter a title',
      );
      emit(MapState.loaded(viewModel: _viewModel));
      return;
    }
    if (event.description.trim().isEmpty) {
      _viewModel = _viewModel.copyWith(
        taskCreateError: 'Please enter a description',
      );
      emit(MapState.loaded(viewModel: _viewModel));
      return;
    }

    _viewModel = _viewModel.copyWith(
      isCreatingTask: true,
      taskCreateError: null,
    );
    emit(MapState.loaded(viewModel: _viewModel));

    final result = await _repository.createTask(
      MapCreateTaskRequest(
        title: event.title,
        description: event.description,
        heroesCount: event.heroesCount,
        reward: event.reward,
        autoShutdown: event.autoShutdown,
      ),
    );

    result.fold(
      (error) {
        _viewModel = _viewModel.copyWith(
          isCreatingTask: false,
          taskCreateError: _mapCreateErrorMessage(error.message),
        );
        emit(MapState.loaded(viewModel: _viewModel));
      },
      (verificationCode) {
        _viewModel = _viewModel.copyWith(
          isCreatingTask: false,
          taskCreatedMessage:
              'Request created successfully. Code: $verificationCode',
        );
        emit(MapState.loaded(viewModel: _viewModel));
      },
    );
  }

  String _mapCreateErrorMessage(String rawMessage) {
    final message = rawMessage.trim().toLowerCase();

    if (message.contains('insufficient_funds')) {
      return 'Insufficient Silver Seals to create this task.';
    }
    if (message.contains('cooldown_active')) {
      return 'Task creation cooldown is active. Please try again later.';
    }
    if (message.contains('invalid_title')) {
      return 'Title is invalid.';
    }
    if (message.contains('invalid_reward')) {
      return 'Reward must be 1, 2 or 3.';
    }
    if (message.contains('invalid_workers')) {
      return 'Workers count must be between 1 and 20.';
    }
    if (message.contains('invalid_coordinates')) {
      return 'Coordinates are invalid.';
    }
    if (message.contains('validation_error')) {
      return 'Please check your task data.';
    }
    return rawMessage;
  }

  @override
  Future<void> close() {
    getIt.resetBloc(this);
    return super.close();
  }
}
