import 'package:app/src/features/home/domain/entities/comment_response_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'threaded_comments_entity.freezed.dart';
part 'threaded_comments_entity.g.dart';

@freezed
class ThreadedCommentsEntity with _$ThreadedCommentsEntity {
  const factory ThreadedCommentsEntity({
    required List<CommentResponseEntity> comments,
    @Default('') String nextCursor,
  }) = _ThreadedCommentsEntity;

  const factory ThreadedCommentsEntity.empty({
    @Default([]) List<CommentResponseEntity> comments,
    @Default('') String nextCursor,
  }) = _ThreadedCommentsEntityEmpty;

  factory ThreadedCommentsEntity.fromJson(Map<String, dynamic> json) =>
      _$ThreadedCommentsEntityFromJson(json);
}
