import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/features/profile/presentation/models/delete_account_flow_data.dart';
import 'package:app/src/features/profile/presentation/widgets/settings/settings_option_widgets.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

const List<String> _deleteAccountReasons = <String>[
  'Want to remove something',
  'Just need a break',
  'Can\'t find people to follow',
  'Privacy concerns',
  'Created another account',
  'Trouble getting started',
  'Concerned about my data',
  'Too busy',
  'Something else',
];

class DeleteAccountReasonPage extends StatefulWidget {
  const DeleteAccountReasonPage({
    super.key,
    required this.flowData,
  });

  final DeleteAccountFlowData flowData;

  @override
  State<DeleteAccountReasonPage> createState() =>
      _DeleteAccountReasonPageState();
}

class _DeleteAccountReasonPageState extends State<DeleteAccountReasonPage> {
  String? _selectedReason;

  bool get _canContinue => (_selectedReason ?? '').isNotEmpty;

  Future<void> _handleContinue() async {
    if (!_canContinue) {
      return;
    }

    final nextRouteName = widget.flowData.usesPhoneVerification
        ? RouteNames.profileSecurityDeleteAccountOtp
        : RouteNames.profileSecurityDeleteAccountPassword;

    final result = await context.pushNamed(
      nextRouteName,
      extra: widget.flowData
          .copyWith(selectedReason: _selectedReason)
          .toExtra(),
    );
    if (!mounted || result != true) {
      return;
    }

    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      appBar: const CustomAppBar(
        backgroundColor: AppColors.colorff19191A,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delete your BrightBund account',
                      style: TextStyles.titleBig.copyWith(
                        fontSize: 24,
                        height: 1.2,
                        letterSpacing: -0.48,
                        color: AppColors.textBrand,
                      ),
                    ),
                    const Gap(16),
                    Text(
                      'We\'re sorry to see you go. We\'d like to know why '
                      'you\'re deleting your account as we may be able to help '
                      'with common issues.',
                      style: TextStyles.bodyLarge.copyWith(
                        color: const Color(0xFFA3A3A3),
                        height: 1.4,
                      ),
                    ),
                    const Gap(20),
                    SettingsOptionCard(
                      child: Column(
                        children: [
                          for (final reason in _deleteAccountReasons)
                            SettingsRadioOptionRow(
                              label: reason,
                              isSelected: reason == _selectedReason,
                              onTap: () {
                                setState(() {
                                  _selectedReason = reason;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: CustomButton(
                text: 'Continue',
                onTap: _handleContinue,
                isDisabled: !_canContinue,
                borderRadius: 6,
                padding: const EdgeInsets.symmetric(vertical: 11),
                textStyle: TextStyles.titleMain.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
