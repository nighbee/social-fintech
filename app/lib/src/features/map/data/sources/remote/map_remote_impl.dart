import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/map/data/models/map_apply_to_task_response_dto.dart';
import 'package:app/src/features/map/data/models/map_cancel_task_response_dto.dart';
import 'package:app/src/features/map/data/models/map_champion_dto.dart';
import 'package:app/src/features/map/data/models/map_confirm_completion_response_dto.dart';
import 'package:app/src/features/map/data/models/map_task_application_dto.dart';
import 'package:app/src/features/map/data/models/map_create_task_response_dto.dart';
import 'package:app/src/features/map/data/models/map_nearby_tasks_response_dto.dart';
import 'package:app/src/features/map/data/models/map_task_dto.dart';
import 'package:app/src/features/map/data/models/map_verify_code_response_dto.dart';
import 'package:app/src/features/map/data/models/map_region_assignment_dto.dart';
import 'package:app/src/features/map/data/sources/remote/i_map_remote.dart';
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
@LazySingleton(as: IMapRemote)
class MapRemoteImpl implements IMapRemote {
  MapRemoteImpl(@Named('DioClient') this._restClient);

  final RestClient _restClient;

  @override
  Future<Either<DomainException, MapRegionAssignmentDto>> assignRegion(
    MapRegionAssignmentRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.mapRegion,
        data: request.toJson(),
      );

      return response.fold((error) => Left(error), (result) {
        final dynamic raw = result.data;
        if (raw is! Map) {
          return Left(UnknownException(message: 'Invalid region response'));
        }

        final dto = MapRegionAssignmentDto.fromJson(
          Map<String, dynamic>.from(raw),
        );
        return Right(dto);
      });
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, List<MapChampionDto>>> getChampions(
    MapChampionsRequest request,
  ) async {
    if (request.h3Indices.isEmpty) {
      return const Right(<MapChampionDto>[]);
    }

    final query = <String, dynamic>{
      'h3': request.h3Indices.join(','),
      'resolution': request.resolution,
    };
    if (request.year != null) {
      query['year'] = request.year;
    }
    if (request.week != null) {
      query['week'] = request.week;
    }

    try {
      final response = await _restClient.get(
        EndPoints.mapChampions,
        queryParameters: query,
      );

      return response.fold((error) => Left(error), (result) {
        final dynamic raw = result.data;
        if (raw is! List) {
          return Left(UnknownException(message: 'Invalid champions response'));
        }

        final champions = raw
            .whereType<Map>()
            .map(
              (item) => MapChampionDto.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
        return Right(champions);
      });
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, MapCreateTaskResponseDto>> createTask(
    MapCreateTaskRequest request,
  ) async {
    try {
      final payload = <String, dynamic>{
        'title': request.title.trim(),
        'description': request.description.trim(),
        'reward': request.reward,
        'workers_needed': 1,
        'latitude': request.latitude,
        'longitude': request.longitude,
        'auto_shutdown': request.autoShutdown,
      };

      final response = await _restClient.post(
        EndPoints.mapTasks,
        data: payload,
      );

      return response.fold((error) => Left(error), (result) {
        final dynamic raw = result.data;
        if (raw is! Map) {
          return Left(
              UnknownException(message: 'Invalid task create response'));
        }
        final json = Map<String, dynamic>.from(raw);
        final dto = MapCreateTaskResponseDto.fromJson(json);
        return Right(dto);
      });
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, MapCancelTaskResponseDto>> cancelTask(
    MapTaskIdRequest request,
  ) async {
    try {
      final response = await _restClient.delete(
        EndPoints.mapTaskById(request.taskId),
      );

      return response.fold((error) => Left(error), (result) {
        final dynamic raw = result.data;
        if (raw is! Map) {
          return Left(
              UnknownException(message: 'Invalid cancel task response'));
        }
        final json = Map<String, dynamic>.from(raw);
        final dto = MapCancelTaskResponseDto.fromJson(json);
        return Right(dto);
      });
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, MapApplyToTaskResponseDto>> applyToTask(
    MapTaskIdRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.mapApplyToTask(request.taskId),
      );

      return response.fold((error) => Left(error), (result) {
        final dynamic raw = result.data;
        if (raw is! Map) {
          return Left(
              UnknownException(message: 'Invalid apply-to-task response'));
        }
        final json = Map<String, dynamic>.from(raw);
        final dto = MapApplyToTaskResponseDto.fromJson(json);
        return Right(dto);
      });
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, List<MapTaskDto>>> getNearbyTasks(
    MapNearbyTasksRequest request,
  ) async {
    try {
      final response = await _restClient.get(
        EndPoints.mapTasksNearby,
        queryParameters: <String, dynamic>{
          'lat': request.lat,
          'lon': request.lon,
          'radius_m': request.radiusM,
          'limit': request.limit,
        },
      );

      return response.fold((error) => Left(error), (result) {
        final dynamic raw = result.data;
        if (raw is! Map) {
          return Left(
              UnknownException(message: 'Invalid nearby tasks response'));
        }
        final dto = MapNearbyTasksResponseDto.fromJson(
          Map<String, dynamic>.from(raw),
        );
        return Right(dto.tasks);
      });
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, List<MapTaskDto>>> getAppliedTasks() async {
    try {
      final response = await _restClient.get(
        EndPoints.mapTasksApplied,
      );

      return response.fold((error) => Left(error), (result) {
        final dynamic raw = result.data;
        if (raw is! Map) {
          return Left(
            UnknownException(message: 'Invalid applied tasks response'),
          );
        }
        final dto = MapNearbyTasksResponseDto.fromJson(
          Map<String, dynamic>.from(raw),
        );
        return Right(dto.tasks);
      });
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, List<MapTaskDto>>> getMyTasks() async {
    try {
      final response = await _restClient.get(
        EndPoints.mapTasksMy,
      );

      return response.fold((error) => Left(error), (result) {
        final dynamic raw = result.data;
        if (raw is! Map) {
          return Left(
            UnknownException(message: 'Invalid my tasks response'),
          );
        }
        final dto = MapNearbyTasksResponseDto.fromJson(
          Map<String, dynamic>.from(raw),
        );
        return Right(dto.tasks);
      });
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, MapTaskDto>> getTaskById(
    MapTaskIdRequest request,
  ) async {
    try {
      final response = await _restClient.get(
        EndPoints.mapTaskById(request.taskId),
      );

      return response.fold((error) => Left(error), (result) {
        final dynamic raw = result.data;
        if (raw is! Map) {
          return Left(
              UnknownException(message: 'Invalid task details response'));
        }

        final dto = MapTaskDto.fromJson(
          Map<String, dynamic>.from(raw),
        );
        return Right(dto);
      });
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, List<MapTaskApplicationDto>>>
      getTaskApplications(MapTaskIdRequest request) async {
    try {
      final response = await _restClient.get(
        EndPoints.mapTaskApplications(request.taskId),
      );

      return response.fold((error) => Left(error), (result) {
        final dynamic raw = result.data;
        if (raw is! List) {
          return Left(
              UnknownException(message: 'Invalid task applications response'));
        }

        final applications = raw
            .whereType<Map>()
            .map(
              (item) => MapTaskApplicationDto.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();

        return Right(applications);
      });
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, String>> acceptTaskApplication(
    MapTaskApplicationIdRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.mapAcceptTaskApplication(
          request.taskId,
          request.applicationId,
        ),
      );

      return response.fold((error) => Left(error), (result) {
        final dynamic raw = result.data;
        if (raw is! Map) {
          return Left(
            UnknownException(message: 'Invalid accept application response'),
          );
        }
        final json = Map<String, dynamic>.from(raw);
        return Right((json['status'] ?? '').toString());
      });
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, String>> rejectTaskApplication(
    MapTaskApplicationIdRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.mapRejectTaskApplication(
          request.taskId,
          request.applicationId,
        ),
      );

      return response.fold((error) => Left(error), (result) {
        final dynamic raw = result.data;
        if (raw is! Map) {
          return Left(
            UnknownException(message: 'Invalid reject application response'),
          );
        }
        final json = Map<String, dynamic>.from(raw);
        return Right((json['status'] ?? '').toString());
      });
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, String>> withdrawTaskApplication(
    MapTaskApplicationIdRequest request,
  ) async {
    try {
      final response = await _restClient.delete(
        EndPoints.mapWithdrawTaskApplication(
          request.taskId,
          request.applicationId,
        ),
      );

      return response.fold((error) => Left(error), (result) {
        final dynamic raw = result.data;
        if (raw is! Map) {
          return Left(
            UnknownException(message: 'Invalid withdraw application response'),
          );
        }
        final json = Map<String, dynamic>.from(raw);
        return Right((json['status'] ?? '').toString());
      });
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, MapConfirmCompletionResponseDto>>
      confirmTaskApplication(MapTaskApplicationIdRequest request) async {
    try {
      final response = await _restClient.post(
        EndPoints.mapConfirmTaskApplication(
          request.taskId,
          request.applicationId,
        ),
      );

      return response.fold((error) => Left(error), (result) {
        final dynamic raw = result.data;
        if (raw is! Map) {
          return Left(
            UnknownException(message: 'Invalid confirm completion response'),
          );
        }
        final json = Map<String, dynamic>.from(raw);
        final dto = MapConfirmCompletionResponseDto.fromJson(json);
        return Right(dto);
      });
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  @override
  Future<Either<DomainException, MapVerifyCodeResponseDto>>
      verifyTaskApplicationCode(
    MapTaskApplicationIdRequest target,
    MapVerifyCodeRequest request,
  ) async {
    try {
      final response = await _restClient.post(
        EndPoints.mapVerifyTaskApplicationCode(
          target.taskId,
          target.applicationId,
        ),
        data: request.toJson(),
      );

      return response.fold((error) => Left(error), (result) {
        final dynamic raw = result.data;
        if (raw is! Map) {
          return Left(
              UnknownException(message: 'Invalid verify code response'));
        }
        final json = Map<String, dynamic>.from(raw);
        final dto = MapVerifyCodeResponseDto.fromJson(json);
        return Right(dto);
      });
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }
}
