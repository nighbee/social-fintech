part of 'ranking_bloc.dart';

@freezed
class RankingEvent with _$RankingEvent {
  const factory RankingEvent.startCountdown(DateTime targetTime) = _StartCountdown;
  const factory RankingEvent.stopCountdown() = _StopCountdown;
}
