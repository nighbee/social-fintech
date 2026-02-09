import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_id_request.freezed.dart';
part 'user_id_request.g.dart';

@freezed
class UserIdRequest with _$UserIdRequest {
  const factory UserIdRequest({required String userId}) = _UserIdRequest;

  factory UserIdRequest.fromJson(Map<String, dynamic> json) =>
      _$UserIdRequestFromJson(json);
}
