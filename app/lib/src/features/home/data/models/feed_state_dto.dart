import 'package:app/src/features/home/domain/entities/feed_state_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'feed_state_dto.freezed.dart';
part 'feed_state_dto.g.dart';

@freezed
class FeedStateDto with _$FeedStateDto {
  const factory FeedStateDto({
    @JsonKey(name: 'accumulated_active_seconds')
    required int accumulatedActiveSeconds,
    @JsonKey(name: 'action_required') required String actionRequired,
    @JsonKey(name: 'is_in_cooldown') required bool isInCooldown,
    @JsonKey(name: 'max_allowed_seconds') required int maxAllowedSeconds,
    @JsonKey(name: 'server_timestamp') required String serverTimestamp,
  }) = _FeedStateDto;

  factory FeedStateDto.fromJson(Map<String, dynamic> json) =>
      _$FeedStateDtoFromJson(json);
}

extension FeedStateDtoX on FeedStateDto {
  FeedStateEntity toEntity() => FeedStateEntity(
        accumulatedActiveSeconds: accumulatedActiveSeconds,
        actionRequired: actionRequired,
        isInCooldown: isInCooldown,
        maxAllowedSeconds: maxAllowedSeconds,
        serverTimestamp: serverTimestamp,
      );
}
