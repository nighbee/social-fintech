import 'package:freezed_annotation/freezed_annotation.dart';

part 'claim_daily_accrual_result_entity.freezed.dart';
part 'claim_daily_accrual_result_entity.g.dart';

@freezed
class ClaimDailyAccrualResultEntity with _$ClaimDailyAccrualResultEntity {
  const ClaimDailyAccrualResultEntity._();

  const factory ClaimDailyAccrualResultEntity({
    required bool success,
    required double amount,
    required double newBalance,
    required String nextClaim,
  }) = _ClaimDailyAccrualResultEntity;

  const factory ClaimDailyAccrualResultEntity.empty({
    @Default(false) bool success,
    @Default(0) double amount,
    @Default(0) double newBalance,
    @Default('') String nextClaim,
  }) = _ClaimDailyAccrualResultEntityEmpty;

  factory ClaimDailyAccrualResultEntity.fromJson(Map<String, dynamic> json) =>
      _$ClaimDailyAccrualResultEntityFromJson(json);

  DateTime? get nextClaimDateTime =>
      nextClaim.isEmpty ? null : DateTime.tryParse(nextClaim);
}
