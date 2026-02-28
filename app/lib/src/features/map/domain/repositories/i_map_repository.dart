import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/map/domain/entities/map_camera_entity.dart';
import 'package:app/src/features/map/domain/entities/map_apply_to_task_entity.dart';
import 'package:app/src/features/map/domain/entities/map_champion_entity.dart';
import 'package:app/src/features/map/domain/entities/map_confirm_completion_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_application_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_entity.dart';
import 'package:app/src/features/map/domain/entities/map_verify_code_entity.dart';
import 'package:app/src/features/map/domain/entities/map_region_assignment_entity.dart';
import 'package:app/src/features/map/domain/requests/map_create_task_request.dart';
import 'package:app/src/features/map/domain/requests/map_region_assignment_request.dart';
import 'package:fpdart/fpdart.dart';

abstract interface class IMapRepository {
  Future<Either<DomainException, MapCameraEntity>> getInitialCamera();
  Future<Either<DomainException, MapRegionAssignmentEntity>> assignRegion(
    MapRegionAssignmentRequest request,
  );
  Future<Either<DomainException, List<MapChampionEntity>>> getChampions({
    required List<String> h3Indices,
    int resolution = 5,
    int? year,
    int? week,
  });
  Future<Either<DomainException, String>> createTask(
    MapCreateTaskRequest request,
  );

  Future<Either<DomainException, String>> cancelTask(String taskId);

  Future<Either<DomainException, MapApplyToTaskEntity>> applyToTask(
    String taskId,
  );

  Future<Either<DomainException, List<MapTaskEntity>>> getNearbyTasks({
    required double lat,
    required double lon,
    double radiusM = 2000,
    int limit = 50,
  });

  Future<Either<DomainException, List<MapTaskApplicationEntity>>>
      getTaskApplications(String taskId);

  Future<Either<DomainException, MapConfirmCompletionEntity>>
      confirmTaskApplication(String taskId, String applicationId);

  Future<Either<DomainException, MapVerifyCodeEntity>> verifyTaskApplicationCode(
    String taskId,
    String applicationId,
    String code,
  );
}
