import 'package:freezed_annotation/freezed_annotation.dart';

part 'economy_balance_entity.freezed.dart';
part 'economy_balance_entity.g.dart';

@freezed
class EconomyBalanceEntity with _$EconomyBalanceEntity {
  const EconomyBalanceEntity._();

  const factory EconomyBalanceEntity({
    required double silverBalance,
    required double silverFreeBalance,
    required double goldBalance,
    required String lastAccrualAt,
  }) = _EconomyBalanceEntity;

  const factory EconomyBalanceEntity.empty({
    @Default(0) double silverBalance,
    @Default(0) double silverFreeBalance,
    @Default(0) double goldBalance,
    @Default('') String lastAccrualAt,
  }) = _EconomyBalanceEntityEmpty;

  factory EconomyBalanceEntity.fromJson(Map<String, dynamic> json) =>
      _$EconomyBalanceEntityFromJson(json);

  DateTime? get lastAccrualAtDateTime =>
      lastAccrualAt.isEmpty ? null : DateTime.tryParse(lastAccrualAt);
}
