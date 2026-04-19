import 'package:app/src/core/base/base_models/base_request.dart';

class GetProfilePostsRequest extends BaseRequest {
  const GetProfilePostsRequest({
    required this.userId,
    this.cursor,
    this.anchorPostId,
    this.limit = 20,
  });

  final String userId;
  final String? cursor;
  final String? anchorPostId;
  final int limit;

  Map<String, dynamic> toQuery() {
    final query = <String, dynamic>{'limit': limit};
    final trimmedCursor = cursor?.trim() ?? '';
    final trimmedAnchorPostId = anchorPostId?.trim() ?? '';
    if (trimmedAnchorPostId.isNotEmpty) {
      query['anchor_post_id'] = trimmedAnchorPostId;
    }
    if (trimmedCursor.isNotEmpty) {
      query['cursor'] = trimmedCursor;
    }
    return query;
  }
}
