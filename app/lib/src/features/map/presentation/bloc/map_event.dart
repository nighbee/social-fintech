part of 'map_bloc.dart';

@freezed
class MapEvent with _$MapEvent {
  const factory MapEvent.loadMap() = _LoadMap;
  const factory MapEvent.assignRegion(MapRegionAssignmentRequest request) =
      _AssignRegion;
  const factory MapEvent.getChampions(MapChampionsRequest request) =
      _GetChampions;
  const factory MapEvent.createTask(MapCreateTaskRequest request) = _CreateTask;
  const factory MapEvent.cancelTask(MapTaskIdRequest request) = _CancelTask;
  const factory MapEvent.applyToTask(MapTaskIdRequest request) = _ApplyToTask;
  const factory MapEvent.getNearbyTasks(MapNearbyTasksRequest request) =
      _GetNearbyTasks;
  const factory MapEvent.getTaskApplications(MapTaskIdRequest request) =
      _GetTaskApplications;
  const factory MapEvent.confirmTaskApplication(
    MapTaskApplicationIdRequest request,
  ) = _ConfirmTaskApplication;
  const factory MapEvent.verifyTaskApplicationCode(
    MapTaskApplicationIdRequest target,
    MapVerifyCodeRequest request,
  ) = _VerifyTaskApplicationCode;
}
