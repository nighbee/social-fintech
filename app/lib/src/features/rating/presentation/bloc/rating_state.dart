part of 'rating_bloc.dart';

abstract class RatingState {
  const RatingState();
}

class RatingStateInitial extends RatingState {
  const RatingStateInitial();
}

class RatingStateLoading extends RatingState {
  const RatingStateLoading();
}

class RatingStateLoaded extends RatingState {
  RatingStateLoaded(this.items);

  final List<Map<String, dynamic>> items;
}

class RatingStateError extends RatingState {
  RatingStateError(this.message);

  final String message;
}
