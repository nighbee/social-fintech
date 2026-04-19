import 'package:app/src/core/base/base_models/base_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'report_post_result_entity.freezed.dart';
part 'report_post_result_entity.g.dart';

@freezed
class ReportPostResultEntity extends BaseEntity with _$ReportPostResultEntity {
  const ReportPostResultEntity._();

  const factory ReportPostResultEntity({
    required String status,
  }) = _ReportPostResultEntity;

  factory ReportPostResultEntity.empty() =>
      const ReportPostResultEntity(status: '');

  factory ReportPostResultEntity.fromJson(Map<String, dynamic> json) =>
      _$ReportPostResultEntityFromJson(json);
}
