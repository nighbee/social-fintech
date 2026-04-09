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
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

const bool _mapChampionsTraceEnabled = bool.fromEnvironment(
  'MAP_CHAMPIONS_TRACE',
  defaultValue: false,
);

@named
@LazySingleton(as: IMapRepository)
class MapRepositoryImpl implements IMapRepository {
  MapRepositoryImpl(@Named.from(MapRemoteImpl) this._remote);

  final IMapRemote _remote;

  void _traceChampions(String message) {
    if (!_mapChampionsTraceEnabled) {
      return;
    }
    debugPrint('[MapChampionsTrace] $message');
  }

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
      _traceChampions(
        'request resolution=$resolution h3=${indices.join(',')}',
      );
      final req = MapChampionsRequest(
        h3Indices: indices,
        resolution: resolution,
      );
      final result = await _remote.getChampions(req);
      return result.fold(
        (error) {
          _traceChampions(
            'response resolution=$resolution error=${error.message}',
          );
          return Left(error);
        },
        (dtos) {
          final summary = dtos
              .map(
                (dto) =>
                    '${dto.username.isEmpty ? dto.userId : dto.username}@${dto.h3Index}',
              )
              .join(' | ');
          _traceChampions(
            'response resolution=$resolution count=${dtos.length} data=$summary',
          );
          return Right(dtos.map((dto) => dto.toEntity()).toList());
        },
      );
    }

    final futures = <Future<Either<DomainException, List<MapChampionEntity>>>>[
      if (region.h3Res5.isNotEmpty) fetchOne([region.h3Res5], 5),
      if (region.h3Res4.isNotEmpty) fetchOne([region.h3Res4], 4),
      if (region.h3Res2.isNotEmpty) fetchOne([region.h3Res2], 2),
    ];
    if (futures.isEmpty) {
      return const Right(<MapChampionEntity>[]);
    }

    final outcomes = await Future.wait(futures);
    DomainException? firstError;
    var anySuccess = false;
    final mergedByKey = <String, MapChampionEntity>{};

    for (final o in outcomes) {
      o.fold(
        (e) => firstError ??= e,
        (list) {
          anySuccess = true;
          for (final c in list) {
            final key = '${c.resolution}|${c.h3Index}|${c.userId.trim()}';
            mergedByKey[key] = c;
          }
        },
      );
    }

    if (!anySuccess && firstError != null) {
      return Left(firstError!);
    }

    final merged = mergedByKey.values.toList(growable: false);
    merged.sort((a, b) => b.score.compareTo(a.score));
    _traceChampions(
      'merged count=${merged.length} data=${merged.map((c) => '${c.resolution}:${c.username.isEmpty ? c.userId : c.username}').join(' | ')}',
    );
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
