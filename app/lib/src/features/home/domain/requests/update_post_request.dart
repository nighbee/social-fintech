import 'package:app/src/core/base/base_models/base_request.dart';

class UpdatePostRequest extends BaseRequest {
  const UpdatePostRequest({
    this.hideLikesCount,
    this.commentPermission,
  });

  final bool? hideLikesCount;
  final String? commentPermission;

  Map<String, dynamic> toPayload() {
    final payload = <String, dynamic>{};

    if (hideLikesCount != null) {
      payload['hide_likes_count'] = hideLikesCount;
    }

    final trimmedCommentPermission = commentPermission?.trim();
    if (trimmedCommentPermission != null &&
        trimmedCommentPermission.isNotEmpty) {
      payload['comment_permission'] = trimmedCommentPermission;
    }

    return payload;
  }
}
