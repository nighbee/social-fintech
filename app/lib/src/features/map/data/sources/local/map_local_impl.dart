import 'package:app/src/features/map/data/sources/local/i_map_local.dart';
import 'package:app/src/features/map/data/sources/local/map_task_mock_models.dart';
import 'package:app/src/features/map/domain/entities/map_champion_entity.dart';
import 'package:app/src/features/map/domain/entities/map_region_assignment_entity.dart';
import 'package:injectable/injectable.dart';

@named
@LazySingleton(as: IMapLocal)
class MapLocalImpl implements IMapLocal {
  MapRegionAssignmentEntity? _lastAssignedRegion;
  final Map<String, List<MapChampionEntity>> _championsCache =
      <String, List<MapChampionEntity>>{};
  MapActiveTaskMock? _activeTask;
  List<MapTaskMockHelper> _taskHelpers = <MapTaskMockHelper>[];
  String? _arrivedHelperName;
  DateTime? _taskCooldownUntil;

  @override
  MapRegionAssignmentEntity? getLastAssignedRegion() => _lastAssignedRegion;

  @override
  void saveLastAssignedRegion(MapRegionAssignmentEntity region) {
    _lastAssignedRegion = region;
  }

  @override
  List<MapChampionEntity>? getChampionsCache(String key) {
    final value = _championsCache[key];
    if (value == null) {
      return null;
    }
    return List<MapChampionEntity>.from(value);
  }

  @override
  void saveChampionsCache(String key, List<MapChampionEntity> champions) {
    _championsCache[key] = List<MapChampionEntity>.from(champions);
  }

  @override
  MapActiveTaskMock? getActiveTask() => _activeTask;

  @override
  void saveActiveTask(MapActiveTaskMock task) {
    _activeTask = task;
  }

  @override
  void clearActiveTask() {
    _activeTask = null;
  }

  @override
  List<MapTaskMockHelper> getTaskHelpers() {
    return List<MapTaskMockHelper>.from(_taskHelpers);
  }

  @override
  void saveTaskHelpers(List<MapTaskMockHelper> helpers) {
    _taskHelpers = List<MapTaskMockHelper>.from(helpers);
  }

  @override
  void removeTaskHelperById(String helperId) {
    _taskHelpers = _taskHelpers.where((helper) => helper.id != helperId).toList();
  }

  @override
  String? getArrivedHelperName() => _arrivedHelperName;

  @override
  void setArrivedHelperName(String? helperName) {
    _arrivedHelperName = helperName;
  }

  @override
  DateTime? getTaskCooldownUntil() => _taskCooldownUntil;

  @override
  void setTaskCooldownUntil(DateTime? cooldownUntil) {
    _taskCooldownUntil = cooldownUntil;
  }
}
