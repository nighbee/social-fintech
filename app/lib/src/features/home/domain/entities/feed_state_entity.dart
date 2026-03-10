import 'package:freezed_annotation/freezed_annotation.dart';

part 'feed_state_entity.freezed.dart';
part 'feed_state_entity.g.dart';

@freezed
class FeedStateEntity with _$FeedStateEntity {
  const FeedStateEntity._();

  const factory FeedStateEntity({
    required int accumulatedActiveSeconds,
    @Default(0) int accumulatedBreakSeconds,
    required String actionRequired,
    required int breakSecondsRemaining,
    required bool isInCooldown,
    required int maxAllowedSeconds,
    required String serverTimestamp,
  }) = _FeedStateEntity;

  const factory FeedStateEntity.empty({
    @Default(0) int accumulatedActiveSeconds,
    @Default(0) int accumulatedBreakSeconds,
    @Default('') String actionRequired,
    @Default(0) int breakSecondsRemaining,
    @Default(false) bool isInCooldown,
    @Default(0) int maxAllowedSeconds,
    @Default('') String serverTimestamp,
  }) = _FeedStateEntityEmpty;

  factory FeedStateEntity.fromJson(Map<String, dynamic> json) =>
      _$FeedStateEntityFromJson(json);

  String get normalizedActionRequired {
    final value = actionRequired.toLowerCase().trim();
    return value.replaceAll('_', '').replaceAll(' ', '');
  }

  bool get shouldTriggerFriction => normalizedActionRequired == 'triggerfriction';

  bool get shouldEnforceCooldown =>
      isInCooldown || normalizedActionRequired == 'enforcecooldown';

  int get safeBreakSecondsRemaining =>
      breakSecondsRemaining < 0 ? 0 : breakSecondsRemaining;

  double get frictionPercent {
    if (maxAllowedSeconds <= 0) {
      return 0;
    }
    return (accumulatedActiveSeconds / maxAllowedSeconds).clamp(0.0, 1.0);
  }
}
