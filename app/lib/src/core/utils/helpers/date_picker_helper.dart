import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';

class DatePickerHelper {
  static Future<DateTime?> pickBirthDate(
    BuildContext context, {
    DateTime? initialDate,
  }) async {
    return showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.colorff74afe3,
              onPrimary: AppColors.colorffffffff,
              surface: AppColors.colorff19191A,
              onSurface: AppColors.colorffffffff,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  static String formatUsShort(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year.toString().substring(2);
    return '$month/$day/$year';
  }
}
