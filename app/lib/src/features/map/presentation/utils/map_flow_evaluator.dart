import 'package:app/src/features/map/domain/entities/map_task_application_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_entity.dart';

class MapFlowEvaluator {
  const MapFlowEvaluator._();

  static MapTaskEntity? findCreatorActiveTask(List<MapTaskEntity> myTasks) {
    DateTime? latestClosedAt;
    for (final task in myTasks) {
      final status = task.status.trim().toLowerCase();
      if (status != 'completed' && status != 'cancelled') {
        continue;
      }

      final createdAt = DateTime.tryParse(task.createdAt)?.toUtc();
      if (createdAt == null) {
        continue;
      }
      if (latestClosedAt == null || createdAt.isAfter(latestClosedAt)) {
        latestClosedAt = createdAt;
      }
    }

    for (final task in myTasks) {
      final status = task.status.trim().toLowerCase();
      if (status == 'completed' || status == 'cancelled') {
        continue;
      }

      final hasRemainingSlots = task.workersFilled < task.workersNeeded;
      final isActiveStatus =
          status == 'open' || status == 'in_progress' || status.startsWith('mine');
      if (!isActiveStatus || !hasRemainingSlots) {
        continue;
      }

      if (latestClosedAt != null) {
        final createdAt = DateTime.tryParse(task.createdAt)?.toUtc();
        if (createdAt == null || !createdAt.isAfter(latestClosedAt)) {
          continue;
        }
      }

      return task;
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
