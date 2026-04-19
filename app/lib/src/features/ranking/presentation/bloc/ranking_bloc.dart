import 'dart:async';
import 'package:app/src/core/base/base_bloc/bloc/base_bloc.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/service/injectable/service_register_proxy.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'ranking_bloc.freezed.dart';
part 'ranking_event.dart';
part 'ranking_state.dart';

@injectable
class RankingBloc extends BaseBloc<RankingEvent, RankingState> {
  RankingBloc() : super(const RankingState.initial());

  Timer? _countdownTimer;

  @override
  Future<void> onEventHandler(RankingEvent event, Emitter emit) async {
    await event.when(
      startCountdown: (targetTime) => _startCountdown(targetTime, emit),
      stopCountdown: () => _stopCountdown(emit),
    );
  }

  Future<void> _startCountdown(DateTime targetTime, Emitter emit) async {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now().toUtc();
      final remaining = targetTime.difference(now);

      if (remaining.isNegative) {
        _countdownTimer?.cancel();
        emit(const RankingState.countdownFinished());
        return;
      }

      final hours = remaining.inHours.toString().padLeft(2, '0');
      final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');

      emit(RankingState.countdownTicking(
        countdown: '$hours:$minutes:$seconds',
        targetTime: targetTime,
      ));
    });
  }

  Future<void> _stopCountdown(Emitter emit) async {
    _countdownTimer?.cancel();
    emit(const RankingState.initial());
  }

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    getIt.resetBloc(this);
    return super.close();
  }
}
