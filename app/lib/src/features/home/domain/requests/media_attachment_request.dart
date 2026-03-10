import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_attachment_request.freezed.dart';
part 'media_attachment_request.g.dart';

@freezed
class MediaAttachmentRequest extends BaseRequest with _$MediaAttachmentRequest {
  const factory MediaAttachmentRequest({
    required String type,
    required String url,
    @JsonKey(name: 'thumbnail_url') String? thumbnailUrl,
  }) = _MediaAttachmentRequest;

  factory MediaAttachmentRequest.fromJson(Map<String, dynamic> json) =>
      _$MediaAttachmentRequestFromJson(json);
}
