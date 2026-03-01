import 'package:app/src/features/map/domain/entities/map_task_application_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_entity.dart';

class MapFlowEvaluator {
  const MapFlowEvaluator._();

  static MapTaskEntity? findCreatorActiveTask(List<MapTaskEntity> myTasks) {
    for (final task in myTasks) {
      final status = task.status.trim().toLowerCase();
      if (status == 'open' || status == 'in_progress' || status.startsWith('mine')) {
        return task;
      }
    }
    return null;
  }

  static List<MapTaskApplicationEntity> buildVisibleApplications(
    List<MapTaskApplicationEntity> taskApplications,
    Set<String> locallyRejectedApplicationIds,
  ) {
    return taskApplications
        .where(
          (app) =>
              app.status.trim().toLowerCase() != 'rejected' &&
              !locallyRejectedApplicationIds.contains(app.id),
        )
        .toList(growable: false);
  }
}
