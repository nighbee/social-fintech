part of 'rating_bloc.dart';

abstract class RatingEvent {}

class RatingEventLoad extends RatingEvent {
  RatingEventLoad({this.limit = 50});

  final int limit;
}
