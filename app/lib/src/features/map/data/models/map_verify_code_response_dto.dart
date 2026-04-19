import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/map/domain/entities/map_verify_code_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_verify_code_response_dto.freezed.dart';
part 'map_verify_code_response_dto.g.dart';

@freezed
class MapVerifyCodeResponseDto extends BaseDto with _$MapVerifyCodeResponseDto {
  const MapVerifyCodeResponseDto._();

  const factory MapVerifyCodeResponseDto({
    @JsonKey(name: 'application_id', defaultValue: '')
    required String applicationId,
    @JsonKey(name: 'status', defaultValue: '') required String status,
  }) = _MapVerifyCodeResponseDto;

  factory MapVerifyCodeResponseDto.fromJson(Map<String, dynamic> json) =>
      _$MapVerifyCodeResponseDtoFromJson(json);

  MapVerifyCodeEntity toEntity() {
    return MapVerifyCodeEntity(
      applicationId: applicationId,
      status: status,
    );
  }
}
