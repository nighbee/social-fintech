import 'package:app/src/features/home/domain/entities/post_response_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'feed_entity.freezed.dart';
part 'feed_entity.g.dart';

@freezed
class FeedEntity with _$FeedEntity {
  const factory FeedEntity({
    required List<PostResponseEntity> items,
    @Default('') String nextCursor,
  }) = _FeedEntity;

  const factory FeedEntity.empty({
    @Default([]) List<PostResponseEntity> items,
    @Default('') String nextCursor,
  }) = _FeedEntityEmpty;

  factory FeedEntity.fromJson(Map<String, dynamic> json) =>
      _$FeedEntityFromJson(json);
}
