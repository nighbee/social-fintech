import 'package:app/src/features/home/domain/entities/author_info_entity.dart';
import 'package:app/src/features/home/domain/entities/media_attachment_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment_response_entity.freezed.dart';
part 'comment_response_entity.g.dart';

@freezed
class CommentResponseEntity with _$CommentResponseEntity {
  const factory CommentResponseEntity({
    required String commentId,
    @Default('') String parentCommentId,
    @Default('') String rootCommentId,
    required AuthorInfoEntity author,
    required String timeAgo,
    required String createdAt,
    required String contentText,
    @Default(<MediaAttachmentEntity>[])
    List<MediaAttachmentEntity> mediaAttachments,
    required int replyCount,
    required int likesCount,
    required bool viewerHasLiked,
  }) = _CommentResponseEntity;

  const factory CommentResponseEntity.empty({
    @Default('') String commentId,
    @Default('') String parentCommentId,
    @Default('') String rootCommentId,
    @Default(AuthorInfoEntity.empty()) AuthorInfoEntity author,
    @Default('') String timeAgo,
    @Default('') String createdAt,
    @Default('') String contentText,
    @Default(<MediaAttachmentEntity>[])
    List<MediaAttachmentEntity> mediaAttachments,
    @Default(0) int replyCount,
    @Default(0) int likesCount,
    @Default(false) bool viewerHasLiked,
  }) = _CommentResponseEntityEmpty;

  factory CommentResponseEntity.fromJson(Map<String, dynamic> json) =>
      _$CommentResponseEntityFromJson(json);
}
