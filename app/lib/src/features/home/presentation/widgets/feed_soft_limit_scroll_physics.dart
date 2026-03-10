import 'package:flutter/material.dart';

class FeedSoftLimitScrollPhysics extends ClampingScrollPhysics {
  const FeedSoftLimitScrollPhysics({
    required this.accumulatedActiveSeconds,
    required this.maxAllowedSeconds,
    required this.isInCooldown,
    required this.breakSecondsRemaining,
    super.parent,
  });

  final int accumulatedActiveSeconds;
  final int maxAllowedSeconds;
  final bool isInCooldown;
  final int breakSecondsRemaining;

  static const double _perMinuteDrop = 0.15;
  static const double _minResponse = 0.40;
  static const int _breakDurationSeconds = 5 * 60;
  static const double _cooldownMinResponse = 0.10;
  static const double _cooldownPerMinuteDrop = 0.18;

  @override
  FeedSoftLimitScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return FeedSoftLimitScrollPhysics(
      accumulatedActiveSeconds: accumulatedActiveSeconds,
      maxAllowedSeconds: maxAllowedSeconds,
      isInCooldown: isInCooldown,
      breakSecondsRemaining: breakSecondsRemaining,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    final base = super.applyPhysicsToUserOffset(position, offset);

    if (isInCooldown) {
      final servedSeconds =
          (_breakDurationSeconds - breakSecondsRemaining).clamp(
        0,
        _breakDurationSeconds,
      );
      final servedMinutes = (servedSeconds / 60.0).floor();
      final cooldownResponse = (1.0 - (servedMinutes * _cooldownPerMinuteDrop))
          .clamp(_cooldownMinResponse, 1.0);
      return base * cooldownResponse;
    }

    int minutesOver = 0;
    final threshold = maxAllowedSeconds > 0 ? maxAllowedSeconds : 20 * 60;
    final overflowSeconds = (accumulatedActiveSeconds - threshold).toDouble();
    if (overflowSeconds > 0) {
      minutesOver = (overflowSeconds / 60.0).ceil();
    }

    if (minutesOver <= 0) return base;

    final response = (1.0 - (minutesOver * _perMinuteDrop)).clamp(
      _minResponse,
      1.0,
    );

    return base * response;
  }
}
