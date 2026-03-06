import 'package:flutter/material.dart';

class FeedSoftLimitScrollPhysics extends ClampingScrollPhysics {
  const FeedSoftLimitScrollPhysics({
    required this.accumulatedActiveSeconds,
    required this.maxAllowedSeconds,
    super.parent,
  });

  final int accumulatedActiveSeconds;
  final int maxAllowedSeconds;

  static const double _perMinuteDrop = 0.15;
  static const double _minResponse = 0.30;

  @override
  FeedSoftLimitScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return FeedSoftLimitScrollPhysics(
      accumulatedActiveSeconds: accumulatedActiveSeconds,
      maxAllowedSeconds: maxAllowedSeconds,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    final base = super.applyPhysicsToUserOffset(position, offset);
    final threshold = maxAllowedSeconds > 0 ? maxAllowedSeconds : 20 * 60;

    final overflowSeconds = (accumulatedActiveSeconds - threshold).toDouble();
    if (overflowSeconds <= 0) {
      return base;
    }

    // After crossing the limit, reduce finger responsiveness by 15%
    // per extra minute, down to a floor of 30%.
    final minutesOver = (overflowSeconds / 60.0).ceil();
    final response = (1.0 - (minutesOver * _perMinuteDrop)).clamp(
      _minResponse,
      1.0,
    );

    return base * response;
  }
}
