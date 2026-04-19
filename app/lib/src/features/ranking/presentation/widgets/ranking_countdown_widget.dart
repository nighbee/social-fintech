import 'dart:async';
import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';

/// Simple countdown timer widget that counts down to 12:00 UTC
/// Uses setState instead of BLoC for better performance
class RankingCountdownWidget extends StatefulWidget {
  const RankingCountdownWidget({
    super.key,
    this.textStyle,
  });

  final TextStyle? textStyle;

  @override
  State<RankingCountdownWidget> createState() => _RankingCountdownWidgetState();
}

class _RankingCountdownWidgetState extends State<RankingCountdownWidget> {
  Timer? _timer;
  String _countdown = '--:--:--';

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    // Calculate next 12:00 UTC
    final now = DateTime.now().toUtc();
    var nextUpdate = DateTime.utc(now.year, now.month, now.day, 12, 0, 0);
    if (now.isAfter(nextUpdate)) {
      nextUpdate = nextUpdate.add(const Duration(days: 1));
    }

    _updateCountdown(nextUpdate);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final nowUtc = DateTime.now().toUtc();
      final remaining = nextUpdate.difference(nowUtc);

      if (remaining.isNegative) {
        // Countdown finished - recalculate for next day
        nextUpdate = nextUpdate.add(const Duration(days: 1));
      }

      _updateCountdown(nextUpdate);
    });
  }

  void _updateCountdown(DateTime targetTime) {
    final now = DateTime.now().toUtc();
    final remaining = targetTime.difference(now);

    if (remaining.isNegative) {
      setState(() => _countdown = '00:00:00');
      return;
    }

    final hours = remaining.inHours.toString().padLeft(2, '0');
    final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    if (mounted) {
      setState(() => _countdown = '$hours:$minutes:$seconds');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(_countdown,
        style: widget.textStyle ??
            TextStyles.titleXBig.copyWith(color: AppColors.colorffffffff));
  }
}
