import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/action_bottom_sheet.dart';
import 'package:app/src/core/widgets/extensions/build_context_ext.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

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

mixin ShowPostReportBottomSheet {
  void showPostReportBottomSheet(
    BuildContext context, {
    required ValueChanged<PostReportReason> onSubmitted,
  }) {
    context.showRoundedModalBottomSheet(
      backgroundColor: Colors.transparent,
      maxHeightFactor: 0.78,
      child: ActionBottomSheet(
        backgroundColor: const Color(0xFF202020).withOpacity(0.20),
        child: _PostReportSheet(onSubmitted: onSubmitted),
      ),
    );
  }
}

class _PostReportSheet extends StatelessWidget {
  const _PostReportSheet({required this.onSubmitted});

  final ValueChanged<PostReportReason> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why are you reporting this post?',
            style: TextStyles.titleHeadline.copyWith(
              color: AppColors.whiteBackground,
            ),
          ),
          const Gap(8),
          Text(
            'Your report is anonymous. If someone is in immediate danger, call local emergency services.',
            style: TextStyles.bodyMain.copyWith(
              color: AppColors.textGray2,
              fontSize: 12,
            ),
          ),
          const Gap(10),
          SizedBox(
            height: 360,
            child: ListView.separated(
              itemCount: PostReportReason.values.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                color: Color(0x33FFFFFF),
              ),
              itemBuilder: (context, index) {
                final reason = PostReportReason.values[index];
                return InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    onSubmitted(reason);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            reason.label,
                            style: TextStyles.bodyMain.copyWith(
                              color: AppColors.whiteBackground,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Color(0xFF8E8E93),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
