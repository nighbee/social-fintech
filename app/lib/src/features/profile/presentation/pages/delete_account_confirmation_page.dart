import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_outlined_button.dart';
import 'package:app/src/core/widgets/styled_message_dialog.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:app/src/features/profile/data/sources/remote/i_interaction_settings_remote.dart';
import 'package:app/src/features/profile/presentation/models/delete_account_flow_data.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class DeleteAccountConfirmationPage extends StatefulWidget {
  const DeleteAccountConfirmationPage({
    super.key,
    required this.flowData,
  });

  final DeleteAccountFlowData flowData;

  @override
  State<DeleteAccountConfirmationPage> createState() =>
      _DeleteAccountConfirmationPageState();
}

class _DeleteAccountConfirmationPageState
    extends State<DeleteAccountConfirmationPage> {
  final IInteractionSettingsRemote _remote =
      getIt<IInteractionSettingsRemote>();
  bool _isAcknowledged = false;
  bool _isSubmitting = false;

  Future<void> _handleDelete() async {
    if (!_isAcknowledged || _isSubmitting) {
      return;
    }
    final token = widget.flowData.verificationToken.trim();
    if (token.isEmpty) {
      await showStyledMessageDialog<void>(
        context: context,
        message: 'Verification expired. Please restart delete account flow.',
      );
      return;
    }
    setState(() => _isSubmitting = true);
    final finalizeResult = await _remote.deleteAccountFinalize(
      verificationToken: token,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    var success = false;
    finalizeResult.fold(
      (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      },
      (_) => success = true,
    );
    if (!success) {
      return;
    }

    getIt<AuthBloc>().add(const AuthEvent.logout());
    context.go(RoutePaths.loginWithEmail);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      appBar: const CustomAppBar(
        title: 'Delete account',
        backgroundColor: AppColors.colorff19191A,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Delete account?',
                style: TextStyles.titleBig.copyWith(
                  fontSize: 24,
                  height: 1.2,
                  letterSpacing: -0.48,
                  color: AppColors.textBrand,
                ),
              ),
              const Gap(12),
              const _DeleteAccountBullet(
                text: 'This action cannot be undone.',
              ),
              const _DeleteAccountBullet(
                text:
                    'Your profile, posts, and interactions will be permanently '
                    'deleted.',
              ),
              const _DeleteAccountBullet(
                text:
                    'Your district ranking and history will be completely '
                    'deleted with no option to recover them.',
              ),
              const Gap(32),
              _DeleteAccountAcknowledgeRow(
                value: _isAcknowledged,
                onTap: () {
                  setState(() {
                    _isAcknowledged = !_isAcknowledged;
                  });
                },
              ),
              const Gap(32),
              CustomButton(
                text: 'Delete',
                onTap: _handleDelete,
                isDisabled: !_isAcknowledged || _isSubmitting,
                backgroundColor: AppColors.backgroundBrandLight,
                borderRadius: 6,
                padding: const EdgeInsets.symmetric(vertical: 11),
                textStyle: TextStyles.titleMain.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                  color: _isAcknowledged
                      ? AppColors.colorffEF4444
                      : AppColors.textDisabledDefault,
                ),
              ),
              const Gap(8),
              CustomOutlinedButton(
                text: 'Cancel',
                onTap: () => context.pop(),
                borderRadius: 6,
                borderColor: AppColors.borderDefault,
                backgroundColor: AppColors.backgroundNeutralSecondary,
                textStyle: TextStyles.titleMain.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                  color: AppColors.textBrand,
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountBullet extends StatelessWidget {
  const _DeleteAccountBullet({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFA3A3A3),
              ),
            ),
          ),
          const Gap(12),
          Expanded(
            child: Text(
              text,
              style: TextStyles.bodyMain.copyWith(
                fontSize: 16,
                height: 1.4,
                color: const Color(0xFFA3A3A3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountAcknowledgeRow extends StatelessWidget {
  const _DeleteAccountAcknowledgeRow({
    required this.value,
    required this.onTap,
  });

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DeleteAccountCheckboxIndicator(value: value),
            const Gap(12),
            Expanded(
              child: Text(
                'I understand that this action cannot be undone.',
                style: TextStyles.bodyMain.copyWith(
                  fontSize: 16,
                  height: 1.4,
                  color: const Color(0xFF5F6880),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteAccountCheckboxIndicator extends StatelessWidget {
  const _DeleteAccountCheckboxIndicator({
    required this.value,
  });

  final bool value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: value ? AppColors.backgroundBrandLight : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: value ? AppColors.backgroundBrandLight : const Color(0xFFF0F1F2),
          width: 1.4,
        ),
      ),
      child: value
          ? const Icon(
              Icons.check_rounded,
              size: 16,
              color: AppColors.textNeutral,
            )
          : null,
    );
  }
}
