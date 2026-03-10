import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'get_post_likes_request.freezed.dart';
part 'get_post_likes_request.g.dart';

@freezed
class GetPostLikesRequest extends BaseRequest with _$GetPostLikesRequest {
  const GetPostLikesRequest._();

  const factory GetPostLikesRequest({
    required String postId,
    String? cursor,
    @Default(50) int limit,
  }) = _GetPostLikesRequest;

  factory GetPostLikesRequest.fromJson(Map<String, dynamic> json) =>
      _$GetPostLikesRequestFromJson(json);

  Map<String, dynamic> toQuery() {
    final query = <String, dynamic>{'limit': limit};
    if (cursor != null && cursor!.isNotEmpty) {
      query['cursor'] = cursor;
    }
    return query;
  }
}
