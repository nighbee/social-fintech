import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SettingsOptionCard extends StatelessWidget {
  const SettingsOptionCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.fromLTRB(12, 16, 12, 10),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}

class SettingsOptionRow extends StatelessWidget {
  const SettingsOptionRow({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyles.bodyLarge.copyWith(
                    fontSize: 18,
                    height: 1,
                    color: AppColors.textBrand,
                  ),
                ),
              ),
              SizedBox(
                width: 22,
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: AppColors.textBrand,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsRadioOptionRow extends StatelessWidget {
  const SettingsRadioOptionRow({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyles.bodyLarge.copyWith(
                    fontSize: 18,
                    height: 1,
                    color: AppColors.textBrand,
                  ),
                ),
              ),
              SettingsRadioIndicator(isSelected: isSelected),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsRadioIndicator extends StatelessWidget {
  const SettingsRadioIndicator({
    required this.isSelected,
    super.key,
  });

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected
              ? AppColors.backgroundBrandLight
              : const Color(0xFF6D6D6D),
          width: 1.4,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.backgroundBrandLight,
                ),
              ),
            )
          : null,
    );
  }
}

class SettingsHelperText extends StatelessWidget {
  const SettingsHelperText({
    required this.text,
    super.key,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyles.bodyMain.copyWith(
        fontSize: 12,
        height: 1.25,
        color: const Color(0xFFA3A3A3),
      ),
    );
  }
}

class SettingsSwitchCard extends StatelessWidget {
  const SettingsSwitchCard({
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsOptionCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyles.bodyLarge.copyWith(
                  fontSize: 18,
                  height: 1,
                  color: AppColors.textBrand,
                ),
              ),
            ),
            CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.backgroundBrandLight,
              inactiveTrackColor: AppColors.backgroundBrandLight,
              thumbColor: value
                  ? AppColors.colorff19191A
                  : const Color(0xFFB0B0B0),
            ),
          ],
        ),
      ),
    );
  }
}
