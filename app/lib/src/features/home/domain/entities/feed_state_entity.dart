import 'package:freezed_annotation/freezed_annotation.dart';

part 'feed_state_entity.freezed.dart';
part 'feed_state_entity.g.dart';

@freezed
class FeedStateEntity with _$FeedStateEntity {
  const FeedStateEntity._();

  const factory FeedStateEntity({
    required int accumulatedActiveSeconds,
    required String actionRequired,
    required bool isInCooldown,
    required int maxAllowedSeconds,
    required String serverTimestamp,
  }) = _FeedStateEntity;

  const factory FeedStateEntity.empty({
    @Default(0) int accumulatedActiveSeconds,
    @Default('') String actionRequired,
    @Default(false) bool isInCooldown,
    @Default(0) int maxAllowedSeconds,
    @Default('') String serverTimestamp,
  }) = _FeedStateEntityEmpty;

  factory FeedStateEntity.fromJson(Map<String, dynamic> json) =>
      _$FeedStateEntityFromJson(json);
}
