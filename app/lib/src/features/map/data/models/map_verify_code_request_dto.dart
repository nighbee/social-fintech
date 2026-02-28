import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_verify_code_request_dto.freezed.dart';
part 'map_verify_code_request_dto.g.dart';

@freezed
class MapVerifyCodeRequestDto extends BaseDto with _$MapVerifyCodeRequestDto {
  const MapVerifyCodeRequestDto._();

  const factory MapVerifyCodeRequestDto({
    @JsonKey(name: 'code', defaultValue: '') required String code,
  }) = _MapVerifyCodeRequestDto;

  factory MapVerifyCodeRequestDto.fromJson(Map<String, dynamic> json) =>
      _$MapVerifyCodeRequestDtoFromJson(json);
}
