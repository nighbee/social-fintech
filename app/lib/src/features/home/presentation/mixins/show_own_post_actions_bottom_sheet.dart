import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/action_bottom_sheet.dart';
import 'package:app/src/core/widgets/extensions/build_context_ext.dart';
import 'package:flutter/material.dart';

typedef OwnPostActionCallback = Future<void> Function();

mixin ShowOwnPostActionsBottomSheet {
  void showOwnPostActionsBottomSheet(
    BuildContext context, {
    required OwnPostActionCallback onDelete,
    required OwnPostActionCallback onToggleLikeCount,
    required OwnPostActionCallback onToggleCommenting,
    required String likeCountLabel,
    required String commentingLabel,
  }) {
    context.showRoundedModalBottomSheet(
      backgroundColor: Colors.transparent,
      maxHeightFactor: 0.52,
      child: ActionBottomSheet(
        backgroundColor: const Color(0xFF202020).withValues(alpha: 0.20),
        child: _OwnPostActionsSheet(
          onDelete: onDelete,
          onToggleLikeCount: onToggleLikeCount,
          onToggleCommenting: onToggleCommenting,
          likeCountLabel: likeCountLabel,
          commentingLabel: commentingLabel,
        ),
      ),
    );
  }
}

class _OwnPostActionsSheet extends StatelessWidget {
  const _OwnPostActionsSheet({
    required this.onDelete,
    required this.onToggleLikeCount,
    required this.onToggleCommenting,
    required this.likeCountLabel,
    required this.commentingLabel,
  });

  final OwnPostActionCallback onDelete;
  final OwnPostActionCallback onToggleLikeCount;
  final OwnPostActionCallback onToggleCommenting;
  final String likeCountLabel;
  final String commentingLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OwnPostActionItem(
            label: 'Delete',
            color: AppColors.colorffEF4444,
            onTap: () async {
              Navigator.of(context).pop();
              await onDelete();
            },
          ),
          const SizedBox(height: 18),
          _OwnPostActionItem(
            label: likeCountLabel,
            onTap: () async {
              Navigator.of(context).pop();
              await onToggleLikeCount();
            },
          ),
          const SizedBox(height: 18),
          _OwnPostActionItem(
            label: commentingLabel,
            onTap: () async {
              Navigator.of(context).pop();
              await onToggleCommenting();
            },
          ),
        ],
      ),
    );
  }
}

class _OwnPostActionItem extends StatelessWidget {
  const _OwnPostActionItem({
    required this.label,
    required this.onTap,
    this.color,
  });

  final String label;
  final OwnPostActionCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? AppColors.textBrand;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 44,
          width: double.infinity,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyles.bodyLarge.copyWith(
                color: resolvedColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
