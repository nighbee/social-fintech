import 'package:app/src/features/profile/presentation/models/profile_post_item.dart';

List<ProfilePostItem> mapProfilePostsGridItems(dynamic payload) {
  final items = payload is Map<String, dynamic> ? payload['items'] : null;
  final mapped = <ProfilePostItem>[];

  if (items is! List) {
    return mapped;
  }

  for (final item in items) {
    if (item is! Map<String, dynamic>) continue;
    final postId = (item['post_id'] ?? '').toString();
    final thumbnailUrl = (item['thumbnail_url'] ?? '').toString();
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
