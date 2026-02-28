import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/map/data/models/map_apply_to_task_response_dto.dart';
import 'package:app/src/features/map/data/models/map_cancel_task_response_dto.dart';
import 'package:app/src/features/map/data/models/map_champions_request_dto.dart';
import 'package:app/src/features/map/data/models/map_champion_dto.dart';
import 'package:app/src/features/map/data/models/map_confirm_completion_response_dto.dart';
import 'package:app/src/features/map/data/models/map_task_application_dto.dart';
import 'package:app/src/features/map/data/models/map_create_task_request_dto.dart';
import 'package:app/src/features/map/data/models/map_create_task_response_dto.dart';
import 'package:app/src/features/map/data/models/map_nearby_tasks_request_dto.dart';
import 'package:app/src/features/map/data/models/map_task_dto.dart';
import 'package:app/src/features/map/data/models/map_verify_code_request_dto.dart';
import 'package:app/src/features/map/data/models/map_verify_code_response_dto.dart';
import 'package:app/src/features/map/data/models/map_region_assignment_dto.dart';
import 'package:app/src/features/map/domain/requests/map_region_assignment_request.dart';
import 'package:fpdart/fpdart.dart';

abstract interface class IMapRemote {
  Future<Either<DomainException, MapRegionAssignmentDto>> assignRegion(
    MapRegionAssignmentRequest request,
  );

  Future<Either<DomainException, List<MapChampionDto>>> getChampions(
    MapChampionsRequestDto request,
  );

  Future<Either<DomainException, MapCreateTaskResponseDto>> createTask(
    MapCreateTaskRequestDto request,
  );

  Future<Either<DomainException, MapCancelTaskResponseDto>> cancelTask(
    String taskId,
  );

  Future<Either<DomainException, MapApplyToTaskResponseDto>> applyToTask(
    String taskId,
  );

  Future<Either<DomainException, List<MapTaskDto>>> getNearbyTasks(
    MapNearbyTasksRequestDto request,
  );

  Future<Either<DomainException, List<MapTaskApplicationDto>>>
      getTaskApplications(String taskId);

  Future<Either<DomainException, MapConfirmCompletionResponseDto>>
      confirmTaskApplication(String taskId, String applicationId);

  Future<Either<DomainException, MapVerifyCodeResponseDto>>
      verifyTaskApplicationCode(
        String taskId,
        String applicationId,
        MapVerifyCodeRequestDto request,
      );
}
