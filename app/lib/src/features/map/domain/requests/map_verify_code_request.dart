import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_verify_code_request.freezed.dart';
part 'map_verify_code_request.g.dart';

@freezed
class MapVerifyCodeRequest extends BaseRequest with _$MapVerifyCodeRequest {
  const factory MapVerifyCodeRequest({
    @JsonKey(name: 'code') required String code,
  }) = _MapVerifyCodeRequest;

  factory MapVerifyCodeRequest.fromJson(Map<String, dynamic> json) =>
      _$MapVerifyCodeRequestFromJson(json);
}
