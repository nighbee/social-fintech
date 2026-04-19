import 'package:app/src/core/service/storage/app_storage/storage_service.dart';
import 'package:app/src/core/service/storage/key_store.dart';
import 'package:app/src/features/map/presentation/models/active_executor_application.dart';

class MapPersistenceService {
  const MapPersistenceService();

  String _scopedKey(String baseKey, String userId) {
    return '${baseKey}_${userId.trim()}';
  }

  Future<DateTime?> readLastCreatorTaskCreatedAt({required String userId}) async {
    if (userId.trim().isEmpty) {
      return null;
    }
    await prefsInstance.initialize();
    final raw = prefsInstance.get<String>(
      _scopedKey(KeyStore.mapLastCreatorTaskCreatedAt, userId),
    );
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> writeLastCreatorTaskCreatedAt(
    DateTime createdAtUtc, {
    required String userId,
  }) async {
    if (userId.trim().isEmpty) {
      return;
    }
    await prefsInstance.initialize();
    await prefsInstance.set<String>(
      _scopedKey(KeyStore.mapLastCreatorTaskCreatedAt, userId),
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

  Future<ActiveExecutorApplication?> readActiveExecutorApplication({
    required String userId,
  }) async {
    if (userId.trim().isEmpty) {
      return null;
    }
    await prefsInstance.initialize();
    final taskId = prefsInstance.get<String>(
      _scopedKey(KeyStore.mapActiveExecutorTaskId, userId),
    );
    final applicationId = prefsInstance.get<String>(
      _scopedKey(KeyStore.mapActiveExecutorApplicationId, userId),
    );
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
    {
    required String userId,
  }
  ) async {
    if (userId.trim().isEmpty) {
      return;
    }
    await prefsInstance.initialize();
    await prefsInstance.set<String>(
      _scopedKey(KeyStore.mapActiveExecutorTaskId, userId),
      target.taskId,
    );
    await prefsInstance.set<String>(
      _scopedKey(KeyStore.mapActiveExecutorApplicationId, userId),
      target.applicationId,
    );
  }

  Future<void> clearActiveExecutorApplication({required String userId}) async {
    if (userId.trim().isEmpty) {
      return;
    }
    await prefsInstance.initialize();
    await prefsInstance.remove(
      _scopedKey(KeyStore.mapActiveExecutorTaskId, userId),
    );
    await prefsInstance.remove(
      _scopedKey(KeyStore.mapActiveExecutorApplicationId, userId),
    );
  }

  Future<void> clearLegacyGlobalExecutorApplication() async {
    await prefsInstance.initialize();
    await prefsInstance.remove(KeyStore.mapActiveExecutorTaskId);
    await prefsInstance.remove(KeyStore.mapActiveExecutorApplicationId);
  }
}
