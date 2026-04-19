import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/map/domain/entities/map_task_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_task_dto.freezed.dart';
part 'map_task_dto.g.dart';

@freezed
class MapTaskDto extends BaseDto with _$MapTaskDto {
  const MapTaskDto._();

  const factory MapTaskDto({
    @JsonKey(name: 'id', defaultValue: '') required String id,
    @JsonKey(name: 'title', defaultValue: '') required String title,
    @JsonKey(name: 'description') String? description,
    @JsonKey(name: 'creator_username') String? creatorUsername,
    @JsonKey(name: 'creator_avatar_url') String? creatorAvatarUrl,
    @JsonKey(name: 'application_status') String? applicationStatus,
    @JsonKey(name: 'reward', defaultValue: 0) required double reward,
    @JsonKey(name: 'workers_needed', defaultValue: 0)
    required int workersNeeded,
    @JsonKey(name: 'workers_filled', defaultValue: 0)
    required int workersFilled,
    @JsonKey(name: 'status', defaultValue: '') required String status,
    @JsonKey(name: 'auto_shutdown_at') String? autoShutdownAt,
    @JsonKey(name: 'latitude', defaultValue: 0) required double latitude,
    @JsonKey(name: 'longitude', defaultValue: 0) required double longitude,
    @JsonKey(name: 'created_at', defaultValue: '') required String createdAt,
  }) = _MapTaskDto;

  factory MapTaskDto.fromJson(Map<String, dynamic> json) =>
      _$MapTaskDtoFromJson(json);

  MapTaskEntity toEntity() {
    return MapTaskEntity(
      id: id,
      title: title,
      description: description ?? "",
      creatorUsername: creatorUsername ?? '',
      creatorAvatarUrl: creatorAvatarUrl ?? '',
      applicationStatus: applicationStatus ?? '',
      reward: reward,
      workersNeeded: workersNeeded,
      workersFilled: workersFilled,
      status: status,
      autoShutdownAt: autoShutdownAt ?? "",
      latitude: latitude,
      longitude: longitude,
      createdAt: createdAt,
    );
  }
}
