import 'package:app/src/core/base/base_models/base_request.dart';

class GetMyProfilePostsRequest extends BaseRequest {
  const GetMyProfilePostsRequest({
    this.cursor,
    this.anchorPostId,
    this.limit = 10,
  });

  final String? cursor;
  final String? anchorPostId;
  final int limit;

  Map<String, dynamic> toQuery() {
    final query = <String, dynamic>{'limit': limit};
    final trimmedAnchorPostId = anchorPostId?.trim() ?? '';
    final trimmedCursor = cursor?.trim() ?? '';

    if (trimmedAnchorPostId.isNotEmpty) {
      query['anchor_post_id'] = trimmedAnchorPostId;
    }
    if (trimmedCursor.isNotEmpty) {
      query['cursor'] = trimmedCursor;
    }

    return query;
  }
}
