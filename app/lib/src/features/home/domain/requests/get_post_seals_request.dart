import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'get_post_seals_request.freezed.dart';
part 'get_post_seals_request.g.dart';

@freezed
class GetPostSealsRequest extends BaseRequest with _$GetPostSealsRequest {
  const GetPostSealsRequest._();

  const factory GetPostSealsRequest({
    required String postId,
    String? cursor,
    @Default(50) int limit,
  }) = _GetPostSealsRequest;

  factory GetPostSealsRequest.fromJson(Map<String, dynamic> json) =>
      _$GetPostSealsRequestFromJson(json);

  Map<String, dynamic> toQuery() {
    final query = <String, dynamic>{'limit': limit};
    if (cursor != null && cursor!.isNotEmpty) {
      query['cursor'] = cursor;
    }
    return query;
  }
}
