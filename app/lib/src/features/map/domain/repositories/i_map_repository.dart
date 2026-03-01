import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/map/domain/entities/map_apply_to_task_entity.dart';
import 'package:app/src/features/map/domain/entities/map_champion_entity.dart';
import 'package:app/src/features/map/domain/entities/map_confirm_completion_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_application_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_entity.dart';
import 'package:app/src/features/map/domain/entities/map_verify_code_entity.dart';
import 'package:app/src/features/map/domain/entities/map_region_assignment_entity.dart';
import 'package:app/src/features/map/domain/requests/map_champions_request.dart';
import 'package:app/src/features/map/domain/requests/map_create_task_request.dart';
import 'package:app/src/features/map/domain/requests/map_nearby_tasks_request.dart';
import 'package:app/src/features/map/domain/requests/map_region_assignment_request.dart';
import 'package:app/src/features/map/domain/requests/map_task_application_id_request.dart';
import 'package:app/src/features/map/domain/requests/map_task_id_request.dart';
import 'package:app/src/features/map/domain/requests/map_verify_code_request.dart';
import 'package:fpdart/fpdart.dart';

abstract interface class IMapRepository {
  Future<Either<DomainException, MapRegionAssignmentEntity>> assignRegion(
    MapRegionAssignmentRequest request,
  );
  Future<Either<DomainException, List<MapChampionEntity>>> getChampions(
    MapChampionsRequest request,
  );
  Future<Either<DomainException, MapTaskEntity>> createTask(
    MapCreateTaskRequest request,
  );

  Future<Either<DomainException, String>> cancelTask(MapTaskIdRequest request);

  Future<Either<DomainException, MapApplyToTaskEntity>> applyToTask(
    MapTaskIdRequest request,
  );

  Future<Either<DomainException, List<MapTaskEntity>>> getNearbyTasks(
    MapNearbyTasksRequest request,
  );

  Future<Either<DomainException, List<MapTaskApplicationEntity>>>
      getTaskApplications(MapTaskIdRequest request);

  Future<Either<DomainException, MapConfirmCompletionEntity>>
      confirmTaskApplication(MapTaskApplicationIdRequest request);

  Future<Either<DomainException, MapVerifyCodeEntity>>
      verifyTaskApplicationCode(
    MapTaskApplicationIdRequest target,
    MapVerifyCodeRequest request,
  );
}
