import 'package:freezed_annotation/freezed_annotation.dart';

part 'post_metrics_entity.freezed.dart';
part 'post_metrics_entity.g.dart';

@freezed
class PostMetricsEntity with _$PostMetricsEntity {
  const factory PostMetricsEntity({
    required int likes,
    required int comments,
    required int shares,
    required int silvers,
  }) = _PostMetricsEntity;

  const factory PostMetricsEntity.empty({
    @Default(0) int likes,
    @Default(0) int comments,
    @Default(0) int shares,
    @Default(0) int silvers,
  }) = _PostMetricsEntityEmpty;

  factory PostMetricsEntity.fromJson(Map<String, dynamic> json) =>
      _$PostMetricsEntityFromJson(json);
}
