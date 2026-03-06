import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/action_bottom_sheet.dart';
import 'package:app/src/core/widgets/custom_outlined_button.dart';
import 'package:app/src/core/widgets/extensions/build_context_ext.dart';
import 'package:app/src/core/widgets/list_item/custom_action_list_item.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

mixin ShowPostReportFeedbackBottomSheet {
  void showPostReportFeedbackBottomSheet(
    BuildContext context, {
    required String reportTargetName,
    VoidCallback? onDone,
  }) {
    context.showRoundedModalBottomSheet(
      backgroundColor: Colors.transparent,
      maxHeightFactor: 0.78,
      child: ActionBottomSheet(
        backgroundColor: const Color(0xFF202020).withOpacity(0.20),
        child: PostReportFeedbackSheet(
          reportTargetName: reportTargetName,
          onDone: onDone,
        ),
      ),
    );
  }
}

class PostReportFeedbackSheet extends StatelessWidget {
  const PostReportFeedbackSheet({
    super.key,
    required this.reportTargetName,
    this.onDone,
  });

  final String reportTargetName;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Thanks for your feedback!',
              style: TextStyles.titleBig.copyWith(
                color: AppColors.colorffffffff,
              ),
            ),
          ),
          const Gap(12),
          Center(
            child: Text(
              'We use these reports to show you less of this kind of content in the future.',
              style: TextStyles.bodyMain.copyWith(
                color: AppColors.colorff838383,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Gap(26),
          Text(
            'Others steps you can take',
            style: TextStyles.titleTag.copyWith(
              color: AppColors.colorffffffff,
            ),
          ),
          const Gap(18),
          CustomActionListItem(
            prefixIcon: Assets.icons.basilUserBlockSolid.svg(
              width: 24,
              height: 24,
              color: const Color(0xFFE5484D),
            ),
            text: 'Block $reportTargetName',
            color: const Color(0xFFE5484D),
            onTap: () {},
          ),
          const Gap(18),
          CustomActionListItem(
            prefixIcon: Assets.icons.fluentEyeHide24Filled.svg(
              width: 24,
              height: 24,
              color: AppColors.colorffffffff,
            ),
            text: 'Restrict $reportTargetName',
            color: AppColors.colorffffffff,
            onTap: () {},
          ),
          const Gap(18),
          CustomActionListItem(
            prefixIcon: Assets.icons.flowbiteFileShieldOutline.svg(
              width: 24,
              height: 24,
              color: AppColors.colorffffffff,
            ),
            text: 'Learn about our Community Standards',
            color: AppColors.colorffffffff,
            onTap: () {},
          ),
          const Gap(150),
          CustomOutlinedButton(
            text: 'Done',
            width: double.infinity,
            borderRadius: 8,
            onTap: () {
              onDone?.call();
              Navigator.of(context).pop();
            },
            backgroundColor: Colors.transparent,
          ),
          const Gap(8),
        ],
      ),
    );
  }
}
