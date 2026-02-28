part of 'map_bloc.dart';

@freezed
class MapEvent with _$MapEvent {
  const factory MapEvent.loadMap() = _LoadMap;
  const factory MapEvent.createTask({
    required String title,
    required String description,
    required int heroesCount,
    required int reward,
    required bool autoShutdown,
  }) = _CreateTask;
}
