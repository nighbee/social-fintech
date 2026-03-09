import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'feed_request.freezed.dart';
part 'feed_request.g.dart';

@freezed
class FeedRequest extends BaseRequest with _$FeedRequest {
  const FeedRequest._();

  const factory FeedRequest({
    String? cursor,
    @Default(20) int limit,
  }) = _FeedRequest;

  factory FeedRequest.fromJson(Map<String, dynamic> json) =>
      _$FeedRequestFromJson(json);

  Map<String, dynamic> toQuery() {
    final query = <String, dynamic>{'limit': limit};
    if (cursor != null && cursor!.isNotEmpty) {
      query['cursor'] = cursor;
    }
    return query;
  }
}
