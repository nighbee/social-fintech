import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/domain/entities/comment_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment_dto.freezed.dart';
part 'comment_dto.g.dart';

@freezed
class CommentDto extends BaseDto with _$CommentDto {
  const CommentDto._();
  const factory CommentDto({
    required String id,
    @JsonKey(name: 'post_id') required String postId,
    @JsonKey(name: 'parent_comment_id') String? parentCommentId,
    @JsonKey(name: 'root_comment_id') String? rootCommentId,
    @JsonKey(name: 'user_id') required String userId,
    required String username,
    @JsonKey(name: 'user_avatar') String? userAvatar,
    required String content,
    @JsonKey(name: 'image_urls') @Default([]) List<String> imageUrls,
    @JsonKey(name: 'likes_count') @Default(0) int likesCount,
    @JsonKey(name: 'is_liked') @Default(false) bool isLiked,
    @JsonKey(name: 'replies_count') @Default(0) int repliesCount,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
  }) = _CommentDto;

  factory CommentDto.fromJson(Map<String, dynamic> json) =>
      _$CommentDtoFromJson(json);

  CommentEntity toEntity() => CommentEntity(
        id: id,
        postId: postId,
        parentCommentId: parentCommentId,
        rootCommentId: rootCommentId,
        userId: userId,
        username: username,
        userAvatar: userAvatar,
        content: content,
        imageUrls: imageUrls,
        likesCount: likesCount,
        isLiked: isLiked,
        repliesCount: repliesCount,
        createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
        updatedAt: updatedAt != null ? DateTime.tryParse(updatedAt!) : null,
      );
}
