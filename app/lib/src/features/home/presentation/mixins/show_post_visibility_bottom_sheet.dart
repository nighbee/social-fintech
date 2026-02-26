import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/action_bottom_sheet.dart';
import 'package:app/src/core/widgets/extensions/build_context_ext.dart';
import 'package:flutter/material.dart';

enum PostVisibilityOption {
  everyone('Everyone'),
  allies('Allies only');

  const PostVisibilityOption(this.label);
  final String label;
}

enum CommentControlOption {
  everyone('Anyone'),
  allies('Allies only'),
  nobody('No one');

  const CommentControlOption(this.label);
  final String label;
}

mixin ShowPostVisibilityBottomSheet {
  void showPostVisibilityBottomSheet(
    BuildContext context, {
    required PostVisibilityOption selected,
    required CommentControlOption selectedCommentControl,
    required ValueChanged<PostVisibilityOption> onSelected,
    required VoidCallback onCommentControlTap,
  }) {
    context.showRoundedModalBottomSheet(
      backgroundColor: Colors.transparent,
      maxHeightFactor: 0.52,
      child: ActionBottomSheet(
        backgroundColor: const Color(0xFF202020).withOpacity(0.20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Who can view your post?',
                    style: TextStyles.bodyMain.copyWith(color: Colors.white),
                  ),
                ),
              ),
              ...PostVisibilityOption.values.map(
                (option) => _VisibilityItem(
                  label: option.label,
                  isSelected: option == selected,
                  onTap: () => onSelected(option),
                ),
              ),
              _CommentControlEntry(
                value: selectedCommentControl.label,
                onTap: onCommentControlTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showCommentControlBottomSheet(
    BuildContext context, {
    required CommentControlOption selected,
    required ValueChanged<CommentControlOption> onSelected,
  }) {
    context.showRoundedModalBottomSheet(
      backgroundColor: Colors.transparent,
      maxHeightFactor: 0.62,
      child: ActionBottomSheet(
        backgroundColor: const Color(0xFF202020).withOpacity(0.20),
        child: _CommentControlSheetBody(
          selected: selected,
          onSelected: onSelected,
        ),
      ),
    );
  }
}

class _CommentControlSheetBody extends StatefulWidget {
  const _CommentControlSheetBody({
    required this.selected,
    required this.onSelected,
  });

  final CommentControlOption selected;
  final ValueChanged<CommentControlOption> onSelected;

  @override
  State<_CommentControlSheetBody> createState() =>
      _CommentControlSheetBodyState();
}

class _CommentControlSheetBodyState extends State<_CommentControlSheetBody> {
  late CommentControlOption _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Comment control',
                style: TextStyles.bodyMain.copyWith(color: Colors.white),
              ),
            ),
          ),
          ...CommentControlOption.values.map(
            (option) => _VisibilityItem(
              label: option.label,
              isSelected: option == _selected,
              onTap: () {
                setState(() => _selected = option);
              },
              closeOnTap: false,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  widget.onSelected(_selected);
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Done',
                  style: TextStyles.titleTag.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _VisibilityItem extends StatelessWidget {
  const _VisibilityItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.closeOnTap = true,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool closeOnTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (closeOnTap) {
          Navigator.of(context).pop();
        }
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyles.titleTag.copyWith(color: Colors.white),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

class _CommentControlEntry extends StatelessWidget {
  const _CommentControlEntry({
    required this.value,
    required this.onTap,
  });

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comments control',
                    style: TextStyles.titleTag.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyles.bodyMain.copyWith(color: Colors.white60),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }
}
