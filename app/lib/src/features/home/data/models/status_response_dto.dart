import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/domain/entities/status_response_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'status_response_dto.freezed.dart';
part 'status_response_dto.g.dart';

@freezed
class StatusResponseDto extends BaseDto with _$StatusResponseDto {
  const StatusResponseDto._();
  const factory StatusResponseDto({
    required String status,
    String? error,
    String? message,
  }) = _StatusResponseDto;

  factory StatusResponseDto.fromJson(Map<String, dynamic> json) =>
      _$StatusResponseDtoFromJson(json);

  StatusResponseEntity toEntity() => StatusResponseEntity(
        status: status,
        error: error ?? '',
        message: message ?? '',
      );
}
