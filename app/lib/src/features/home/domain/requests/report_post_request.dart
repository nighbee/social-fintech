import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'report_post_request.freezed.dart';
part 'report_post_request.g.dart';

@freezed
class ReportPostRequest extends BaseRequest with _$ReportPostRequest {
  const ReportPostRequest._();

  const factory ReportPostRequest({
    required String reason,
    String? description,
  }) = _ReportPostRequest;

  factory ReportPostRequest.fromJson(Map<String, dynamic> json) =>
      _$ReportPostRequestFromJson(json);

  Map<String, dynamic> toPayload() {
    final payload = toJson();
    final trimmedDescription = description?.trim();
    if (trimmedDescription == null || trimmedDescription.isEmpty) {
      payload.remove('description');
    } else {
      payload['description'] = trimmedDescription;
    }
    payload['reason'] = reason.trim();
    return payload;
  }
}
