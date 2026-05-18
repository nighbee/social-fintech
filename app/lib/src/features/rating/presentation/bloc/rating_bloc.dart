import 'package:bloc/bloc.dart';
import 'package:app/src/core/base/base_bloc/bloc/base_bloc.dart';
// equatable not required here
import 'package:app/src/features/rating/domain/usecases/get_leaderboard_usecase.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';

part 'rating_event.dart';
part 'rating_state.dart';

class RatingBloc extends BaseBloc<RatingEvent, RatingState> {
  RatingBloc(this._getLeaderboard) : super(const RatingStateInitial());

  final GetLeaderboardUseCase _getLeaderboard;

  @override
  Future<void> onEventHandler(RatingEvent event, Emitter emit) async {
    if (event is RatingEventLoad) {
      emit(const RatingStateLoading());
      final res = await _getLeaderboard.execute(limit: event.limit);
      res.fold((DomainException e) => emit(RatingStateError(e.message)), (items) {
        emit(RatingStateLoaded(items));
      });
    }
  }
}
