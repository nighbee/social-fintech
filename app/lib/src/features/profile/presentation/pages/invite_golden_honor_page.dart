import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

class InviteGoldenHonorPage extends StatefulWidget {
  const InviteGoldenHonorPage({
    super.key,
    this.currentUserId,
  });

  final String? currentUserId;

  @override
  State<InviteGoldenHonorPage> createState() => _InviteGoldenHonorPageState();
}

class _InviteGoldenHonorPageState extends State<InviteGoldenHonorPage> {
  bool _isLinkCopied = false;

  String get _inviteLink {
    final userId = widget.currentUserId?.trim() ?? '';
    // Replace this placeholder URL once the backend exposes the real invite link contract.
    final inviteUri = Uri(
      scheme: 'https',
      host: 'brightbund.app',
      path: 'invite',
      queryParameters: userId.isEmpty ? null : {'ref': userId},
    );
    return inviteUri.toString();
  }

  String get _shareMessage =>
      'Join BrightBund using my invitation link:\n$_inviteLink';

  Future<void> _shareInvitationLink() async {
    try {
      final smsUri = Uri(
        scheme: 'sms',
        queryParameters: {'body': _shareMessage},
      );
      final didLaunch = await launchUrl(
        smsUri,
        mode: LaunchMode.externalApplication,
      );
      if (didLaunch || !mounted) {
        return;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
    }

    await Clipboard.setData(ClipboardData(text: _shareMessage));
    if (!mounted) {
      return;
    }

    _showFeedbackMessage('Invitation message copied. Share it anywhere.');
  }

  Future<void> _copyInvitationLink() async {
    await Clipboard.setData(ClipboardData(text: _inviteLink));
    if (!mounted) {
      return;
    }

    setState(() {
      _isLinkCopied = true;
    });
    _showFeedbackMessage('Invitation link copied.');
  }

  void _showFeedbackMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.colorff202020,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      appBar: const CustomAppBar(
        backgroundColor: AppColors.colorff19191A,
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _InviteGoldenHonorHeader(),
              const Gap(24),
              const _InviteGoldenHonorRewardCard(),
              const Gap(32),
              _InviteGoldenHonorActionGroup(
                isLinkCopied: _isLinkCopied,
                onShareTap: _shareInvitationLink,
                onCopyTap: _copyInvitationLink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteGoldenHonorHeader extends StatelessWidget {
  const _InviteGoldenHonorHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Invite & Earn Golden Honor',
                style: TextStyles.titleBig.copyWith(
                  fontSize: 24,
                  height: 1.2,
                  letterSpacing: -0.48,
                  color: AppColors.textBrand,
                ),
              ),
            ),
            const Gap(12),
            Assets.icons.silverCoin.svg(
              width: 25,
              height: 25,
            ),
          ],
        ),
        const Gap(16),
        Text(
          'Invite people to join BrightBund.\n'
          'When someone registers, they can find your profile\n'
          'and select you as the person who invited them.',
          style: TextStyles.bodyLarge.copyWith(
            color: const Color(0xFFA3A3A3),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _InviteGoldenHonorRewardCard extends StatelessWidget {
  const _InviteGoldenHonorRewardCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Text(
        'After their account is verified, you will receive a\n'
        'Golden Honor as a reward!\n\n'
        'Verification may take a few days.',
        style: TextStyles.bodyLarge.copyWith(
          color: const Color(0xFFA3A3A3),
          height: 1.4,
        ),
      ),
    );
  }
}

class _InviteGoldenHonorActionGroup extends StatelessWidget {
  const _InviteGoldenHonorActionGroup({
    required this.isLinkCopied,
    required this.onShareTap,
    required this.onCopyTap,
  });

  final bool isLinkCopied;
  final VoidCallback onShareTap;
  final VoidCallback onCopyTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomButton(
          text: 'Share your invitation link',
          onTap: onShareTap,
          borderRadius: 6,
          backgroundColor: AppColors.backgroundBrandLight,
          textStyle: TextStyles.titleMain.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            height: 1.1,
            color: AppColors.textNeutral,
          ),
          padding: const EdgeInsets.symmetric(vertical: 11),
        ),
        const Gap(8),
        CustomButton(
          text: isLinkCopied ? 'Link copied' : 'Copy link',
          onTap: onCopyTap,
          borderRadius: 6,
          backgroundColor: AppColors.backgroundNeutralSecondary,
          border: Border.all(
            color: AppColors.borderDefault,
            width: 0.8,
          ),
          textStyle: TextStyles.titleMain.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            height: 1.1,
            color: AppColors.textBrand,
          ),
          padding: const EdgeInsets.symmetric(vertical: 11),
          suffixIcon: Icon(
            isLinkCopied ? Icons.check_rounded : Icons.content_copy_rounded,
            size: 20,
            color: AppColors.textBrand,
          ),
        ),
      ],
    );
  }
}
