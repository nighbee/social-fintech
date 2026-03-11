import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'post_id_request.freezed.dart';
part 'post_id_request.g.dart';

@freezed
class PostIdRequest extends BaseRequest with _$PostIdRequest {
  const factory PostIdRequest({
    required String postId,
  }) = _PostIdRequest;

  factory PostIdRequest.fromJson(Map<String, dynamic> json) =>
      _$PostIdRequestFromJson(json);
}
