part of 'map_bloc.dart';

@freezed
class MapState with _$MapState {
  const factory MapState.initial() = _Initial;
  const factory MapState.loading({required MapViewModel viewModel}) = _Loading;
  const factory MapState.loadingError(String message) = _LoadingError;
  const factory MapState.loaded({required MapViewModel viewModel}) = _Loaded;
}

@freezed
class MapViewModel with _$MapViewModel {
  const factory MapViewModel({
    @Default(50.4501) double centerLatitude,
    @Default(30.5234) double centerLongitude,
    @Default(11.8) double zoom,
    @Default(false) bool isBusy,
    @Default(false) bool isCreatingTask,
    @Default(MapRegionAssignmentEntity.empty())
    MapRegionAssignmentEntity assignedRegion,
    @Default(<MapChampionEntity>[]) List<MapChampionEntity> champions,
    @Default(<MapTaskEntity>[]) List<MapTaskEntity> nearbyTasks,
    @Default(<MapTaskEntity>[]) List<MapTaskEntity> appliedTasks,
    @Default(false) bool hasAppliedTasksLoaded,
    @Default(<MapTaskEntity>[]) List<MapTaskEntity> myTasks,
    @Default(MapTaskEntity.empty()) MapTaskEntity selectedTask,
    @Default(<MapTaskApplicationEntity>[]) List<MapTaskApplicationEntity>
        taskApplications,
    @Default(MapApplyToTaskEntity.empty()) MapApplyToTaskEntity applyToTaskResult,
    @Default(MapConfirmCompletionEntity.empty())
    MapConfirmCompletionEntity confirmCompletionResult,
    @Default(MapVerifyCodeEntity.empty()) MapVerifyCodeEntity verifyCodeResult,
    @Default('') String taskApplicationActionResult,
    @Default('') String cancelTaskResult,
  }) = _MapViewModel;
}
