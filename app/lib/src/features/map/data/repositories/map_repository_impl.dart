import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/map/domain/entities/map_apply_to_task_entity.dart';
import 'package:app/src/features/map/data/sources/remote/i_map_remote.dart';
import 'package:app/src/features/map/data/sources/remote/map_remote_impl.dart';
import 'package:app/src/features/map/domain/entities/map_champion_entity.dart';
import 'package:app/src/features/map/domain/entities/map_confirm_completion_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_application_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_entity.dart';
import 'package:app/src/features/map/domain/entities/map_verify_code_entity.dart';
import 'package:app/src/features/map/domain/entities/map_region_assignment_entity.dart';
import 'package:app/src/features/map/domain/repositories/i_map_repository.dart';
import 'package:app/src/features/map/domain/requests/map_champions_request.dart';
import 'package:app/src/features/map/domain/requests/map_create_task_request.dart';
import 'package:app/src/features/map/domain/requests/map_nearby_tasks_request.dart';
import 'package:app/src/features/map/domain/requests/map_region_assignment_request.dart';
import 'package:app/src/features/map/domain/requests/map_task_application_id_request.dart';
import 'package:app/src/features/map/domain/requests/map_task_id_request.dart';
import 'package:app/src/features/map/domain/requests/map_verify_code_request.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@named
@LazySingleton(as: IMapRepository)
class MapRepositoryImpl implements IMapRepository {
  MapRepositoryImpl(@Named.from(MapRemoteImpl) this._remote);

  final IMapRemote _remote;

  @override
  Future<Either<DomainException, MapRegionAssignmentEntity>> assignRegion(
    MapRegionAssignmentRequest request,
  ) async {
    final result = await _remote.assignRegion(request);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, List<MapChampionEntity>>> getChampions(
    MapChampionsRequest request,
  ) async {
    if (request.h3Indices.isEmpty) {
      return const Right(<MapChampionEntity>[]);
    }

    final result = await _remote.getChampions(request);

    return result.fold(
      (error) => Left(error),
      (dtos) => Right(dtos.map((dto) => dto.toEntity()).toList()),
    );
  }

  @override
  Future<Either<DomainException, MapTaskEntity>> createTask(
    MapCreateTaskRequest request,
  ) async {
    final result = await _remote.createTask(request);
    return result.fold(
      (error) => Left(error),
      (responseDto) => Right(
        MapTaskEntity(
          id: responseDto.id,
          title: responseDto.title,
          description: responseDto.description ?? '',
          reward: responseDto.reward,
          workersNeeded: responseDto.workersNeeded,
          workersFilled: responseDto.workersFilled,
          // Keep local creator marker + backend numeric verification code.
          status: 'mine|${responseDto.verificationCode}',
          autoShutdownAt: responseDto.autoShutdownAt ?? '',
          latitude: responseDto.latitude,
          longitude: responseDto.longitude,
          createdAt: responseDto.createdAt,
        ),
      ),
    );
  }

  @override
  Future<Either<DomainException, String>> cancelTask(
    MapTaskIdRequest request,
  ) async {
    final result = await _remote.cancelTask(request);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.status),
    );
  }

  @override
  Future<Either<DomainException, MapApplyToTaskEntity>> applyToTask(
    MapTaskIdRequest request,
  ) async {
    final result = await _remote.applyToTask(request);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, List<MapTaskEntity>>> getNearbyTasks(
    MapNearbyTasksRequest request,
  ) async {
    final result = await _remote.getNearbyTasks(request);

    return result.fold(
      (error) => Left(error),
      (dtos) => Right(dtos.map((dto) => dto.toEntity()).toList()),
    );
  }

  @override
  Future<Either<DomainException, List<MapTaskApplicationEntity>>>
      getTaskApplications(MapTaskIdRequest request) async {
    final result = await _remote.getTaskApplications(request);
    return result.fold(
      (error) => Left(error),
      (dtos) => Right(dtos.map((dto) => dto.toEntity()).toList()),
    );
  }

  @override
  Future<Either<DomainException, MapConfirmCompletionEntity>>
      confirmTaskApplication(MapTaskApplicationIdRequest request) async {
    final result = await _remote.confirmTaskApplication(request);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, MapVerifyCodeEntity>>
      verifyTaskApplicationCode(
    MapTaskApplicationIdRequest target,
    MapVerifyCodeRequest request,
  ) async {
    final result = await _remote.verifyTaskApplicationCode(target, request);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }
}
