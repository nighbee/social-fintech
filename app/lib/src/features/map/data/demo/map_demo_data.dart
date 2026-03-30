import 'package:app/src/features/map/domain/entities/map_champion_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_entity.dart';

const String mapDemoChampionH3Res5 = '8520e60bfffffff';

const String mapDemoChampionUserId = '__demo_champion_almaty__';

/// [h3Res5] — ячейка текущего региона с бэка; иначе пин уезжает в Алматы, пока камера на другом городе.
MapChampionEntity buildDemoChampion({String? h3Res5}) {
  final h3 = (h3Res5 != null && h3Res5.trim().isNotEmpty)
      ? h3Res5.trim().toLowerCase()
      : mapDemoChampionH3Res5;
  return MapChampionEntity(
    h3Index: h3,
    resolution: 5,
    score: 9999,
    userId: mapDemoChampionUserId,
  );
}

/// Треугольники-задания в сотнях метров от точки запроса nearby (центр карты / GPS).
List<MapTaskEntity> buildDemoNearbyTasks({
  required double centerLat,
  required double centerLon,
}) {
  final base = DateTime.now().toUtc().toIso8601String();
  return <MapTaskEntity>[
    MapTaskEntity(
      id: 'map-demo-task-1',
      title: 'Демо: срочная доставка',
      description: 'Мок для превью карты в Алматы.',
      reward: 2,
      workersNeeded: 3,
      workersFilled: 1,
      status: 'open',
      autoShutdownAt: '',
      latitude: centerLat + 0.0022,
      longitude: centerLon + 0.0011,
      createdAt: base,
    ),
    MapTaskEntity(
      id: 'map-demo-task-2',
      title: 'Демо: фото витрины',
      description: 'Второй мок-таск рядом.',
      reward: 3,
      workersNeeded: 2,
      workersFilled: 0,
      status: 'open',
      autoShutdownAt: '',
      latitude: centerLat - 0.0014,
      longitude: centerLon + 0.0018,
      createdAt: base,
    ),
    MapTaskEntity(
      id: 'map-demo-task-3',
      title: 'Демо: опрос проходимости',
      description: 'Третий мок для плотности пинов.',
      reward: 1,
      workersNeeded: 5,
      workersFilled: 2,
      status: 'open',
      autoShutdownAt: '',
      latitude: centerLat + 0.0006,
      longitude: centerLon - 0.0020,
      createdAt: base,
    ),
  ];
}

List<MapTaskEntity> mergeWithDemoNearbyTasks(
  List<MapTaskEntity> fromApi,
  List<MapTaskEntity> demo,
) {
  final ids = fromApi.map((t) => t.id).toSet();
  return <MapTaskEntity>[...fromApi, ...demo.where((t) => !ids.contains(t.id))];
}
