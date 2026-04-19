import 'dart:async';

import 'package:app/src/features/map/domain/entities/map_task_entity.dart';
import 'package:app/src/features/map/presentation/utils/map_flow_evaluator.dart';
import 'package:flutter/foundation.dart';

class MapPollingService {
  Timer? _nearbyRefreshTimer;
  DateTime? _lastApplicationsRefreshAt;
  String? _lastApplicationsTaskId;

  String? get lastApplicationsTaskId => _lastApplicationsTaskId;

  void dispose() {
    _nearbyRefreshTimer?.cancel();
  }

  void startNearbyRefreshTimer({
    required Duration interval,
    required VoidCallback onTick,
  }) {
    _nearbyRefreshTimer?.cancel();
    _nearbyRefreshTimer = Timer.periodic(interval, (_) => onTick());
  }

  void refreshTaskApplicationsIfNeeded({
    required List<MapTaskEntity> myTasks,
    required Duration refreshInterval,
    required void Function(String taskId) onRefresh,
    required VoidCallback onNoActiveTask,
  }) {
    final myTask = MapFlowEvaluator.findCreatorActiveTask(myTasks);

    if (myTask == null || myTask.id.isEmpty) {
      _lastApplicationsTaskId = null;
      _lastApplicationsRefreshAt = null;
      onNoActiveTask();
      return;
    }

    final now = DateTime.now();
    final taskChanged = _lastApplicationsTaskId != myTask.id;
    final canRefreshByTime = _lastApplicationsRefreshAt == null ||
        now.difference(_lastApplicationsRefreshAt!) >= refreshInterval;

    if (!taskChanged && !canRefreshByTime) {
      return;
    }

    _lastApplicationsTaskId = myTask.id;
    _lastApplicationsRefreshAt = now;
    onRefresh(myTask.id);
  }
}
