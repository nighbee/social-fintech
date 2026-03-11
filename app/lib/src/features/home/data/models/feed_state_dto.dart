import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/domain/entities/feed_state_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'feed_state_dto.freezed.dart';
part 'feed_state_dto.g.dart';

@freezed
class FeedStateDto extends BaseDto with _$FeedStateDto {
  const FeedStateDto._();
  const factory FeedStateDto({
    @JsonKey(name: 'accumulated_active_seconds')
    required int accumulatedActiveSeconds,
    @JsonKey(name: 'accumulated_break_seconds')
    required int accumulatedBreakSeconds,
    @JsonKey(name: 'action_required') String? actionRequired,
    @JsonKey(name: 'break_seconds_remaining')
    required int breakSecondsRemaining,
    @JsonKey(name: 'is_in_cooldown') required bool isInCooldown,
    @JsonKey(name: 'max_allowed_seconds') required int maxAllowedSeconds,
    @JsonKey(name: 'server_timestamp') required String serverTimestamp,
  }) = _FeedStateDto;

  factory FeedStateDto.fromJson(Map<String, dynamic> json) =>
      _$FeedStateDtoFromJson(json);

  FeedStateEntity toEntity() => FeedStateEntity(
        accumulatedActiveSeconds: accumulatedActiveSeconds,
        accumulatedBreakSeconds: accumulatedBreakSeconds,
        actionRequired: actionRequired ?? '',
        breakSecondsRemaining: breakSecondsRemaining,
        isInCooldown: isInCooldown,
        maxAllowedSeconds: maxAllowedSeconds,
        serverTimestamp: serverTimestamp,
      );
}
