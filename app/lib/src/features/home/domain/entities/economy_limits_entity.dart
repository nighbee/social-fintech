import 'package:freezed_annotation/freezed_annotation.dart';

part 'economy_limits_entity.freezed.dart';
part 'economy_limits_entity.g.dart';

@freezed
class EconomyLimitsEntity with _$EconomyLimitsEntity {
  const EconomyLimitsEntity._();

  const factory EconomyLimitsEntity({
    required int monthlyTransferLimit,
    required int monthlyTransferred,
    required int remaining,
    required String nextReset,
    required bool dailyAccrualClaimed,
    required String nextAccrual,
  }) = _EconomyLimitsEntity;

  const factory EconomyLimitsEntity.empty({
    @Default(0) int monthlyTransferLimit,
    @Default(0) int monthlyTransferred,
    @Default(0) int remaining,
    @Default('') String nextReset,
    @Default(false) bool dailyAccrualClaimed,
    @Default('') String nextAccrual,
  }) = _EconomyLimitsEntityEmpty;

  factory EconomyLimitsEntity.fromJson(Map<String, dynamic> json) =>
      _$EconomyLimitsEntityFromJson(json);

  DateTime? get nextResetDateTime =>
      nextReset.isEmpty ? null : DateTime.tryParse(nextReset);

  DateTime? get nextAccrualDateTime =>
      nextAccrual.isEmpty ? null : DateTime.tryParse(nextAccrual);
}
