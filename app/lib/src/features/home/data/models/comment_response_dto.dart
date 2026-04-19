import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/data/models/author_info_dto.dart';
import 'package:app/src/features/home/data/models/media_attachment_dto.dart';
import 'package:app/src/features/home/domain/entities/comment_response_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment_response_dto.freezed.dart';
part 'comment_response_dto.g.dart';

@freezed
class CommentResponseDto extends BaseDto with _$CommentResponseDto {
  const CommentResponseDto._();
  const factory CommentResponseDto({
    @JsonKey(name: 'comment_id') required String commentId,
    @JsonKey(name: 'parent_comment_id') String? parentCommentId,
    @JsonKey(name: 'root_comment_id') String? rootCommentId,
    required AuthorInfoDto author,
    @JsonKey(name: 'time_ago') required String timeAgo,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'content_text') required String contentText,
    @JsonKey(name: 'media_attachments')
    List<MediaAttachmentDto>? mediaAttachments,
    @JsonKey(name: 'reply_count') required int replyCount,
    @JsonKey(name: 'likes_count') required int likesCount,
    @JsonKey(name: 'viewer_has_liked') required bool viewerHasLiked,
  }) = _CommentResponseDto;

  factory CommentResponseDto.fromJson(Map<String, dynamic> json) =>
      _$CommentResponseDtoFromJson(json);

  CommentResponseEntity toEntity() => CommentResponseEntity(
        commentId: commentId,
        parentCommentId: parentCommentId ?? '',
        rootCommentId: rootCommentId ?? '',
        author: author.toEntity(),
        timeAgo: timeAgo,
        createdAt: createdAt,
        contentText: contentText,
        mediaAttachments: (mediaAttachments ?? const <MediaAttachmentDto>[])
            .map((item) => item.toEntity())
            .toList(),
        replyCount: replyCount,
        likesCount: likesCount,
        viewerHasLiked: viewerHasLiked,
      );
}
