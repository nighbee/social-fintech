import 'package:app/gen/fonts.gen.dart';
import 'package:app/src/core/widgets/action_bottom_sheet.dart';
import 'package:app/src/core/widgets/extensions/build_context_ext.dart';
import 'package:flutter/material.dart';

/// Тот же «стеклянный» контейнер, что у [ShowPostReportBottomSheet.showPostReportBottomSheet]:
/// `ActionBottomSheet` с `Color(0xFF202020)` + `backgroundOpacity: 0.2`, blur по умолчанию,
/// `barrierColor: 0.42`. Отличия только в контенте (пункты профиля, Lora по центру).
mixin ShowProfileActionsBottomSheet {
  static const Color _dangerRed = Color(0xFFFF3B30);
  static const Color _labelLight = Color(0xFFFFFFFF);

  void showProfileActionsBottomSheet(
    BuildContext context, {
    required String userName,
    VoidCallback? onBlock,
    VoidCallback? onReport,
    VoidCallback? onRestrict,
    VoidCallback? onCopyUrl,
    VoidCallback? onShare,
  }) {
    // См. show_post_report_bottom_sheet.dart — те же параметры модалки и ActionBottomSheet.
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
          // Как у _PostReportReasonSheet: отступы и ручка.
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
                labelColor: _dangerRed,
                onTap: onBlock,
              ),
              _ProfileActionRow(
                label: 'Report this account',
                labelColor: _dangerRed,
                onTap: onReport,
              ),
              _ProfileActionRow(
                label: 'Restrict $userName',
                labelColor: _dangerRed,
                onTap: onRestrict,
              ),
              _ProfileActionRow(
                label: 'Copy Profile URL',
                labelColor: _labelLight,
                onTap: onCopyUrl,
              ),
              _ProfileActionRow(
                label: 'Share Profile',
                labelColor: _labelLight,
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
    required this.labelColor,
    this.onTap,
  });

  final String label;
  final Color labelColor;
  final VoidCallback? onTap;

  static TextStyle _itemStyle(Color color) {
    return TextStyle(
      fontFamily: FontFamily.lora,
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w400,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap == null
            ? null
            : () {
                Navigator.of(context).pop();
                onTap!();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: _itemStyle(labelColor),
          ),
        ),
      ),
    );
  }
}
