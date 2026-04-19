import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'get_post_comments_request.freezed.dart';
part 'get_post_comments_request.g.dart';

@freezed
class GetPostCommentsRequest extends BaseRequest with _$GetPostCommentsRequest {
  const GetPostCommentsRequest._();

  const factory GetPostCommentsRequest({
    required String postId,
    @JsonKey(name: 'parent_id') String? parentId,
    String? cursor,
    @Default(50) int limit,
  }) = _GetPostCommentsRequest;

  factory GetPostCommentsRequest.fromJson(Map<String, dynamic> json) =>
      _$GetPostCommentsRequestFromJson(json);

  Map<String, dynamic> toQuery() {
    final query = <String, dynamic>{'limit': limit};
    if (parentId != null && parentId!.isNotEmpty) {
      query['parent_id'] = parentId;
    }
    if (cursor != null && cursor!.isNotEmpty) {
      query['cursor'] = cursor;
    }
    return query;
  }
}
