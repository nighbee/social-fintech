import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:app/src/features/home/domain/requests/media_attachment_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'create_comment_request.freezed.dart';
part 'create_comment_request.g.dart';

@freezed
class CreateCommentRequest extends BaseRequest with _$CreateCommentRequest {
  const factory CreateCommentRequest({
    @JsonKey(name: 'parent_id') String? parentId,
    @JsonKey(name: 'content_text') required String contentText,
    @JsonKey(name: 'media_attachments')
    required List<MediaAttachmentRequest> mediaAttachments,
  }) = _CreateCommentRequest;

  factory CreateCommentRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateCommentRequestFromJson(json);
}
