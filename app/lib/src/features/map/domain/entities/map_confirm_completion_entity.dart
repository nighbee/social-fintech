import 'package:app/src/core/base/base_models/base_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_confirm_completion_entity.freezed.dart';

@freezed
class MapConfirmCompletionEntity extends BaseEntity
    with _$MapConfirmCompletionEntity {
  const factory MapConfirmCompletionEntity({
    required String taskId,
    required String applicationId,
    required double reward,
    required String taskStatus,
  }) = _MapConfirmCompletionEntity;

  const factory MapConfirmCompletionEntity.empty({
    @Default('') String taskId,
    @Default('') String applicationId,
    @Default(0.0) double reward,
    @Default('') String taskStatus,
  }) = _MapConfirmCompletionEntityEmpty;
}
