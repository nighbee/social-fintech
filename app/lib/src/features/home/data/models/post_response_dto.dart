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
      _$PostResponseDtoFromJson(_normalizePostResponseJson(json));

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

Map<String, dynamic> _normalizePostResponseJson(Map<String, dynamic> json) {
  final normalized = Map<String, dynamic>.from(json);
  final author = _stringKeyedMap(normalized['author']);
  final metrics = _stringKeyedMap(normalized['metrics']);
  final permissions = _stringKeyedMap(normalized['permissions']);
  final media = normalized['media_attachments'];

  normalized
    ..['post_id'] = _stringValue(normalized['post_id'])
    ..['author'] = <String, dynamic>{
      ...author,
      'id': _stringValue(author['id']),
      'username': _stringValue(author['username']),
      'full_name': _stringValue(author['full_name']),
      'profile_pic_url': _stringValue(author['profile_pic_url']),
      'rank': _stringValue(author['rank']),
      'rank_sub_level': _nullableStringValue(author['rank_sub_level']),
    }
    ..['time_ago'] = _stringValue(normalized['time_ago'])
    ..['visibility'] = _stringValue(
      normalized['visibility'],
      fallback: 'ANYONE',
    )
    ..['content_text'] = _stringValue(normalized['content_text'])
    ..['media_attachments'] = media is List
        ? media
            .whereType<Map>()
            .map((item) => _normalizeMediaAttachment(item))
            .toList(growable: false)
        : const <Map<String, dynamic>>[]
    ..['metrics'] = <String, dynamic>{
      'likes': _intValue(metrics['likes']),
      'comments': _intValue(metrics['comments']),
      'shares': _intValue(metrics['shares']),
      'silvers': _intValue(metrics['silvers']),
    }
    ..['permissions'] = <String, dynamic>{
      'can_comment': _boolValue(
        permissions['can_comment'],
        fallback: true,
      ),
    }
    ..['hide_likes_count'] = _boolValue(normalized['hide_likes_count'])
    ..['is_own_post'] = _boolValue(normalized['is_own_post'])
    ..['viewer_has_liked'] = _boolValue(normalized['viewer_has_liked']);

  return normalized;
}

Map<String, dynamic> _normalizeMediaAttachment(Map<dynamic, dynamic> raw) {
  final media = raw.map((key, value) => MapEntry(key.toString(), value));
  final url = _stringValue(media['video_1080p_url']).isNotEmpty
      ? _stringValue(media['video_1080p_url'])
      : _stringValue(media['url']);

  return <String, dynamic>{
    ...media,
    'type': _stringValue(media['type'], fallback: 'image'),
    'url': url,
    'video_1080p_url': url,
    'thumbnail_url': _nullableStringValue(media['thumbnail_url']),
  };
}

Map<String, dynamic> _stringKeyedMap(dynamic value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

String _stringValue(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final result = value.toString();
  return result == 'null' ? fallback : result;
}

String? _nullableStringValue(dynamic value) {
  final result = _stringValue(value);
  return result.isEmpty ? null : result;
}

int _intValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _boolValue(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    if (value.toLowerCase() == 'true') return true;
    if (value.toLowerCase() == 'false') return false;
  }
  return fallback;
}
