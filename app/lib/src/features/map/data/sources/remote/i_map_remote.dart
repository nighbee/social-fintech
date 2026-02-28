import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/map/data/models/map_apply_to_task_response_dto.dart';
import 'package:app/src/features/map/data/models/map_cancel_task_response_dto.dart';
import 'package:app/src/features/map/data/models/map_champion_dto.dart';
import 'package:app/src/features/map/data/models/map_confirm_completion_response_dto.dart';
import 'package:app/src/features/map/data/models/map_task_application_dto.dart';
import 'package:app/src/features/map/data/models/map_create_task_response_dto.dart';
import 'package:app/src/features/map/data/models/map_task_dto.dart';
import 'package:app/src/features/map/data/models/map_verify_code_response_dto.dart';
import 'package:app/src/features/map/data/models/map_region_assignment_dto.dart';
import 'package:app/src/features/map/domain/requests/map_champions_request.dart';
import 'package:app/src/features/map/domain/requests/map_create_task_request.dart';
import 'package:app/src/features/map/domain/requests/map_nearby_tasks_request.dart';
import 'package:app/src/features/map/domain/requests/map_region_assignment_request.dart';
import 'package:app/src/features/map/domain/requests/map_task_application_id_request.dart';
import 'package:app/src/features/map/domain/requests/map_task_id_request.dart';
import 'package:app/src/features/map/domain/requests/map_verify_code_request.dart';
import 'package:fpdart/fpdart.dart';

abstract interface class IMapRemote {
  Future<Either<DomainException, MapRegionAssignmentDto>> assignRegion(
    MapRegionAssignmentRequest request,
  );

  Future<Either<DomainException, List<MapChampionDto>>> getChampions(
    MapChampionsRequest request,
  );

  Future<Either<DomainException, MapCreateTaskResponseDto>> createTask(
    MapCreateTaskRequest request,
  );

  Future<Either<DomainException, MapCancelTaskResponseDto>> cancelTask(
    MapTaskIdRequest request,
  );

  Future<Either<DomainException, MapApplyToTaskResponseDto>> applyToTask(
    MapTaskIdRequest request,
  );

  Future<Either<DomainException, List<MapTaskDto>>> getNearbyTasks(
    MapNearbyTasksRequest request,
  );

  Future<Either<DomainException, List<MapTaskApplicationDto>>>
      getTaskApplications(MapTaskIdRequest request);

  Future<Either<DomainException, MapConfirmCompletionResponseDto>>
      confirmTaskApplication(MapTaskApplicationIdRequest request);

  Future<Either<DomainException, MapVerifyCodeResponseDto>>
      verifyTaskApplicationCode(
    MapTaskApplicationIdRequest target,
    MapVerifyCodeRequest request,
  );
}
