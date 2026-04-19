import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/domain/entities/claim_daily_accrual_result_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'claim_daily_accrual_result_dto.freezed.dart';
part 'claim_daily_accrual_result_dto.g.dart';

@freezed
class ClaimDailyAccrualResultDto extends BaseDto
    with _$ClaimDailyAccrualResultDto {
  const ClaimDailyAccrualResultDto._();

  const factory ClaimDailyAccrualResultDto({
    required bool success,
    required double amount,
    @JsonKey(name: 'new_balance') required double newBalance,
    @JsonKey(name: 'next_claim') required DateTime nextClaim,
  }) = _ClaimDailyAccrualResultDto;

  factory ClaimDailyAccrualResultDto.fromJson(Map<String, dynamic> json) =>
      _$ClaimDailyAccrualResultDtoFromJson(json);

  ClaimDailyAccrualResultEntity toEntity() => ClaimDailyAccrualResultEntity(
        success: success,
        amount: amount,
        newBalance: newBalance,
        nextClaim: nextClaim.toIso8601String(),
      );
}
