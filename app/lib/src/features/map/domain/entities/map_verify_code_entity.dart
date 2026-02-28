import 'package:app/src/core/base/base_models/base_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_verify_code_entity.freezed.dart';

@freezed
class MapVerifyCodeEntity extends BaseEntity with _$MapVerifyCodeEntity {
  const factory MapVerifyCodeEntity({
    required String applicationId,
    required String status,
  }) = _MapVerifyCodeEntity;
}
