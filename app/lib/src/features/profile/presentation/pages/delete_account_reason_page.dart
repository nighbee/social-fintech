import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/features/profile/data/sources/remote/i_interaction_settings_remote.dart';
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

const Map<String, String> _deleteReasonApiByLabel = <String, String>{
  'Want to remove something': 'want_to_remove_something',
  'Just need a break': 'need_a_break',
  'Can\'t find people to follow': 'cant_find_people',
  'Privacy concerns': 'privacy_concerns',
  'Created another account': 'created_another_account',
  'Trouble getting started': 'trouble_getting_started',
  'Concerned about my data': 'concerned_about_my_data',
  'Too busy': 'too_busy',
  'Something else': 'something_else',
};

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
  final IInteractionSettingsRemote _remote =
      getIt<IInteractionSettingsRemote>();
  String? _selectedReason;
  bool _isSubmitting = false;

  bool get _canContinue => (_selectedReason ?? '').isNotEmpty;

  Future<void> _handleContinue() async {
    if (!_canContinue || _isSubmitting) {
      return;
    }
    final selectedLabel = _selectedReason!;
    final reasonApi =
        _deleteReasonApiByLabel[selectedLabel] ?? 'something_else';
    setState(() => _isSubmitting = true);
    final reasonResult = await _remote.deleteAccountReason(reason: reasonApi);
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    String? verificationMethod;
    reasonResult.fold(
      (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      },
      (v) => verificationMethod = v.verificationMethod,
    );
    if (verificationMethod == null || verificationMethod!.isEmpty) {
      return;
    }

    final nextRouteName = verificationMethod == 'otp'
        ? RouteNames.profileSecurityDeleteAccountOtp
        : RouteNames.profileSecurityDeleteAccountPassword;

    final result = await context.pushNamed(
      nextRouteName,
      extra: widget.flowData
          .copyWith(
            selectedReason: reasonApi,
            verificationMethod:
                verificationMethod == 'otp'
                    ? DeleteAccountFlowData.phoneMethod
                    : DeleteAccountFlowData.emailMethod,
          )
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
                isDisabled: !_canContinue || _isSubmitting,
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
