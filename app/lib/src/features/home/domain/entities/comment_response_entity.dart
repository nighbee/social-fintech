import 'package:app/src/features/home/domain/entities/author_info_entity.dart';
import 'package:app/src/features/home/domain/entities/media_attachment_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment_response_entity.freezed.dart';
part 'comment_response_entity.g.dart';

@freezed
class CommentResponseEntity with _$CommentResponseEntity {
  const factory CommentResponseEntity({
    required String commentId,
    required AuthorInfoEntity author,
    required String timeAgo,
    required String contentText,
    @Default(MediaAttachmentEntity.empty()) MediaAttachmentEntity mediaAttachment,
    required int replyCount,
  }) = _CommentResponseEntity;

  const factory CommentResponseEntity.empty({
    @Default('') String commentId,
    @Default(AuthorInfoEntity.empty()) AuthorInfoEntity author,
    @Default('') String timeAgo,
    @Default('') String contentText,
    @Default(MediaAttachmentEntity.empty()) MediaAttachmentEntity mediaAttachment,
    @Default(0) int replyCount,
  }) = _CommentResponseEntityEmpty;

  factory CommentResponseEntity.fromJson(Map<String, dynamic> json) =>
      _$CommentResponseEntityFromJson(json);
}
