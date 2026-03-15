import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/data/models/author_info_dto.dart';
import 'package:app/src/features/home/data/models/media_attachment_dto.dart';
import 'package:app/src/features/home/data/models/permissions_dto.dart';
import 'package:app/src/features/home/data/models/post_metrics_dto.dart';
import 'package:app/src/features/home/domain/entities/post_response_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'post_response_dto.freezed.dart';
part 'post_response_dto.g.dart';

@freezed
class PostResponseDto extends BaseDto with _$PostResponseDto {
  const PostResponseDto._();
  const factory PostResponseDto({
    @JsonKey(name: 'post_id') required String postId,
    required AuthorInfoDto author,
    @JsonKey(name: 'time_ago') required String timeAgo,
    required String visibility,
    @JsonKey(name: 'content_text') required String contentText,
    @JsonKey(name: 'media_attachments')
    required List<MediaAttachmentDto> mediaAttachments,
    required PostMetricsDto metrics,
    required PermissionsDto permissions,
    @JsonKey(name: 'hide_likes_count') required bool hideLikesCount,
    @JsonKey(name: 'is_own_post') required bool isOwnPost,
    @JsonKey(name: 'viewer_has_liked') required bool viewerHasLiked,
  }) = _PostResponseDto;

  factory PostResponseDto.fromJson(Map<String, dynamic> json) =>
      _$PostResponseDtoFromJson(json);

  PostResponseEntity toEntity() => PostResponseEntity(
        postId: postId,
        author: author.toEntity(),
        timeAgo: timeAgo,
        visibility: visibility,
        contentText: contentText,
        mediaAttachments: mediaAttachments.map((e) => e.toEntity()).toList(),
        metrics: metrics.toEntity(),
        permissions: permissions.toEntity(),
        hideLikesCount: hideLikesCount,
        isOwnPost: isOwnPost,
        viewerHasLiked: viewerHasLiked,
      );
}
