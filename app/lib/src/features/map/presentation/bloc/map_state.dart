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
    @Default(40.7128) double centerLatitude,
    @Default(-74.0060) double centerLongitude,
    @Default(10.5) double zoom,
    @Default(false) bool isCreatingTask,
    String? taskCreateError,
    String? taskCreatedMessage,
  }) = _MapViewModel;
}
