import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';

/// Switch track when ON: `rgba(194, 193, 193, 1)` — neutral gray, not system blue.
class NeutralTrackSwitch extends StatelessWidget {
  const NeutralTrackSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.scale = 0.88,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final double scale;

  /// `background: rgba(194, 193, 193, 1)`
  static const Color onTrackColor = Color(0xFFC2C1C1);

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: onTrackColor,
        inactiveTrackColor: AppColors.colorff3F3F40,
        activeThumbColor: AppColors.colorffffffff,
        inactiveThumbColor: AppColors.colorffffffff,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
