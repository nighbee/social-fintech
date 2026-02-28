import 'package:app/src/features/map/domain/entities/map_champion_entity.dart';
import 'package:app/src/features/map/domain/entities/map_region_assignment_entity.dart';
import 'package:app/src/features/map/data/sources/local/map_task_mock_models.dart';

abstract interface class IMapLocal {
  MapRegionAssignmentEntity? getLastAssignedRegion();
  void saveLastAssignedRegion(MapRegionAssignmentEntity region);

  List<MapChampionEntity>? getChampionsCache(String key);
  void saveChampionsCache(String key, List<MapChampionEntity> champions);

  MapActiveTaskMock? getActiveTask();
  void saveActiveTask(MapActiveTaskMock task);
  void clearActiveTask();

  List<MapTaskMockHelper> getTaskHelpers();
  void saveTaskHelpers(List<MapTaskMockHelper> helpers);
  void removeTaskHelperById(String helperId);

  String? getArrivedHelperName();
  void setArrivedHelperName(String? helperName);

  DateTime? getTaskCooldownUntil();
  void setTaskCooldownUntil(DateTime? cooldownUntil);
}
