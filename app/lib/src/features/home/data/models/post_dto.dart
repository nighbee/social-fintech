import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'post_dto.freezed.dart';
part 'post_dto.g.dart';

@freezed
class PostDto extends BaseDto with _$PostDto {
  const PostDto._();
  const factory PostDto({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    required String username,
    @JsonKey(name: 'user_avatar') String? userAvatar,
    required String content,
    @JsonKey(name: 'image_urls') @Default([]) List<String> imageUrls,
    @JsonKey(name: 'likes_count') @Default(0) int likesCount,
    @JsonKey(name: 'comments_count') @Default(0) int commentsCount,
    @JsonKey(name: 'is_liked') @Default(false) bool isLiked,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _PostDto;

  factory PostDto.fromJson(Map<String, dynamic> json) =>
      _$PostDtoFromJson(json);

  PostEntity toEntity() => PostEntity(
    id: id,
    userId: userId,
    username: username,
    userAvatar: userAvatar,
    content: content,
    imageUrls: imageUrls,
    likesCount: likesCount,
    commentsCount: commentsCount,
    isLiked: isLiked,
    createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
  );
}
