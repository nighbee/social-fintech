import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/action_bottom_sheet.dart';
import 'package:app/src/core/widgets/extensions/build_context_ext.dart';
import 'package:flutter/material.dart';

mixin ShowProfileActionsBottomSheet {
  void showProfileActionsBottomSheet(
    BuildContext context, {
    required String userName,
    VoidCallback? onBlock,
    VoidCallback? onReport,
    VoidCallback? onRestrict,
    VoidCallback? onCopyUrl,
    VoidCallback? onShare,
  }) {
    context.showRoundedModalBottomSheet(
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      maxHeightFactor: 0.9,
      child: ActionBottomSheet(
        backgroundColor: const Color(0xFF202020),
        backgroundOpacity: 0.2,
        enableGlassEffect: true,
        enableDropShadow: false,
        showDivider: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _ProfileActionRow(
                label: 'Block $userName',
                labelColor: const Color(0xFFFF3B30),
                onTap: onBlock,
              ),
              _ProfileActionRow(
                label: 'Report this account',
                labelColor: const Color(0xFFFF3B30),
                onTap: onReport,
              ),
              _ProfileActionRow(
                label: 'Restrict $userName',
                labelColor: const Color(0xFFFF3B30),
                onTap: onRestrict,
              ),
              _ProfileActionRow(
                label: 'Copy Profile URL',
                onTap: onCopyUrl,
              ),
              _ProfileActionRow(
                label: 'Share Profile',
                onTap: onShare,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileActionRow extends StatelessWidget {
  const _ProfileActionRow({
    required this.label,
    this.labelColor = const Color(0xFFE6E6E6),
    this.onTap,
  });

  final String label;
  final Color labelColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap == null
          ? null
          : () {
              Navigator.of(context).pop();
              onTap!();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyles.bodyLarge.copyWith(
                  fontFamily: 'Lora',
                  fontSize: 17,
                  height: 21 / 17,
                  letterSpacing: 0,
                  color: labelColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: labelColor == const Color(0xFFFF3B30)
                  ? const Color(0xFFCB5B5B)
                  : const Color(0xFF6D6D6D),
            ),
          ],
        ),
      ),
    );
  }
}
