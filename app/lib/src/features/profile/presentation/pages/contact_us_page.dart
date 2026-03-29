import 'package:app/src/core/constants/support_links.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/utils/helpers/url_helper.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  Future<void> _openSupportChannels(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.colorff202020,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppColors.colorff6D6D6D,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                const Gap(18),
                _ContactSheetRow(
                  title: 'WhatsApp',
                  icon: Icons.chat_bubble_outline_rounded,
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await UrlHelper.tryLaunchUrl(
                      url: SupportLinks.whatsappUrl,
                      context: context,
                      errorText: 'WhatsApp is not available on this device.',
                    );
                  },
                ),
                _ContactSheetRow(
                  title: 'Telegram',
                  icon: Icons.send_rounded,
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await UrlHelper.tryLaunchUrl(
                      url: SupportLinks.telegramUrl,
                      context: context,
                      errorText: 'Telegram is not available on this device.',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Подтверждение как в системном звонке, затем `tel:` — работает на iOS и Android.
  Future<void> _confirmPhoneCall(BuildContext context) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              isDefaultAction: true,
              onPressed: () async {
                Navigator.of(ctx).pop();
                await UrlHelper.makePhoneCall(
                  phoneNumber: SupportLinks.phoneTel,
                  context: context,
                  errorText: 'Could not start a call on this device.',
                );
              },
              child: Text(
                'Call ${SupportLinks.phoneDisplay}',
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      appBar: const CustomAppBar(
        title: 'Contact us',
        backgroundColor: AppColors.colorff19191A,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How can we help?',
                style: TextStyles.titleHeadline.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  color: AppColors.textBrand,
                ),
              ),
              const Gap(12),
              Text(
                'If you have any questions or run into technical issues, feel free to contact us. We reply within 24–48 hours.',
                style: TextStyles.bodyMain.copyWith(
                  fontSize: 14,
                  height: 1.45,
                  color: const Color(0xFFA3A3A3),
                ),
              ),
              const Gap(20),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.colorff202020,
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _ContactOptionRow(
                      title: 'Write to support',
                      icon: Icons.chat_bubble_outline_rounded,
                      onTap: () => _openSupportChannels(context),
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    _ContactOptionRow(
                      title: 'Call',
                      icon: Icons.call_outlined,
                      onTap: () => _confirmPhoneCall(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactOptionRow extends StatelessWidget {
  const _ContactOptionRow({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                color: AppColors.colorffffffff,
                size: 22,
              ),
              const Gap(14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyles.bodyLarge.copyWith(
                    fontSize: 17,
                    color: AppColors.colorffffffff,
                    height: 1.2,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.colorff838383,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactSheetRow extends StatelessWidget {
  const _ContactSheetRow({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              Icon(
                icon,
                color: AppColors.colorffffffff,
                size: 22,
              ),
              const Gap(14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyles.bodyLarge.copyWith(
                    color: AppColors.colorffffffff,
                    height: 22 / 16,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.colorff838383,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
