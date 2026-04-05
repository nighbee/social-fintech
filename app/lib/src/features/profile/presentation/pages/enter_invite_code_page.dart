import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/core/router/router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class EnterInviteCodePage extends StatefulWidget {
  const EnterInviteCodePage({super.key});

  @override
  State<EnterInviteCodePage> createState() => _EnterInviteCodePageState();
}

class _EnterInviteCodePageState extends State<EnterInviteCodePage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  String? _errorMessage;
  bool _submitting = false;

  static final _codeRe = RegExp(r'^[A-Za-z0-9]+$');

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String _) {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _errorMessage = 'Enter a code');
      return;
    }
    if (raw.length < 4 || !_codeRe.hasMatch(raw)) {
      setState(() => _errorMessage = 'Invalid code');
      return;
    }

    // Referral redeem is currently handled during signup flow only.
    setState(() {
      _errorMessage =
          'Invite code can only be applied during signup right now.';
    });
  }

  void _goToMyCode() {
    final router = GoRouter.of(context);
    router.pop();
    router.pushNamed(RouteNames.profileInviteGoldenHonor);
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _errorMessage != null;
    const errorRed = Color(0xFFFF4D4D);

    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      appBar: CustomAppBar(
        backgroundColor: AppColors.colorff19191A,
        centerTitle: true,
        title: '',
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => context.pop(),
            child: Text(
              'Skip',
              style: TextStyles.bodyLarge.copyWith(
                fontSize: 16,
                color: AppColors.textBrand,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Have you been invited?',
                style: TextStyles.titleBig.copyWith(
                  fontSize: 26,
                  height: 1.15,
                  color: AppColors.textBrand,
                ),
              ),
              const Gap(16),
              Text(
                'If you were invited by a friend, enter their invite code below. '
                "We'll send them 1 Golden Honor as a thank you!",
                style: TextStyles.bodyLarge.copyWith(
                  fontSize: 15,
                  height: 1.45,
                  color: const Color(0xFF8E8E93),
                ),
              ),
              const Gap(32),
              CustomTextField(
                controller: _controller,
                focusNode: _focusNode,
                labelText: 'Code',
                hintText: '',
                onChanged: _onTextChanged,
                textCapitalization: TextCapitalization.characters,
                inactiveBorderColor: hasError ? errorRed : const Color(0xFF6D6D6D),
                activeBorderColor: hasError ? errorRed : AppColors.textBrand,
                textStyle: TextStyles.bodyLarge.copyWith(
                  fontSize: 17,
                  color: AppColors.textBrand,
                ),
                footer: hasError
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _errorMessage!,
                            style: TextStyles.bodyMain.copyWith(
                              fontSize: 13,
                              color: errorRed,
                              height: 1.2,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              if (hasError) ...[
                const Gap(16),
                TextButton(
                  onPressed: _submitting ? null : _goToMyCode,
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    'Share my referral code instead',
                    style: TextStyles.bodyLarge.copyWith(
                      fontSize: 15,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.textBrand,
                      color: AppColors.textBrand,
                    ),
                  ),
                ),
              ],
              const Gap(36),
              CustomButton(
                text: 'Confirm',
                onTap: _submit,
                isDisabled: _submitting,
                borderRadius: 10,
                backgroundColor: const Color(0xFF4A4A4A),
                textStyle: TextStyles.titleMain.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textBrand,
                ),
                disabledTextStyle: TextStyles.titleMain.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF8E8E8E),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
