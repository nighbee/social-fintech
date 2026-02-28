import 'package:app/src/core/base/base_bloc/bloc/base_bloc.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/service/injectable/service_register_proxy.dart';
import 'package:app/src/features/map/data/repositories/map_repository_impl.dart';
import 'package:app/src/features/map/domain/entities/map_apply_to_task_entity.dart';
import 'package:app/src/features/map/domain/entities/map_champion_entity.dart';
import 'package:app/src/features/map/domain/entities/map_confirm_completion_entity.dart';
import 'package:app/src/features/map/domain/entities/map_region_assignment_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_application_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_entity.dart';
import 'package:app/src/features/map/domain/entities/map_verify_code_entity.dart';
import 'package:app/src/features/map/domain/repositories/i_map_repository.dart';
import 'package:app/src/features/map/domain/requests/map_champions_request.dart';
import 'package:app/src/features/map/domain/requests/map_create_task_request.dart';
import 'package:app/src/features/map/domain/requests/map_nearby_tasks_request.dart';
import 'package:app/src/features/map/domain/requests/map_region_assignment_request.dart';
import 'package:app/src/features/map/domain/requests/map_task_application_id_request.dart';
import 'package:app/src/features/map/domain/requests/map_task_id_request.dart';
import 'package:app/src/features/map/domain/requests/map_verify_code_request.dart';
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
      loadMap: () => _loadMap(emit),
      assignRegion: (_) => _assignRegion(event as _AssignRegion, emit),
      getChampions: (_) => _getChampions(event as _GetChampions, emit),
      createTask: (_) => _createTask(event as _CreateTask, emit),
      cancelTask: (_) => _cancelTask(event as _CancelTask, emit),
      applyToTask: (_) => _applyToTask(event as _ApplyToTask, emit),
      getNearbyTasks: (_) => _getNearbyTasks(event as _GetNearbyTasks, emit),
      getTaskApplications: (_) =>
          _getTaskApplications(event as _GetTaskApplications, emit),
      confirmTaskApplication: (_) =>
          _confirmTaskApplication(event as _ConfirmTaskApplication, emit),
      verifyTaskApplicationCode: (_, __) => _verifyTaskApplicationCode(
        event as _VerifyTaskApplicationCode,
        emit,
      ),
    );
  }

  Future<void> _loadMap(Emitter emit) async {
    _viewModel = _viewModel.copyWith(
      centerLatitude: 50.4501,
      centerLongitude: 30.5234,
      zoom: 11.8,
    );
    emit(MapState.loaded(viewModel: _viewModel));
  }

  Future<void> _assignRegion(_AssignRegion event, Emitter emit) async {
    _setBusy(emit);
    final result = await _repository.assignRegion(event.request);
    result.fold(
      (error) {
        _viewModel = _viewModel.copyWith(isBusy: false);
        emit(MapState.loadingError(error.message));
      },
      (entity) {
        _viewModel = _viewModel.copyWith(
          isBusy: false,
          assignedRegion: entity,
        );
        emit(MapState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _getChampions(_GetChampions event, Emitter emit) async {
    _setBusy(emit);
    final result = await _repository.getChampions(event.request);
    result.fold(
      (error) {
        _viewModel = _viewModel.copyWith(isBusy: false);
        emit(MapState.loadingError(error.message));
      },
      (items) {
        _viewModel = _viewModel.copyWith(
          isBusy: false,
          champions: items,
        );
        emit(MapState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _createTask(_CreateTask event, Emitter emit) async {
    if (event.request.title.trim().isEmpty) {
      emit(const MapState.loadingError('Please enter a title'));
      return;
    }
    if (event.request.description.trim().isEmpty) {
      emit(const MapState.loadingError('Please enter a description'));
      return;
    }

    _viewModel = _viewModel.copyWith(
      isCreatingTask: true,
    );
    emit(MapState.loaded(viewModel: _viewModel));

    final result = await _repository.createTask(event.request);
    result.fold(
      (error) {
        final message = _mapCreateErrorMessage(error.message);
        _viewModel = _viewModel.copyWith(
          isCreatingTask: false,
        );
        emit(MapState.loadingError(message));
      },
      (_) {
        _viewModel = _viewModel.copyWith(
          isCreatingTask: false,
        );
        emit(MapState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _cancelTask(_CancelTask event, Emitter emit) async {
    _setBusy(emit);
    final result = await _repository.cancelTask(event.request);
    result.fold(
      (error) {
        _viewModel = _viewModel.copyWith(isBusy: false);
        emit(MapState.loadingError(error.message));
      },
      (taskId) {
        _viewModel = _viewModel.copyWith(
          isBusy: false,
          cancelTaskResult: taskId,
        );
        emit(MapState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _applyToTask(_ApplyToTask event, Emitter emit) async {
    _setBusy(emit);
    final result = await _repository.applyToTask(event.request);
    result.fold(
      (error) {
        _viewModel = _viewModel.copyWith(isBusy: false);
        emit(MapState.loadingError(error.message));
      },
      (entity) {
        _viewModel = _viewModel.copyWith(
          isBusy: false,
          applyToTaskResult: entity,
        );
        emit(MapState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _getNearbyTasks(_GetNearbyTasks event, Emitter emit) async {
    _setBusy(emit);
    final result = await _repository.getNearbyTasks(event.request);
    result.fold(
      (error) {
        _viewModel = _viewModel.copyWith(isBusy: false);
        emit(MapState.loadingError(error.message));
      },
      (items) {
        _viewModel = _viewModel.copyWith(
          isBusy: false,
          nearbyTasks: items,
        );
        emit(MapState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _getTaskApplications(
    _GetTaskApplications event,
    Emitter emit,
  ) async {
    _setBusy(emit);
    final result = await _repository.getTaskApplications(event.request);
    result.fold(
      (error) {
        _viewModel = _viewModel.copyWith(isBusy: false);
        emit(MapState.loadingError(error.message));
      },
      (items) {
        _viewModel = _viewModel.copyWith(
          isBusy: false,
          taskApplications: items,
        );
        emit(MapState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _confirmTaskApplication(
    _ConfirmTaskApplication event,
    Emitter emit,
  ) async {
    _setBusy(emit);
    final result = await _repository.confirmTaskApplication(event.request);
    result.fold(
      (error) {
        _viewModel = _viewModel.copyWith(isBusy: false);
        emit(MapState.loadingError(error.message));
      },
      (entity) {
        _viewModel = _viewModel.copyWith(
          isBusy: false,
          confirmCompletionResult: entity,
        );
        emit(MapState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _verifyTaskApplicationCode(
    _VerifyTaskApplicationCode event,
    Emitter emit,
  ) async {
    _setBusy(emit);
    final result = await _repository.verifyTaskApplicationCode(
      event.target,
      event.request,
    );
    result.fold(
      (error) {
        _viewModel = _viewModel.copyWith(isBusy: false);
        emit(MapState.loadingError(error.message));
      },
      (entity) {
        _viewModel = _viewModel.copyWith(
          isBusy: false,
          verifyCodeResult: entity,
        );
        emit(MapState.loaded(viewModel: _viewModel));
      },
    );
  }

  void _setBusy(Emitter emit) {
    _viewModel = _viewModel.copyWith(
      isBusy: true,
    );
    emit(MapState.loaded(viewModel: _viewModel));
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
