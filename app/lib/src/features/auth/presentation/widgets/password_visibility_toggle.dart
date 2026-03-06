import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';

class PasswordVisibilityToggle extends StatelessWidget {
  const PasswordVisibilityToggle({
    required this.isVisible,
    required this.onTap,
    super.key,
  });

  final bool isVisible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: SizedBox(
          height: 20,
          width: 20,
          child: isVisible
              ? Assets.icons.eyeOpened.svg(
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                    AppColors.colorff838383,
                    BlendMode.srcIn,
                  ),
                )
              : Assets.icons.eyeClosed.svg(
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                    AppColors.colorff838383,
                    BlendMode.srcIn,
                  ),
                ),
        ),
      ),
    );
  }
}
