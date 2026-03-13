import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/domain/entities/report_post_result_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'report_post_result_dto.freezed.dart';
part 'report_post_result_dto.g.dart';

@freezed
class ReportPostResultDto extends BaseDto with _$ReportPostResultDto {
  const ReportPostResultDto._();

  const factory ReportPostResultDto({
    required String status,
  }) = _ReportPostResultDto;

  factory ReportPostResultDto.fromJson(Map<String, dynamic> json) =>
      _$ReportPostResultDtoFromJson(json);

  ReportPostResultEntity toEntity() => ReportPostResultEntity(status: status);
}
