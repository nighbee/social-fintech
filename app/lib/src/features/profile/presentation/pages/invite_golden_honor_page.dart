import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/styled_message_dialog.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

/// Экран «мой реферальный код» + шаринг.
/// Отображаемый код: в приоритете `referral_code` с бэка; если пусто — username (пока бэкенд не выдал код).
class InviteGoldenHonorPage extends StatelessWidget {
  const InviteGoldenHonorPage({
    super.key,
    this.currentUserId,
  });

  /// Оставлено для совместимости с `extra` в роутере; код берётся из [AuthBloc].
  final String? currentUserId;

  String _displayCode(AuthState auth) {
    return auth.maybeWhen(
      authenticated: (login) {
        final code = login.user.referralCode.trim();
        if (code.isNotEmpty) return code;
        final u = login.user.username.trim();
        if (u.isNotEmpty) return u;
        return '—';
      },
      orElse: () => '—',
    );
  }

  Future<void> _copyCode(BuildContext context, String code) async {
    if (code == '—') {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Referral code is not available yet'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.colorff202020,
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Code copied'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.colorff202020,
      ),
    );
  }

  Future<void> _shareCode(BuildContext context, String code) async {
    if (code == '—') {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Referral code is not available yet'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.colorff202020,
        ),
      );
      return;
    }
    final message =
        'Join BrightBund with my code: $code\nhttps://brightbund.app/invite';
    try {
      final smsUri = Uri(
        scheme: 'sms',
        queryParameters: {'body': message},
      );
      final launched = await launchUrl(
        smsUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched && context.mounted) return;
    } catch (_) {}

    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Message copied — share it anywhere'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.colorff202020,
      ),
    );
  }

  Future<void> _onChangeCode(BuildContext context) async {
    await showStyledMessageDialog<void>(
      context: context,
      title: 'Change code',
      message:
          'Custom referral codes are not editable yet. This option will be available in a future update.',
      barrierColor: Colors.black.withValues(alpha: 0.72),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      bloc: getIt<AuthBloc>(),
      builder: (context, auth) {
        final code = _displayCode(auth);

        return Scaffold(
          backgroundColor: AppColors.colorff19191A,
          appBar: const CustomAppBar(
            backgroundColor: AppColors.colorff19191A,
            centerTitle: false,
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Earn a Golden Honor when your invite joins.',
                              style: TextStyles.titleHeadline.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                height: 1.25,
                                color: AppColors.textBrand,
                              ),
                            ),
                          ),
                          const Gap(8),
                          Assets.images.goldenHonor.image(
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                      const Gap(12),
                      Text(
                        "Share your code. You'll earn 1 Golden Honor as soon as your friend redeems it.",
                        style: TextStyles.bodyMain.copyWith(
                          fontSize: 13,
                          height: 1.4,
                          color: const Color(0xFFA3A3A3),
                        ),
                      ),
                      const Gap(22),
                      _ReferralCodeCard(
                        code: code,
                        onCopy: () => _copyCode(context, code),
                      ),
                      const Gap(22),
                      CustomButton(
                        text: 'Share your code',
                        onTap: () => _shareCode(context, code),
                        borderRadius: 8,
                        backgroundColor: AppColors.backgroundBrandLight,
                        textStyle: TextStyles.bodyLarge.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          color: AppColors.textNeutral,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      const Gap(8),
                      CustomButton(
                        text: 'Change code',
                        onTap: () => _onChangeCode(context),
                        borderRadius: 8,
                        backgroundColor: const Color(0xFF2C2C2E),
                        textStyle: TextStyles.bodyLarge.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                          color: AppColors.textBrand,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReferralCodeCard extends StatelessWidget {
  const _ReferralCodeCard({
    required this.code,
    required this.onCopy,
  });

  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderDefault, width: 1),
        color: const Color(0xFF141414),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your unique code',
                  style: TextStyles.bodyMain.copyWith(
                    fontSize: 11,
                    height: 1.2,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
                const Gap(6),
                SelectableText(
                  code,
                  style: TextStyles.bodyLarge.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    color: AppColors.textBrand,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(
              Icons.copy_rounded,
              size: 20,
              color: AppColors.textBrand,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }
}
