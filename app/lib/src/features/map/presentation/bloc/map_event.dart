part of 'map_bloc.dart';

@freezed
class MapEvent with _$MapEvent {
  const factory MapEvent.loadMap() = _LoadMap;
  const factory MapEvent.assignRegion(MapRegionAssignmentRequest request) =
      _AssignRegion;
  const factory MapEvent.getChampions(MapChampionsRequest request) =
      _GetChampions;
  /// Чемпионы district + city + country (разные resolution в БД).
  const factory MapEvent.getRegionalChampions() = _GetRegionalChampions;
  const factory MapEvent.createTask(MapCreateTaskRequest request) = _CreateTask;
  const factory MapEvent.cancelTask(MapTaskIdRequest request) = _CancelTask;
  const factory MapEvent.applyToTask(MapTaskIdRequest request) = _ApplyToTask;
  const factory MapEvent.getNearbyTasks(MapNearbyTasksRequest request) =
      _GetNearbyTasks;
  const factory MapEvent.getAppliedTasks() = _GetAppliedTasks;
  const factory MapEvent.getMyTasks() = _GetMyTasks;
  const factory MapEvent.getTaskById(MapTaskIdRequest request) = _GetTaskById;
  const factory MapEvent.hydrateExecutorApplication(
    MapTaskApplicationIdRequest request,
  ) = _HydrateExecutorApplication;
  const factory MapEvent.getTaskApplications(MapTaskIdRequest request) =
      _GetTaskApplications;
  const factory MapEvent.acceptTaskApplication(
    MapTaskApplicationIdRequest request,
  ) = _AcceptTaskApplication;
  const factory MapEvent.rejectTaskApplication(
    MapTaskApplicationIdRequest request,
  ) = _RejectTaskApplication;
  const factory MapEvent.withdrawTaskApplication(
    MapTaskApplicationIdRequest request,
  ) = _WithdrawTaskApplication;
  const factory MapEvent.confirmTaskApplication(
    MapTaskApplicationIdRequest request,
  ) = _ConfirmTaskApplication;
  const factory MapEvent.verifyTaskApplicationCode(
    MapTaskApplicationIdRequest target,
    MapVerifyCodeRequest request,
  ) = _VerifyTaskApplicationCode;
}
