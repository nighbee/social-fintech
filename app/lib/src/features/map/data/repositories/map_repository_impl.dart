import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/map/domain/entities/map_apply_to_task_entity.dart';
import 'package:app/src/features/map/data/models/map_champions_request_dto.dart';
import 'package:app/src/features/map/data/models/map_create_task_request_dto.dart';
import 'package:app/src/features/map/data/models/map_nearby_tasks_request_dto.dart';
import 'package:app/src/features/map/data/models/map_verify_code_request_dto.dart';
import 'package:app/src/features/map/data/sources/local/i_map_local.dart';
import 'package:app/src/features/map/data/sources/local/map_local_impl.dart';
import 'package:app/src/features/map/data/sources/local/map_task_mock_models.dart';
import 'package:app/src/features/map/data/sources/remote/i_map_remote.dart';
import 'package:app/src/features/map/data/sources/remote/map_remote_impl.dart';
import 'package:app/src/features/map/domain/entities/map_camera_entity.dart';
import 'package:app/src/features/map/domain/entities/map_champion_entity.dart';
import 'package:app/src/features/map/domain/entities/map_confirm_completion_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_application_entity.dart';
import 'package:app/src/features/map/domain/entities/map_task_entity.dart';
import 'package:app/src/features/map/domain/entities/map_verify_code_entity.dart';
import 'package:app/src/features/map/domain/entities/map_region_assignment_entity.dart';
import 'package:app/src/features/map/domain/repositories/i_map_repository.dart';
import 'package:app/src/features/map/domain/requests/map_create_task_request.dart';
import 'package:app/src/features/map/domain/requests/map_region_assignment_request.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@named
@LazySingleton(as: IMapRepository)
class MapRepositoryImpl implements IMapRepository {
  MapRepositoryImpl(
    @Named.from(MapRemoteImpl) this._remote,
    @Named.from(MapLocalImpl) this._local,
  );

  final IMapRemote _remote;
  final IMapLocal _local;

  @override
  Future<Either<DomainException, MapCameraEntity>> getInitialCamera() async {
    return const Right(
      MapCameraEntity(
        centerLatitude: 40.7128,
        centerLongitude: -74.0060,
        zoom: 10.5,
      ),
    );
  }

  @override
  Future<Either<DomainException, MapRegionAssignmentEntity>> assignRegion(
    MapRegionAssignmentRequest request,
  ) async {
    final result = await _remote.assignRegion(request);
    return result.fold(
      (error) => Left(error),
      (dto) {
        final entity = dto.toEntity();
        _local.saveLastAssignedRegion(entity);
        return Right(entity);
      },
    );
  }

  String _championsKey(
    List<String> h3Indices,
    int resolution,
    int? year,
    int? week,
  ) {
    return '${h3Indices.join(',')}|$resolution|${year ?? ''}|${week ?? ''}';
  }

  @override
  Future<Either<DomainException, List<MapChampionEntity>>> getChampions({
    required List<String> h3Indices,
    int resolution = 5,
    int? year,
    int? week,
  }) async {
    if (h3Indices.isEmpty) {
      return const Right(<MapChampionEntity>[]);
    }

    final cacheKey = _championsKey(h3Indices, resolution, year, week);
    final result = await _remote.getChampions(
      MapChampionsRequestDto(
        h3Indices: h3Indices,
        resolution: resolution,
        year: year,
        week: week,
      ),
    );

    return result.fold(
      (error) {
        final cached = _local.getChampionsCache(cacheKey);
        if (cached != null) {
          return Right(cached);
        }
        return Left(error);
      },
      (dtos) {
        final champions = dtos.map((dto) => dto.toEntity()).toList();
        _local.saveChampionsCache(cacheKey, champions);
        return Right(champions);
      },
    );
  }

  @override
  Future<Either<DomainException, String>> createTask(
    MapCreateTaskRequest request,
  ) async {
    final dto = MapCreateTaskRequestDto(
      title: request.title,
      description: request.description,
      heroesCount: request.heroesCount,
      reward: request.reward,
      autoShutdown: request.autoShutdown,
    );
    final result = await _remote.createTask(dto);
    return result.fold((error) => Left(error), (responseDto) {
      final verificationCode = responseDto.verificationCode;
      _local.saveActiveTask(
        MapActiveTaskMock(
          taskId: responseDto.id,
          title: request.title,
          code: verificationCode,
          description: request.description,
          heroesCount: request.heroesCount,
          reward: request.reward,
          createdAt: DateTime.now(),
        ),
      );

      _local.saveTaskHelpers(const [
        MapTaskMockHelper(id: 'helper_1', name: 'Kundyz Akzhan'),
        MapTaskMockHelper(id: 'helper_2', name: 'Merey Zhumagul'),
      ]);
      _local.setArrivedHelperName(null);
      _local.setTaskCooldownUntil(null);
      return Right(verificationCode);
    });
  }

  @override
  Future<Either<DomainException, String>> cancelTask(String taskId) async {
    final result = await _remote.cancelTask(taskId);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.status),
    );
  }

  @override
  Future<Either<DomainException, MapApplyToTaskEntity>> applyToTask(
    String taskId,
  ) async {
    final result = await _remote.applyToTask(taskId);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, List<MapTaskEntity>>> getNearbyTasks({
    required double lat,
    required double lon,
    double radiusM = 2000,
    int limit = 50,
  }) async {
    final result = await _remote.getNearbyTasks(
      MapNearbyTasksRequestDto(
        lat: lat,
        lon: lon,
        radiusM: radiusM,
        limit: limit,
      ),
    );

    return result.fold(
      (error) => Left(error),
      (dtos) => Right(dtos.map((dto) => dto.toEntity()).toList()),
    );
  }

  @override
  Future<Either<DomainException, List<MapTaskApplicationEntity>>>
      getTaskApplications(String taskId) async {
    final result = await _remote.getTaskApplications(taskId);
    return result.fold(
      (error) => Left(error),
      (dtos) => Right(dtos.map((dto) => dto.toEntity()).toList()),
    );
  }

  @override
  Future<Either<DomainException, MapConfirmCompletionEntity>>
      confirmTaskApplication(String taskId, String applicationId) async {
    final result = await _remote.confirmTaskApplication(taskId, applicationId);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }

  @override
  Future<Either<DomainException, MapVerifyCodeEntity>> verifyTaskApplicationCode(
    String taskId,
    String applicationId,
    String code,
  ) async {
    final result = await _remote.verifyTaskApplicationCode(
      taskId,
      applicationId,
      MapVerifyCodeRequestDto(code: code),
    );
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
    );
  }
}
