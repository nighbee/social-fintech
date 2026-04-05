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

  static String? buildCreateTaskLockMessage(
    List<MapTaskEntity> myTasks, {
    List<MapTaskEntity> nearbyTasks = const <MapTaskEntity>[],
    DateTime? creatorLastTaskCreatedAtUtc,
    required DateTime nowUtc,
  }) {
    final active = findCreatorActiveTask(myTasks);
    if (active != null) {
      return 'You will be able to create a new request in 7 days.';
    }

    // Fallback: иногда myTasks приходит позже/неполно, но в nearby уже есть локальный mine|...
    final hasMineNearby = nearbyTasks.any(
      (task) => task.status.trim().toLowerCase().startsWith('mine|'),
    );
    if (hasMineNearby) {
      return 'You will be able to create a new request in 7 days.';
    }

    DateTime? latestCreatedAt = creatorLastTaskCreatedAtUtc;

    for (final task in myTasks) {
      final createdAt = DateTime.tryParse(task.createdAt)?.toUtc();
      if (createdAt == null) {
        continue;
      }
      if (latestCreatedAt == null || createdAt.isAfter(latestCreatedAt)) {
        latestCreatedAt = createdAt;
      }
    }

    final unlockAt = latestCreatedAt?.add(const Duration(days: 7));
    final isCooldownLocked = unlockAt != null && nowUtc.isBefore(unlockAt);
    if (isCooldownLocked) {
      return 'You must wait 7 days between creating tasks';
    }
    return null;
  }
}
