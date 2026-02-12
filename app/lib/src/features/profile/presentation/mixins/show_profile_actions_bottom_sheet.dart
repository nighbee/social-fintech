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
    VoidCallback? onAbout,
    VoidCallback? onShare,
  }) {
    context.showRoundedModalBottomSheet(
      backgroundColor: Colors.transparent,
      maxHeightFactor: 0.9,
      child: ActionBottomSheet(
        backgroundColor: Color(0xFF202020).withOpacity(0.20),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _ActionItem(
              label: 'Block $userName',
              labelColor: const Color(0xFFFF3B30),
              onTap: onBlock,
            ),
            _ActionItem(
              label: 'Report this account',
              labelColor: const Color(0xFFFF3B30),
              onTap: onReport,
            ),
            _ActionItem(
              label: 'Restrict Ayaulym',
              onTap: onRestrict,
              labelColor: const Color(0xFFFF3B30),
            ),
            _ActionItem(label: 'Copy Profile URL', onTap: onCopyUrl),
            _ActionItem(label: 'About this account', onTap: onAbout),
            _ActionItem(label: 'Share profile', onTap: onShare),
          ],
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({required this.label, this.labelColor, this.onTap});

  final String label;
  final Color? labelColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Center(
          child: Text(
            label,
            style: TextStyles.titleTag.copyWith(
              color: labelColor ?? Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
