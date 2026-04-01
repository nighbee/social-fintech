import 'package:flutter/material.dart';

class FeedSoftLimitScrollPhysics extends ClampingScrollPhysics {
  const FeedSoftLimitScrollPhysics({
    required this.accumulatedActiveSeconds,
    required this.maxAllowedSeconds,
    required this.isInCooldown,
    required this.breakSecondsRemaining,
    required this.freezeBreakCountdown,
    this.cooldownFreezeStartedAt,
    super.parent,
  });

  final int accumulatedActiveSeconds;
  final int maxAllowedSeconds;
  final bool isInCooldown;
  final int breakSecondsRemaining;
  final bool freezeBreakCountdown;
  final DateTime? cooldownFreezeStartedAt;

  static const double _perMinuteDrop = 0.15;
  static const double _minResponse = 0.30;
  static const int _breakDurationSeconds = 5 * 60;
  static const double _cooldownMinResponse = 0.30;
  static const double _cooldownPerMinuteDrop = 0.18;

  @override
  FeedSoftLimitScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return FeedSoftLimitScrollPhysics(
      accumulatedActiveSeconds: accumulatedActiveSeconds,
      maxAllowedSeconds: maxAllowedSeconds,
      isInCooldown: isInCooldown,
      breakSecondsRemaining: breakSecondsRemaining,
      freezeBreakCountdown: freezeBreakCountdown,
      cooldownFreezeStartedAt: cooldownFreezeStartedAt,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    final base = super.applyPhysicsToUserOffset(position, offset);

    if (isInCooldown) {
      final int servedSeconds;
      if (freezeBreakCountdown && cooldownFreezeStartedAt != null) {
        final elapsed = DateTime.now().difference(cooldownFreezeStartedAt!);
        servedSeconds = elapsed.inSeconds.clamp(0, _breakDurationSeconds);
      } else {
        servedSeconds = (_breakDurationSeconds - breakSecondsRemaining).clamp(
          0,
          _breakDurationSeconds,
        );
      }
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
