import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:app/src/features/home/domain/requests/media_attachment_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'create_post_request.freezed.dart';
part 'create_post_request.g.dart';

@freezed
class CreatePostRequest extends BaseRequest with _$CreatePostRequest {
  @JsonSerializable(explicitToJson: true)
  const factory CreatePostRequest({
    required String caption,
    @JsonKey(name: 'media_attachments')
    @Default([])
    List<MediaAttachmentRequest> mediaAttachments,
    required String visibility,
    @JsonKey(name: 'hide_likes_count') @Default(false) bool hideLikesCount,
    @JsonKey(name: 'comment_permission') required String commentPermission,
  }) = _CreatePostRequest;

  factory CreatePostRequest.fromJson(Map<String, dynamic> json) =>
      _$CreatePostRequestFromJson(json);
}
