part of 'rating_bloc.dart';

abstract class RatingEvent {}

class RatingEventLoad extends RatingEvent {
  RatingEventLoad({this.scope = 'district', this.limit = 50});

  final String scope;
  final int limit;
}
