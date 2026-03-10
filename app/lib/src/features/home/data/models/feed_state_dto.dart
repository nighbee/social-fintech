import 'package:app/src/features/home/domain/entities/feed_state_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'feed_state_dto.freezed.dart';
part 'feed_state_dto.g.dart';

@freezed
class FeedStateDto with _$FeedStateDto {
  const factory FeedStateDto({
    @JsonKey(name: 'accumulated_active_seconds')
    required int accumulatedActiveSeconds,
    @JsonKey(name: 'accumulated_break_seconds', defaultValue: 0)
    @Default(0)
    int accumulatedBreakSeconds,
    @JsonKey(name: 'action_required') String? actionRequired,
    @JsonKey(name: 'break_seconds_remaining')
    required int breakSecondsRemaining,
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
        accumulatedBreakSeconds: accumulatedBreakSeconds,
        actionRequired: actionRequired ?? '',
        breakSecondsRemaining: breakSecondsRemaining,
        isInCooldown: isInCooldown,
        maxAllowedSeconds: maxAllowedSeconds,
        serverTimestamp: serverTimestamp,
      );
}
