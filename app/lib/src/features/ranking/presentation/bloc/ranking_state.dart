part of 'ranking_bloc.dart';

@freezed
class RankingState with _$RankingState {
  const factory RankingState.initial() = _Initial;
  const factory RankingState.countdownTicking({
    required String countdown,
    required DateTime targetTime,
  }) = _CountdownTicking;
  const factory RankingState.countdownFinished() = _CountdownFinished;
}
