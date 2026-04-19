import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/action_bottom_sheet.dart';
import 'package:app/src/core/widgets/custom_outlined_button.dart';
import 'package:app/src/core/widgets/extensions/build_context_ext.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

mixin ShowSortBottomSheet {
  void showSortBottomSheet(
    BuildContext context, {
    required String selectedSort,
    required void Function(String) onSortChanged,
  }) {
    final sortOptions = ['Default: Earliest', 'Default: Latest'];

    context.showRoundedModalBottomSheet(
      backgroundColor: Colors.transparent,
      child: ActionBottomSheet(
        backgroundColor: const Color(0xFF202020).withValues(alpha: 0.20),
        enableGlassEffect: false,
        enableDropShadow: false,
        showDivider: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: sortOptions.map((option) {
                  final isSelected = selectedSort == option;
                  return InkWell(
                    onTap: () {
                      onSortChanged(option);
                      Navigator.of(context, rootNavigator: true).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Text(
                            option,
                            style: TextStyles.titleTag.copyWith(
                              color: isSelected
                                  ? const Color(0xFF838383)
                                  : Color(0xFFCACACA),
                            ),
                          ),
                          const Gap(6),
                          if (isSelected)
                            const Icon(
                              Icons.check,
                              color: Color(0xFF838383),
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Gap(16),
              CustomOutlinedButton(
                text: "Cancel",
                onTap: () => Navigator.of(context, rootNavigator: true).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
