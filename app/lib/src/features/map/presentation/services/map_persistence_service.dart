import 'package:app/src/core/service/storage/app_storage/storage_service.dart';
import 'package:app/src/core/service/storage/key_store.dart';
import 'package:app/src/features/map/presentation/models/active_executor_application.dart';

class MapPersistenceService {
  const MapPersistenceService();

  Future<DateTime?> readLastCreatorTaskCreatedAt() async {
    await prefsInstance.initialize();
    final raw = prefsInstance.get<String>(KeyStore.mapLastCreatorTaskCreatedAt);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> writeLastCreatorTaskCreatedAt(DateTime createdAtUtc) async {
    await prefsInstance.initialize();
    await prefsInstance.set<String>(
      KeyStore.mapLastCreatorTaskCreatedAt,
      createdAtUtc.toUtc().toIso8601String(),
    );
  }

  Future<({double lat, double lon})?> readSavedCenter() async {
    await prefsInstance.initialize();
    final savedLat = prefsInstance.get<double>(KeyStore.mapLastCenterLat);
    final savedLon = prefsInstance.get<double>(KeyStore.mapLastCenterLon);
    if (savedLat == null || savedLon == null) {
      return null;
    }
    return (lat: savedLat, lon: savedLon);
  }

  Future<void> writeSavedCenter(double lat, double lon) async {
    await prefsInstance.initialize();
    await prefsInstance.set<double>(KeyStore.mapLastCenterLat, lat);
    await prefsInstance.set<double>(KeyStore.mapLastCenterLon, lon);
  }

  Future<ActiveExecutorApplication?> readActiveExecutorApplication() async {
    await prefsInstance.initialize();
    final taskId = prefsInstance.get<String>(KeyStore.mapActiveExecutorTaskId);
    final applicationId =
        prefsInstance.get<String>(KeyStore.mapActiveExecutorApplicationId);
    if (taskId == null ||
        taskId.isEmpty ||
        applicationId == null ||
        applicationId.isEmpty) {
      return null;
    }

    return ActiveExecutorApplication(
      taskId: taskId,
      applicationId: applicationId,
    );
  }

  Future<void> writeActiveExecutorApplication(
    ActiveExecutorApplication target,
  ) async {
    await prefsInstance.initialize();
    await prefsInstance.set<String>(KeyStore.mapActiveExecutorTaskId, target.taskId);
    await prefsInstance.set<String>(
      KeyStore.mapActiveExecutorApplicationId,
      target.applicationId,
    );
  }

  Future<void> clearActiveExecutorApplication() async {
    await prefsInstance.initialize();
    await prefsInstance.remove(KeyStore.mapActiveExecutorTaskId);
    await prefsInstance.remove(KeyStore.mapActiveExecutorApplicationId);
  }
}
