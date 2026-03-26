import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/action_bottom_sheet.dart';
import 'package:app/src/core/widgets/extensions/build_context_ext.dart';
import 'package:flutter/material.dart';

enum PostReportReason {
  spamOrScam('Spam or scam'),
  hateHarassment('Hate, harassment'),
  nuditySexualContent('Nudity or sexual content'),
  violence('Violence'),
  illegalContent('Illegal content'),
  gamblingPromotion('Gambling promotion'),
  copyrightViolation('Copyright violation'),
  fakeAccount('Fake account'),
  manipulationOfHonor('Manipulation of Honor');

  const PostReportReason(this.label);
  final String label;
}

mixin ShowPostReportBottomSheet {
  void showPostReportBottomSheet(
    BuildContext context, {
    required String username,
  }) {
    context.showRoundedModalBottomSheet(
      backgroundColor: Colors.transparent,
      maxHeightFactor: 0.9,
      child: ActionBottomSheet(
        backgroundColor: const Color(0xFF202020),
        backgroundOpacity: 0.2,
        enableGlassEffect: true,
        enableDropShadow: false,
        showDivider: false,
        child: _PostReportFlowSheet(username: username),
      ),
    );
  }
}

class _PostReportFlowSheet extends StatefulWidget {
  const _PostReportFlowSheet({required this.username});

  final String username;

  @override
  State<_PostReportFlowSheet> createState() => _PostReportFlowSheetState();
}

class _PostReportFlowSheetState extends State<_PostReportFlowSheet> {
  PostReportReason? _selectedReason;

  @override
  Widget build(BuildContext context) {
    if (_selectedReason == null) {
      return _PostReportReasonSheet(
        onReasonTap: (reason) {
          setState(() => _selectedReason = reason);
        },
      );
    }

    return _PostReportResultSheet(
      username: widget.username,
      onDoneTap: () => Navigator.of(context).pop(),
    );
  }
}

class _PostReportReasonSheet extends StatelessWidget {
  const _PostReportReasonSheet({required this.onReasonTap});

  final ValueChanged<PostReportReason> onReasonTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Center(
            child: Text(
              'Why are you reporting this post?',
              textAlign: TextAlign.center,
              style: TextStyles.titleHeadline.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              "Your report is anonymous. If someone is in\nimmediate danger, call the local emergency services\n- don't wait.",
              textAlign: TextAlign.center,
              style: TextStyles.bodyMain.copyWith(
                color: const Color(0xFF888888),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...PostReportReason.values.map(
            (reason) => _ReportReasonRow(
              label: reason.label,
              onTap: () => onReasonTap(reason),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportReasonRow extends StatelessWidget {
  const _ReportReasonRow({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
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
                  color: const Color(0xFFE6E6E6),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF6D6D6D),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostReportResultSheet extends StatelessWidget {
  const _PostReportResultSheet({
    required this.username,
    required this.onDoneTap,
  });

  final String username;
  final VoidCallback onDoneTap;

  @override
  Widget build(BuildContext context) {
    final displayName = username.trim().isEmpty ? 'this account' : username;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 52,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Thanks for your feedback !',
              style: TextStyles.titleHeadline.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'We use these reports to show you less of\nthis kind of content in the future.',
              textAlign: TextAlign.center,
              style: TextStyles.bodyMain.copyWith(
                color: const Color(0xFF888888),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Others steps you can take',
            style: TextStyles.titleTag.copyWith(
              color: const Color(0xFFE6E6E6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _ReportActionRow(
            icon: Assets.icons.blocked.svg(
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(
                Color(0xFFCB5B5B),
                BlendMode.srcIn,
              ),
            ),
            title: 'Block $displayName',
            titleColor: const Color(0xFFCB5B5B),
            onTap: () {},
          ),
          _ReportActionRow(
            icon: Assets.icons.eyeClosed.svg(
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(
                Color(0xFFE5E5E5),
                BlendMode.srcIn,
              ),
            ),
            title: 'Restrict $displayName',
            onTap: () {},
          ),
          _ReportActionRow(
            icon: Assets.icons.noPeople.svg(
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(
                Color(0xFFE5E5E5),
                BlendMode.srcIn,
              ),
            ),
            title: 'Learn about our Community Standards',
            onTap: () {},
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onDoneTap,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                'Done',
                style: TextStyles.titleTag.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportActionRow extends StatelessWidget {
  const _ReportActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.titleColor = const Color(0xFFE6E6E6),
  });

  final Widget icon;
  final String title;
  final VoidCallback onTap;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyles.bodyLarge.copyWith(
                  fontFamily: 'Lora',
                  fontSize: 17,
                  height: 21 / 17,
                  letterSpacing: 0,
                  color: titleColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF6D6D6D),
            ),
          ],
        ),
      ),
    );
  }
}
