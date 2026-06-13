class CurrentSeasonDto {
  const CurrentSeasonDto({
    required this.id,
    required this.year,
    required this.half,
    required this.startsAt,
    required this.endsAt,
    required this.secondsRemaining,
  });

  factory CurrentSeasonDto.fromJson(Map<String, dynamic> json) {
    final season = json['season'] as Map<String, dynamic>? ?? const {};
    return CurrentSeasonDto(
      id: season['id'] as String? ?? '',
      year: _asInt(season['season_year']),
      half: _asInt(season['season_half']),
      startsAt: DateTime.tryParse(season['starts_at'] as String? ?? ''),
      endsAt: DateTime.tryParse(season['ends_at'] as String? ?? ''),
      secondsRemaining: _asInt(json['seconds_remaining']),
    );
  }

  final String id;
  final int year;
  final int half;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int secondsRemaining;
}

class SeasonArchiveDto {
  const SeasonArchiveDto({
    required this.seasonId,
    required this.year,
    required this.half,
    required this.startsAt,
    required this.endsAt,
    required this.receivedSeals,
    required this.givenSeals,
    required this.rankName,
    required this.rankQuality,
    required this.rankLevel,
  });

  factory SeasonArchiveDto.fromJson(Map<String, dynamic> json) {
    final payload =
        json['snapshot_payload'] as Map<String, dynamic>? ?? const {};
    return SeasonArchiveDto(
      seasonId: json['season_id'] as String? ?? '',
      year: _asInt(json['season_year']),
      half: _asInt(json['season_half']),
      startsAt: DateTime.tryParse(json['starts_at'] as String? ?? ''),
      endsAt: DateTime.tryParse(json['ends_at'] as String? ?? ''),
      receivedSeals: _asInt(
        payload['received_seals'] ?? json['seal_count'],
      ),
      givenSeals: _asInt(payload['given_seals']),
      rankName: payload['rank_name'] as String? ?? '',
      rankQuality: payload['rank_quality'] as String? ?? '',
      rankLevel: payload['rank_level'] as String? ?? '',
    );
  }

  final String seasonId;
  final int year;
  final int half;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int receivedSeals;
  final int givenSeals;
  final String rankName;
  final String rankQuality;
  final String rankLevel;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
