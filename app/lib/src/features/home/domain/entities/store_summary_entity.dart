import 'package:app/src/features/home/domain/entities/economy_balance_entity.dart';
import 'package:app/src/features/home/domain/entities/economy_limits_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'store_summary_entity.freezed.dart';
part 'store_summary_entity.g.dart';

enum StoreSummaryStatus { nextFree, storageFull, freeLimitReached }

@freezed
class StoreSummaryEntity with _$StoreSummaryEntity {
  const StoreSummaryEntity._();

  const factory StoreSummaryEntity({
    @Default(EconomyBalanceEntity.empty()) EconomyBalanceEntity balance,
    @Default(EconomyLimitsEntity.empty()) EconomyLimitsEntity limits,
  }) = _StoreSummaryEntity;

  const factory StoreSummaryEntity.empty({
    @Default(EconomyBalanceEntity.empty()) EconomyBalanceEntity balance,
    @Default(EconomyLimitsEntity.empty()) EconomyLimitsEntity limits,
  }) = _StoreSummaryEntityEmpty;

  factory StoreSummaryEntity.fromJson(Map<String, dynamic> json) =>
      _$StoreSummaryEntityFromJson(json);

  static const double assumedFreeSilverCap = 5.0;

  int get silverHonorsCount => balance.silverBalance.floor();

  int get freeSilverHonorsCount => balance.silverFreeBalance.floor();

  bool get hasPurchasedSilver =>
      balance.silverBalance > balance.silverFreeBalance;

  bool get isFreeSilverStorageFull =>
      balance.silverFreeBalance >= assumedFreeSilverCap;

  StoreSummaryStatus get status {
    if (!isFreeSilverStorageFull) {
      return StoreSummaryStatus.nextFree;
    }
    if (hasPurchasedSilver) {
      return StoreSummaryStatus.freeLimitReached;
    }
    return StoreSummaryStatus.storageFull;
  }

  bool get canClaimDailyAccrual =>
      !limits.dailyAccrualClaimed && !isFreeSilverStorageFull;

  DateTime? get nextAccrualDateTime => limits.nextAccrualDateTime;
}
