import 'package:app/src/features/home/domain/entities/author_info_entity.dart';
import 'package:app/src/features/home/domain/entities/media_attachment_entity.dart';
import 'package:app/src/features/home/domain/entities/permissions_entity.dart';
import 'package:app/src/features/home/domain/entities/post_metrics_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'post_response_entity.freezed.dart';
part 'post_response_entity.g.dart';

@freezed
class PostResponseEntity with _$PostResponseEntity {
  const factory PostResponseEntity({
    required String postId,
    required AuthorInfoEntity author,
    required String timeAgo,
    required String visibility,
    required String contentText,
    required List<MediaAttachmentEntity> mediaAttachments,
    required PostMetricsEntity metrics,
    required PermissionsEntity permissions,
    required bool hideLikesCount,
    required bool isOwnPost,
    required bool viewerHasLiked,
  }) = _PostResponseEntity;

  const factory PostResponseEntity.empty({
    @Default('') String postId,
    @Default(AuthorInfoEntity.empty()) AuthorInfoEntity author,
    @Default('') String timeAgo,
    @Default('') String visibility,
    @Default('') String contentText,
    @Default([]) List<MediaAttachmentEntity> mediaAttachments,
    @Default(PostMetricsEntity.empty()) PostMetricsEntity metrics,
    @Default(PermissionsEntity.empty()) PermissionsEntity permissions,
    @Default(false) bool hideLikesCount,
    @Default(false) bool isOwnPost,
    @Default(false) bool viewerHasLiked,
  }) = _PostResponseEntityEmpty;

  factory PostResponseEntity.fromJson(Map<String, dynamic> json) =>
      _$PostResponseEntityFromJson(json);
}
