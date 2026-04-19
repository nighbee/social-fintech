import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment_id_request.freezed.dart';
part 'comment_id_request.g.dart';

@freezed
class CommentIdRequest extends BaseRequest with _$CommentIdRequest {
  const factory CommentIdRequest({
    required String commentId,
  }) = _CommentIdRequest;

  factory CommentIdRequest.fromJson(Map<String, dynamic> json) =>
      _$CommentIdRequestFromJson(json);
}
