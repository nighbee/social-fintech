import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'feed_state_sync_request.freezed.dart';
part 'feed_state_sync_request.g.dart';

@freezed
class FeedStateSyncRequest extends BaseRequest with _$FeedStateSyncRequest {
  const factory FeedStateSyncRequest({
    @JsonKey(name: 'delta_seconds') required int deltaSeconds,
    @JsonKey(name: 'device_id') required String deviceId,
  }) = _FeedStateSyncRequest;

  factory FeedStateSyncRequest.fromJson(Map<String, dynamic> json) =>
      _$FeedStateSyncRequestFromJson(json);
}
