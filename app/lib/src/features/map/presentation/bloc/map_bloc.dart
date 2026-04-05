import 'package:app/src/core/base/base_bloc/bloc/base_bloc.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/service/injectable/service_register_proxy.dart';
import 'package:app/src/features/map/data/demo/map_demo_config.dart';
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
      getRegionalChampions: () =>
          _getRegionalChampions(emit),
      createTask: (_) => _createTask(event as _CreateTask, emit),
      cancelTask: (_) => _cancelTask(event as _CancelTask, emit),
      applyToTask: (_) => _applyToTask(event as _ApplyToTask, emit),
      getNearbyTasks: (_) => _getNearbyTasks(event as _GetNearbyTasks, emit),
      getAppliedTasks: () => _getAppliedTasks(emit),
      getMyTasks: () => _getMyTasks(emit),
      getTaskById: (_) => _getTaskById(event as _GetTaskById, emit),
      hydrateExecutorApplication: (_) => _hydrateExecutorApplication(
        event as _HydrateExecutorApplication,
        emit,
      ),
      getTaskApplications: (_) =>
          _getTaskApplications(event as _GetTaskApplications, emit),
      acceptTaskApplication: (_) =>
          _acceptTaskApplication(event as _AcceptTaskApplication, emit),
      rejectTaskApplication: (_) =>
          _rejectTaskApplication(event as _RejectTaskApplication, emit),
      withdrawTaskApplication: (_) =>
          _withdrawTaskApplication(event as _WithdrawTaskApplication, emit),
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
      centerLatitude:
          mapDemoMocksEnabled ? mapDemoAlmatyLatitude : 50.4501,
      centerLongitude:
          mapDemoMocksEnabled ? mapDemoAlmatyLongitude : 30.5234,
      zoom: 11.8,
      cancelTaskResult: '',
      applyToTaskResult: const MapApplyToTaskEntity.empty(),
      confirmCompletionResult: const MapConfirmCompletionEntity.empty(),
      verifyCodeResult: const MapVerifyCodeEntity.empty(),
      taskApplicationActionResult: '',
      hasAppliedTasksLoaded: false,
      hasMyTasksLoaded: false,
      assignedRegion: const MapRegionAssignmentEntity.empty(),
      champions: const <MapChampionEntity>[],
    );
    emit(MapState.loaded(viewModel: _viewModel));
    if (mapDemoMocksEnabled) {
      add(const MapEvent.getRegionalChampions());
    }
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
        add(const MapEvent.getRegionalChampions());
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

  Future<void> _getRegionalChampions(Emitter emit) async {
    final region = _viewModel.assignedRegion;
    final hasAny = region.h3Res5.isNotEmpty ||
        region.h3Res4.isNotEmpty ||
        region.h3Res2.isNotEmpty;
    if (!hasAny) {
      // Без региона API не вызывается — в debug подмешиваем демо-чемпиона из репозитория.
      if (!mapDemoMocksEnabled) {
        return;
      }
      _setBusy(emit);
      final demoResult = await _repository.getChampionsMergedForRegion(
        const MapRegionAssignmentEntity.empty(),
      );
      demoResult.fold(
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
      return;
    }
    _setBusy(emit);
    final result = await _repository.getChampionsMergedForRegion(region);
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
    if (event.request.reward < 1 || event.request.reward > 3) {
      emit(const MapState.loadingError('Reward must be 1, 2 or 3.'));
      return;
    }
    if (event.request.heroesCount < 1 || event.request.heroesCount > 20) {
      emit(const MapState.loadingError('Workers count must be between 1 and 20.'));
      return;
    }
    if (!event.request.latitude.isFinite || !event.request.longitude.isFinite) {
      emit(const MapState.loadingError('Coordinates are invalid.'));
      return;
    }

    _viewModel = _viewModel.copyWith(
      isCreatingTask: true,
    );
    emit(MapState.loaded(viewModel: _viewModel));

    final result = await _repository.createTask(event.request);
    await result.fold(
      (error) async {
        final message = _mapCreateErrorMessage(error.message);
        _viewModel = _viewModel.copyWith(
          isCreatingTask: false,
        );
        emit(MapState.loadingError(message));
      },
      (createdTask) async {
        final myTask = createdTask;
        _viewModel = _viewModel.copyWith(
          isCreatingTask: false,
          myTasks: [
            myTask,
            ..._viewModel.myTasks.where((task) => task.id != myTask.id),
          ],
          nearbyTasks: [
            myTask,
            ..._viewModel.nearbyTasks.where((task) => task.id != myTask.id),
          ],
        );
        emit(MapState.loaded(viewModel: _viewModel));

        // Refresh nearby tasks after creation using current map center
        final nearbyResult = await _repository.getNearbyTasks(
          MapNearbyTasksRequest(
            lat: event.request.latitude,
            lon: event.request.longitude,
            radiusM: 2000,
            limit: 50,
          ),
        );

        nearbyResult.fold(
          (error) {
            // Silently handle error - task was created successfully
          },
          (tasks) {
            _viewModel = _viewModel.copyWith(
              nearbyTasks: [
                myTask,
                ...tasks.where((task) => task.id != myTask.id),
              ],
            );
            emit(MapState.loaded(viewModel: _viewModel));
          },
        );
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
        final filteredTasks = _viewModel.nearbyTasks
            .where((task) => task.id != event.request.taskId)
            .toList();
        final filteredMyTasks = _viewModel.myTasks
            .where((task) => task.id != event.request.taskId)
            .toList();
        _viewModel = _viewModel.copyWith(
          isBusy: false,
          cancelTaskResult: taskId,
          nearbyTasks: filteredTasks,
          myTasks: filteredMyTasks,
          taskApplications: const <MapTaskApplicationEntity>[],
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
          taskApplicationActionResult: '',
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

  Future<void> _getAppliedTasks(Emitter emit) async {
    _setBusy(emit);
    final result = await _repository.getAppliedTasks();
    result.fold(
      (error) {
        _viewModel = _viewModel.copyWith(
          isBusy: false,
          hasAppliedTasksLoaded: false,
        );
        emit(MapState.loadingError(error.message));
      },
      (items) {
        _viewModel = _viewModel.copyWith(
          isBusy: false,
          appliedTasks: items,
          hasAppliedTasksLoaded: true,
        );
        emit(MapState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _getMyTasks(Emitter emit) async {
    _setBusy(emit);
    final result = await _repository.getMyTasks();
    result.fold(
      (error) {
        _viewModel = _viewModel.copyWith(
          isBusy: false,
          hasMyTasksLoaded: false,
        );
        emit(MapState.loadingError(error.message));
      },
      (items) {
        // Backend can lag for a short time and miss freshly created local mine| task.
        // Keep local active mine tasks until backend catches up.
        final mergedById = <String, MapTaskEntity>{
          for (final t in items) t.id: t,
        };
        for (final local in _viewModel.myTasks) {
          final status = local.status.trim().toLowerCase();
          final isLocalMine = status.startsWith('mine|');
          final isClosed = status == 'completed' || status == 'cancelled';
          if (isLocalMine && !isClosed && !mergedById.containsKey(local.id)) {
            mergedById[local.id] = local;
          }
        }
        _viewModel = _viewModel.copyWith(
          isBusy: false,
          myTasks: mergedById.values.toList(growable: false),
          hasMyTasksLoaded: true,
        );
        emit(MapState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _getTaskById(_GetTaskById event, Emitter emit) async {
    _setBusy(emit);
    final result = await _repository.getTaskById(event.request);
    result.fold(
      (error) {
        _viewModel = _viewModel.copyWith(isBusy: false);
        emit(MapState.loadingError(error.message));
      },
      (item) {
        _viewModel = _viewModel.copyWith(
          isBusy: false,
          selectedTask: item,
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

  Future<void> _hydrateExecutorApplication(
    _HydrateExecutorApplication event,
    Emitter emit,
  ) async {
    _viewModel = _viewModel.copyWith(
      applyToTaskResult: MapApplyToTaskEntity(
        applicationId: event.request.applicationId,
        taskId: event.request.taskId,
        status: 'pending',
      ),
    );
    emit(MapState.loaded(viewModel: _viewModel));
  }

  Future<void> _acceptTaskApplication(
    _AcceptTaskApplication event,
    Emitter emit,
  ) async {
    _viewModel = _viewModel.copyWith(taskApplicationActionResult: '');
    _setBusy(emit);
    final result = await _repository.acceptTaskApplication(event.request);
    result.fold(
      (error) {
        _viewModel = _viewModel.copyWith(isBusy: false);
        emit(MapState.loadingError(error.message));
      },
      (status) {
        _viewModel = _viewModel.copyWith(
          isBusy: false,
          taskApplicationActionResult: status,
        );
        emit(MapState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _rejectTaskApplication(
    _RejectTaskApplication event,
    Emitter emit,
  ) async {
    _viewModel = _viewModel.copyWith(taskApplicationActionResult: '');
    _setBusy(emit);
    final result = await _repository.rejectTaskApplication(event.request);
    result.fold(
      (error) {
        _viewModel = _viewModel.copyWith(isBusy: false);
        emit(MapState.loadingError(error.message));
      },
      (status) {
        _viewModel = _viewModel.copyWith(
          isBusy: false,
          taskApplicationActionResult: status,
        );
        emit(MapState.loaded(viewModel: _viewModel));
      },
    );
  }

  Future<void> _withdrawTaskApplication(
    _WithdrawTaskApplication event,
    Emitter emit,
  ) async {
    _viewModel = _viewModel.copyWith(taskApplicationActionResult: '');
    _setBusy(emit);
    final result = await _repository.withdrawTaskApplication(event.request);
    result.fold(
      (error) {
        _viewModel = _viewModel.copyWith(isBusy: false);
        emit(MapState.loadingError(error.message));
      },
      (status) {
        _viewModel = _viewModel.copyWith(
          isBusy: false,
          taskApplicationActionResult: status,
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
        final taskIdToRemove = event.request.taskId;
        final filteredTasks = _viewModel.nearbyTasks
            .where((task) => task.id != taskIdToRemove)
            .toList();
        final filteredMyTasks = _viewModel.myTasks
            .where((task) => task.id != taskIdToRemove)
            .toList();
        _viewModel = _viewModel.copyWith(
          isBusy: false,
          confirmCompletionResult: entity,
          nearbyTasks: filteredTasks,
          myTasks: filteredMyTasks,
          taskApplications: const <MapTaskApplicationEntity>[],
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
    if (message.contains('task_create_failed')) {
      return 'Could not create the task right now. Please try again in a minute.';
    }
    if (message.contains('invalid_body')) {
      return 'Invalid request. Please try again.';
    }
    if (message.contains('unauthorized')) {
      return 'Session expired. Please sign in again and retry.';
    }
    return rawMessage;
  }

  @override
  Future<void> close() {
    getIt.resetBloc(this);
    return super.close();
  }
}
