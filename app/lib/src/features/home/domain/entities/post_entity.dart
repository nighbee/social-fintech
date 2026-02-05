import 'package:freezed_annotation/freezed_annotation.dart';

part 'post_entity.freezed.dart';
part 'post_entity.g.dart';

@freezed
class PostEntity with _$PostEntity {
  const PostEntity._();

  const factory PostEntity({
    required String id,
    required String userId,
    required String username,
    String? userAvatar,
    required String content,
    @Default([]) List<String> imageUrls,
    @Default(0) int likesCount,
    @Default(0) int commentsCount,
    required DateTime createdAt,
  }) = _PostEntity;

  const factory PostEntity.empty({
    @Default('') String id,
    @Default('') String userId,
    @Default('') String username,
    String? userAvatar,
    @Default('') String content,
    @Default([]) List<String> imageUrls,
    @Default(0) int likesCount,
    @Default(0) int commentsCount,
    required DateTime createdAt,
  }) = _PostEntityEmpty;

  factory PostEntity.fromJson(Map<String, dynamic> json) =>
      _$PostEntityFromJson(json);
}
