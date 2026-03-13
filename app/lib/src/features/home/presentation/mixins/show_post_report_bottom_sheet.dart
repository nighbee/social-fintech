import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/action_bottom_sheet.dart';
import 'package:app/src/core/widgets/extensions/build_context_ext.dart';
import 'package:app/src/core/widgets/list_item/custom_action_list_item.dart';
import 'package:app/src/features/home/presentation/mixins/show_post_report_feedback_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

typedef PostReportSubmitCallback = Future<bool> Function(
  PostReportReason reason,
);

enum PostReportReason {
  spam('Spam or scam'),
  hate('Hate, harassment'),
  nudity('Nudity or sexual content'),
  violence('Violence'),
  illegal('Illegal content'),
  gambling('Gambling promotion'),
  copyright('Copyright violation'),
  fake('Fake account'),
  manipulation('Manipulation of honor');

  const PostReportReason(this.label);
  final String label;
}

extension PostReportReasonApiValue on PostReportReason {
  String get apiValue {
    switch (this) {
      case PostReportReason.spam:
        return 'spam';
      case PostReportReason.hate:
        return 'hate';
      case PostReportReason.nudity:
        return 'nudity';
      case PostReportReason.violence:
        return 'violence';
      case PostReportReason.illegal:
        return 'illegal';
      case PostReportReason.gambling:
        return 'gambling';
      case PostReportReason.copyright:
        return 'copyright';
      case PostReportReason.fake:
        return 'fake_account';
      case PostReportReason.manipulation:
        return 'manipulation';
    }
  }
}

mixin ShowPostReportBottomSheet on ShowPostReportFeedbackBottomSheet {
  void showPostReportBottomSheet(
    BuildContext context, {
    required PostReportSubmitCallback onSubmitted,
    String reportTargetName = 'User',
    VoidCallback? onBlock,
    VoidCallback? onRestrict,
    VoidCallback? onFeedbackDone,
  }) {
    context.showRoundedModalBottomSheet(
      backgroundColor: Colors.transparent,
      maxHeightFactor: 0.78,
      child: ActionBottomSheet(
        backgroundColor: const Color(0xFF202020).withValues(alpha: 0.20),
        child: _PostReportSheet(
          onSubmitted: onSubmitted,
          onReportSucceeded: () {
            Future.microtask(() {
              if (!context.mounted) return;
              showPostReportFeedbackBottomSheet(
                context,
                reportTargetName: reportTargetName,
                onBlock: onBlock,
                onRestrict: onRestrict,
                onDone: onFeedbackDone,
              );
            });
          },
        ),
      ),
    );
  }
}

class _PostReportSheet extends StatelessWidget {
  const _PostReportSheet({
    required this.onSubmitted,
    required this.onReportSucceeded,
  });

  final PostReportSubmitCallback onSubmitted;
  final VoidCallback onReportSucceeded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Why are you reporting this post?',
            style: TextStyles.titleBig.copyWith(
              color: AppColors.colorffffffff,
            ),
            textAlign: TextAlign.center,
          ),
          const Gap(8),
          Text(
            'Your report is anonymous. If someone is in immediate danger, call local emergency services.',
            style: TextStyles.bodyMain.copyWith(
              color: AppColors.colorff838383,
            ),
            textAlign: TextAlign.center,
          ),
          const Gap(16),
          SizedBox(
            height: 360,
            child: ListView.separated(
              itemCount: PostReportReason.values.length,
              separatorBuilder: (_, __) => const Gap(12),
              itemBuilder: (context, index) {
                final reason = PostReportReason.values[index];
                return CustomActionListItem(
                  text: reason.label,
                  color: AppColors.colorffffffff,
                  onTap: () async {
                    Navigator.of(context).pop();
                    final shouldShowFeedback = await onSubmitted(reason);
                    if (shouldShowFeedback) {
                      onReportSucceeded();
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
