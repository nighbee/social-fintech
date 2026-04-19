import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/domain/entities/economy_balance_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'economy_balance_dto.freezed.dart';
part 'economy_balance_dto.g.dart';

@freezed
class EconomyBalanceDto extends BaseDto with _$EconomyBalanceDto {
  const EconomyBalanceDto._();

  const factory EconomyBalanceDto({
    @JsonKey(name: 'silver_balance') required double silverBalance,
    @JsonKey(name: 'silver_free_balance') required double silverFreeBalance,
    @JsonKey(name: 'gold_balance') required double goldBalance,
    @JsonKey(name: 'last_accrual_at') DateTime? lastAccrualAt,
  }) = _EconomyBalanceDto;

  factory EconomyBalanceDto.fromJson(Map<String, dynamic> json) =>
      _$EconomyBalanceDtoFromJson(json);

  EconomyBalanceEntity toEntity() => EconomyBalanceEntity(
        silverBalance: silverBalance,
        silverFreeBalance: silverFreeBalance,
        goldBalance: goldBalance,
        lastAccrualAt: lastAccrualAt?.toIso8601String() ?? '',
      );
}
