import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/data/models/author_info_dto.dart';
import 'package:app/src/features/home/data/models/media_attachment_dto.dart';
import 'package:app/src/features/home/domain/entities/media_attachment_entity.dart';
import 'package:app/src/features/home/domain/entities/comment_response_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment_response_dto.freezed.dart';
part 'comment_response_dto.g.dart';

@freezed
class CommentResponseDto extends BaseDto with _$CommentResponseDto {
  const CommentResponseDto._();
  const factory CommentResponseDto({
    @JsonKey(name: 'comment_id') required String commentId,
    required AuthorInfoDto author,
    @JsonKey(name: 'time_ago') required String timeAgo,
    @JsonKey(name: 'content_text') required String contentText,
    @JsonKey(name: 'media_attachment') MediaAttachmentDto? mediaAttachment,
    @JsonKey(name: 'reply_count') required int replyCount,
  }) = _CommentResponseDto;

  factory CommentResponseDto.fromJson(Map<String, dynamic> json) =>
      _$CommentResponseDtoFromJson(json);

  CommentResponseEntity toEntity() => CommentResponseEntity(
        commentId: commentId,
        author: author.toEntity(),
        timeAgo: timeAgo,
        contentText: contentText,
        mediaAttachment:
            mediaAttachment?.toEntity() ?? const MediaAttachmentEntity.empty(),
        replyCount: replyCount,
      );
}
