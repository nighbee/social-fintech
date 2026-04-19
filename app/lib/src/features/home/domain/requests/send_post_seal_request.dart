import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'send_post_seal_request.freezed.dart';
part 'send_post_seal_request.g.dart';

@freezed
class SendPostSealRequest extends BaseRequest with _$SendPostSealRequest {
  const SendPostSealRequest._();

  const factory SendPostSealRequest({
    required int amount,
    @Default('') String comment,
  }) = _SendPostSealRequest;

  factory SendPostSealRequest.fromJson(Map<String, dynamic> json) =>
      _$SendPostSealRequestFromJson(json);

  Map<String, dynamic> toPayload() {
    final payload = toJson();
    final trimmedComment = comment.trim();
    if (trimmedComment.isEmpty) {
      payload.remove('comment');
    } else {
      payload['comment'] = trimmedComment;
    }
    return payload;
  }
}
