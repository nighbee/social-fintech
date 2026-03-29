import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/core/widgets/styled_message_dialog.dart';
import 'package:app/src/features/auth/presentation/widgets/password_visibility_toggle.dart';
import 'package:app/src/features/profile/data/sources/remote/i_interaction_settings_remote.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ProfileChangePasswordPage extends StatefulWidget {
  const ProfileChangePasswordPage({super.key});

  @override
  State<ProfileChangePasswordPage> createState() =>
      _ProfileChangePasswordPageState();
}

class _ProfileChangePasswordPageState extends State<ProfileChangePasswordPage> {
  final IInteractionSettingsRemote _remote =
      getIt<IInteractionSettingsRemote>();

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _currentPasswordController.addListener(_handleTextChanged);
    _newPasswordController.addListener(_handleTextChanged);
    _confirmPasswordController.addListener(_handleTextChanged);
  }

  bool get _hasRequiredLength =>
      _newPasswordController.text.trim().length >= 6;

  bool get _hasLetter =>
      RegExp(r'[A-Za-z]').hasMatch(_newPasswordController.text.trim());

  bool get _hasNumber =>
      RegExp(r'\d').hasMatch(_newPasswordController.text.trim());

  bool get _hasSpecial =>
      RegExp(r'[!$@%#^&*()_+\-=\[\]{};:\\|,.<>\/?]').hasMatch(
        _newPasswordController.text.trim(),
      );

  bool get _isFormValid {
    return _currentPasswordController.text.trim().isNotEmpty &&
        _newPasswordController.text.trim().isNotEmpty &&
        _confirmPasswordController.text.trim().isNotEmpty &&
        _hasRequiredLength &&
        _hasLetter &&
        _hasNumber &&
        _hasSpecial &&
        _newPasswordController.text == _confirmPasswordController.text;
  }

  void _handleTextChanged() {
    setState(() {});
  }

  Future<void> _onContinue() async {
    if (!_isFormValid || _submitting) return;

    setState(() => _submitting = true);
    final result = await _remote.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      (e) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      (_) => context.pop(true),
    );
  }

  Future<void> _handleForgotPassword() async {
    await showStyledMessageDialog<void>(
      context: context,
      message: 'Password recovery is not available yet.',
    );
  }

  @override
  void dispose() {
    _currentPasswordController.removeListener(_handleTextChanged);
    _newPasswordController.removeListener(_handleTextChanged);
    _confirmPasswordController.removeListener(_handleTextChanged);
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  static const _borderIdle = AppColors.colorff838383;
  static const _borderActive = AppColors.colorffffffff;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      appBar: const CustomAppBar(
        backgroundColor: AppColors.colorff19191A,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change password',
                style: TextStyles.titleBig.copyWith(
                  fontSize: 24,
                  height: 1.2,
                  letterSpacing: -0.48,
                  color: AppColors.textBrand,
                ),
              ),
              const Gap(12),
              Text(
                'Your password must be at least 6 characters and should include '
                'a combination of numbers, letters and special characters '
                '(!\$@%).',
                style: TextStyles.bodyMain.copyWith(
                  color: AppColors.colorff838383,
                  fontSize: 13,
                  height: 20 / 13,
                ),
              ),
              const Gap(32),
              _PasswordInputField(
                controller: _currentPasswordController,
                labelText: 'Current password',
                obscureText: !_isCurrentPasswordVisible,
                isVisible: _isCurrentPasswordVisible,
                onVisibilityTap: () {
                  setState(() {
                    _isCurrentPasswordVisible = !_isCurrentPasswordVisible;
                  });
                },
                inactiveBorderColor: _borderIdle,
                activeBorderColor: _borderActive,
              ),
              const Gap(12),
              _PasswordInputField(
                controller: _newPasswordController,
                labelText: 'New password',
                obscureText: !_isNewPasswordVisible,
                isVisible: _isNewPasswordVisible,
                onVisibilityTap: () {
                  setState(() {
                    _isNewPasswordVisible = !_isNewPasswordVisible;
                  });
                },
                inactiveBorderColor: _borderIdle,
                activeBorderColor: _borderActive,
              ),
              const Gap(12),
              _PasswordInputField(
                controller: _confirmPasswordController,
                labelText: 'Re-enter new password',
                obscureText: !_isConfirmPasswordVisible,
                isVisible: _isConfirmPasswordVisible,
                onVisibilityTap: () {
                  setState(() {
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                  });
                },
                inactiveBorderColor: _borderIdle,
                activeBorderColor: _borderActive,
              ),
              const Gap(24),
              CustomButton(
                text: 'Continue',
                onTap: _onContinue,
                isDisabled: !_isFormValid || _submitting,
                borderRadius: 6,
                padding: const EdgeInsets.symmetric(vertical: 11),
                backgroundColor: AppColors.backgroundBrandLight,
                textStyle: TextStyles.titleMain.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                  color: AppColors.textNeutral,
                ),
                disabledBackgroundColor: AppColors.backgroundDisabledDefault,
                disabledTextStyle: TextStyles.titleMain.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                  color: AppColors.textDisabledDefault,
                ),
              ),
              const Gap(8),
              Center(
                child: TextButton(
                  onPressed: _handleForgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textBrand,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    'Forgot your password?',
                    style: TextStyles.bodyMain.copyWith(
                      fontSize: 14,
                      height: 22 / 14,
                      color: AppColors.textBrand,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordInputField extends StatelessWidget {
  const _PasswordInputField({
    required this.controller,
    required this.labelText,
    required this.obscureText,
    required this.isVisible,
    required this.onVisibilityTap,
    required this.inactiveBorderColor,
    required this.activeBorderColor,
  });

  final TextEditingController controller;
  final String labelText;
  final bool obscureText;
  final bool isVisible;
  final VoidCallback onVisibilityTap;
  final Color inactiveBorderColor;
  final Color activeBorderColor;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      labelText: labelText,
      showLabel: false,
      height: 68,
      obscureText: obscureText,
      backgroundColor: Colors.transparent,
      inactiveBorderColor: inactiveBorderColor,
      activeBorderColor: activeBorderColor,
      containerPadding: const EdgeInsets.fromLTRB(16, 10, 0, 10),
      textStyle: TextStyles.bodyLarge.copyWith(
        color: AppColors.textBrand,
        height: 1.25,
      ),
      hintStyle: TextStyles.bodyLarge.copyWith(
        color: AppColors.colorff838383,
        height: 1.25,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      suffixIcon: PasswordVisibilityToggle(
        isVisible: isVisible,
        onTap: onVisibilityTap,
      ),
    );
  }
}
