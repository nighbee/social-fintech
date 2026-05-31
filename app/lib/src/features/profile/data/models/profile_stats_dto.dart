class ProfileStatsDto {
  const ProfileStatsDto({
    required this.userId,
    required this.silverBalanceCentinels,
    required this.goldBalanceCentinels,
    required this.totalSentCentinels,
    required this.totalReceivedCentinels,
  });

  factory ProfileStatsDto.fromJson(Map<String, dynamic> json) {
    return ProfileStatsDto(
      userId: json['user_id'] as String? ?? '',
      silverBalanceCentinels: _asInt(json['silver_balance']),
      goldBalanceCentinels: _asInt(json['gold_balance']),
      totalSentCentinels: _asInt(json['total_sent']),
      totalReceivedCentinels: _asInt(json['total_received']),
    );
  }

  final String userId;
  final int silverBalanceCentinels;
  final int goldBalanceCentinels;
  final int totalSentCentinels;
  final int totalReceivedCentinels;

  int get silverBalanceSeals => _centinelsToSeals(silverBalanceCentinels);
  int get goldBalanceSeals => _centinelsToSeals(goldBalanceCentinels);
  int get totalSentSeals => _centinelsToSeals(totalSentCentinels);
  int get totalReceivedSeals => _centinelsToSeals(totalReceivedCentinels);

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _centinelsToSeals(int value) => (value / 100).round();
}
