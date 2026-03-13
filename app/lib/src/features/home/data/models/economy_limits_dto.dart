import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/domain/entities/economy_limits_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'economy_limits_dto.freezed.dart';
part 'economy_limits_dto.g.dart';

@freezed
class EconomyLimitsDto extends BaseDto with _$EconomyLimitsDto {
  const EconomyLimitsDto._();

  const factory EconomyLimitsDto({
    @JsonKey(name: 'monthly_transfer_limit') required int monthlyTransferLimit,
    @JsonKey(name: 'monthly_transferred') required int monthlyTransferred,
    @JsonKey(name: 'remaining') required int remaining,
    @JsonKey(name: 'next_reset') required DateTime nextReset,
    @JsonKey(name: 'daily_accrual_claimed') required bool dailyAccrualClaimed,
    @JsonKey(name: 'next_accrual') DateTime? nextAccrual,
  }) = _EconomyLimitsDto;

  factory EconomyLimitsDto.fromJson(Map<String, dynamic> json) =>
      _$EconomyLimitsDtoFromJson(json);

  EconomyLimitsEntity toEntity() => EconomyLimitsEntity(
        monthlyTransferLimit: monthlyTransferLimit,
        monthlyTransferred: monthlyTransferred,
        remaining: remaining,
        nextReset: nextReset.toIso8601String(),
        dailyAccrualClaimed: dailyAccrualClaimed,
        nextAccrual: nextAccrual?.toIso8601String() ?? '',
      );
}
