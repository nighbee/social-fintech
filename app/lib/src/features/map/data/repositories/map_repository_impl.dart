import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/map/data/demo/map_demo_config.dart';
import 'package:app/src/features/map/data/demo/map_demo_data.dart';
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
  Future<Either<DomainException, List<MapChampionEntity>>>
      getChampionsMergedForRegion(MapRegionAssignmentEntity region) async {
    Future<Either<DomainException, List<MapChampionEntity>>> fetchOne(
      List<String> indices,
      int resolution,
    ) async {
      if (indices.isEmpty) {
        return const Right(<MapChampionEntity>[]);
      }
      final req = MapChampionsRequest(
        h3Indices: indices,
        resolution: resolution,
      );
      final result = await _remote.getChampions(req);
      return result.fold(
        Left.new,
        (dtos) => Right(dtos.map((dto) => dto.toEntity()).toList()),
      );
    }

    final futures = <Future<Either<DomainException, List<MapChampionEntity>>>>[
      if (region.h3Res5.isNotEmpty) fetchOne([region.h3Res5], 5),
      if (region.h3Res4.isNotEmpty) fetchOne([region.h3Res4], 4),
      if (region.h3Res2.isNotEmpty) fetchOne([region.h3Res2], 2),
    ];
    if (futures.isEmpty) {
      if (mapDemoMocksEnabled) {
        return Right([buildDemoChampion(h3Res5: region.h3Res5)]);
      }
      return const Right(<MapChampionEntity>[]);
    }

    final outcomes = await Future.wait(futures);
    DomainException? firstError;
    var anySuccess = false;
    final merged = <MapChampionEntity>[];
    final seenH3 = <String>{};

    for (final o in outcomes) {
      o.fold(
        (e) => firstError ??= e,
        (list) {
          anySuccess = true;
          for (final c in list) {
            if (seenH3.add(c.h3Index)) {
              merged.add(c);
            }
          }
        },
      );
    }

    if (!anySuccess && firstError != null) {
      if (mapDemoMocksEnabled) {
        return Right([buildDemoChampion(h3Res5: region.h3Res5)]);
      }
      return Left(firstError!);
    }
    merged.sort((a, b) => b.score.compareTo(a.score));
    if (mapDemoMocksEnabled) {
      final demo = buildDemoChampion(h3Res5: region.h3Res5);
      if (!merged.any((c) => c.h3Index == demo.h3Index)) {
        merged.add(demo);
        merged.sort((a, b) => b.score.compareTo(a.score));
      }
    }
    return Right(merged);
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
    final demo = mapDemoMocksEnabled
        ? buildDemoNearbyTasks(
            centerLat: request.lat,
            centerLon: request.lon,
          )
        : const <MapTaskEntity>[];

    if (mapDemoMocksEnabled) {
      final result = await _remote.getNearbyTasks(request);
      return result.fold(
        (_) => Right(demo),
        (dtos) => Right(
          mergeWithDemoNearbyTasks(
            dtos.map((dto) => dto.toEntity()).toList(),
            demo,
          ),
        ),
      );
    }

    final result = await _remote.getNearbyTasks(request);
    return result.fold(
      (error) => Left(error),
      (dtos) => Right(dtos.map((dto) => dto.toEntity()).toList()),
    );
  }

  @override
  Future<Either<DomainException, List<MapTaskEntity>>> getAppliedTasks() async {
    final result = await _remote.getAppliedTasks();

    return result.fold(
      (error) => Left(error),
      (dtos) => Right(dtos.map((dto) => dto.toEntity()).toList()),
    );
  }

  @override
  Future<Either<DomainException, List<MapTaskEntity>>> getMyTasks() async {
    final result = await _remote.getMyTasks();

    return result.fold(
      (error) => Left(error),
      (dtos) => Right(dtos.map((dto) => dto.toEntity()).toList()),
    );
  }

  @override
  Future<Either<DomainException, MapTaskEntity>> getTaskById(
    MapTaskIdRequest request,
  ) async {
    final result = await _remote.getTaskById(request);
    return result.fold(
      (error) => Left(error),
      (dto) => Right(dto.toEntity()),
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
  Future<Either<DomainException, String>> acceptTaskApplication(
    MapTaskApplicationIdRequest request,
  ) async {
    final result = await _remote.acceptTaskApplication(request);
    return result.fold(
      (error) => Left(error),
      (status) => Right(status),
    );
  }

  @override
  Future<Either<DomainException, String>> rejectTaskApplication(
    MapTaskApplicationIdRequest request,
  ) async {
    final result = await _remote.rejectTaskApplication(request);
    return result.fold(
      (error) => Left(error),
      (status) => Right(status),
    );
  }

  @override
  Future<Either<DomainException, String>> withdrawTaskApplication(
    MapTaskApplicationIdRequest request,
  ) async {
    final result = await _remote.withdrawTaskApplication(request);
    return result.fold(
      (error) => Left(error),
      (status) => Right(status),
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
