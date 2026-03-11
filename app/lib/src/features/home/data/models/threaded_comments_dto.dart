import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/data/models/comment_response_dto.dart';
import 'package:app/src/features/home/domain/entities/threaded_comments_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'threaded_comments_dto.freezed.dart';
part 'threaded_comments_dto.g.dart';

@freezed
class ThreadedCommentsDto extends BaseDto with _$ThreadedCommentsDto {
  const ThreadedCommentsDto._();
  const factory ThreadedCommentsDto({
    required List<CommentResponseDto> comments,
    @JsonKey(name: 'next_cursor') String? nextCursor,
  }) = _ThreadedCommentsDto;

  factory ThreadedCommentsDto.fromJson(Map<String, dynamic> json) =>
      _$ThreadedCommentsDtoFromJson(json);

  ThreadedCommentsEntity toEntity() => ThreadedCommentsEntity(
        comments: comments.map((e) => e.toEntity()).toList(),
        nextCursor: nextCursor ?? '',
      );
}
