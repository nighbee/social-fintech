import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment_entity.freezed.dart';
part 'comment_entity.g.dart';

@freezed
class CommentEntity with _$CommentEntity {
  const CommentEntity._();

  const factory CommentEntity({
    required String id,
    required String postId,
    String? parentCommentId,
    String? rootCommentId,
    required String userId,
    required String username,
    String? userAvatar,
    required String content,
    @Default([]) List<String> imageUrls,
    @Default(0) int likesCount,
    @Default(false) bool isLiked,
    @Default(0) int repliesCount,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _CommentEntity;

  factory CommentEntity.fromJson(Map<String, dynamic> json) =>
      _$CommentEntityFromJson(json);
}
