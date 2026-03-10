import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/domain/entities/post_metrics_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'post_metrics_dto.freezed.dart';
part 'post_metrics_dto.g.dart';

@freezed
class PostMetricsDto extends BaseDto with _$PostMetricsDto {
  const PostMetricsDto._();
  const factory PostMetricsDto({
    required int likes,
    required int comments,
    required int shares,
    required int silvers,
  }) = _PostMetricsDto;

  factory PostMetricsDto.fromJson(Map<String, dynamic> json) =>
      _$PostMetricsDtoFromJson(json);

  PostMetricsEntity toEntity() => PostMetricsEntity(
        likes: likes,
        comments: comments,
        shares: shares,
        silvers: silvers,
      );
}
