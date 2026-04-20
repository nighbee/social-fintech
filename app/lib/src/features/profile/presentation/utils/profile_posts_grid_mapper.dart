import 'package:app/src/features/profile/presentation/models/profile_post_item.dart';

List<ProfilePostItem> mapProfilePostsGridItems(dynamic payload) {
  Map<String, dynamic>? asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  final root = asMap(payload);
  final nestedData = asMap(root?['data']);
  final items = root?['items'] ?? nestedData?['items'];
  final mapped = <ProfilePostItem>[];

  if (items is! List) {
    return mapped;
  }

  for (final item in items) {
    final map = asMap(item);
    if (map == null) continue;
    final postId = (map['post_id'] ?? map['id'] ?? '').toString();
    final thumbnailUrl = (map['thumbnail_url'] ??
            map['thumb_url'] ??
            map['preview_url'] ??
            map['cover_url'] ??
            map['image_url'] ??
            map['url'] ??
            map['video_1080p_url'] ??
            map['video_480p_url'] ??
            '')
        .toString();
    if (postId.isEmpty) continue;

    mapped.add(
      ProfilePostItem(
        id: postId,
        imageUrls: thumbnailUrl.isEmpty ? const <String>[] : [thumbnailUrl],
      ),
    );
  }

  return mapped;
}
