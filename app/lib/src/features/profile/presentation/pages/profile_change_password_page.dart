import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/core/widgets/styled_message_dialog.dart';
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
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                style: TextStyles.bodyLarge.copyWith(
                  color: const Color(0xFFA3A3A3),
                  height: 1.4,
                ),
              ),
              const Gap(48),
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
              ),
              const Gap(20),
              CustomButton(
                text: 'Continue',
                onTap: () => context.pop(true),
                isDisabled: !_isFormValid,
                borderRadius: 6,
                padding: const EdgeInsets.symmetric(vertical: 11),
                textStyle: TextStyles.titleMain.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
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
  });

  final TextEditingController controller;
  final String labelText;
  final bool obscureText;
  final bool isVisible;
  final VoidCallback onVisibilityTap;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      labelText: labelText,
      obscureText: obscureText,
      backgroundColor: Colors.transparent,
      customBorder: Border.all(color: AppColors.textBrand, width: 1),
      textStyle: TextStyles.titleMain.copyWith(
        color: AppColors.textBrand,
        fontSize: 20,
        height: 1.1,
      ),
      suffixIcon: _PasswordVisibilityToggle(
        isVisible: isVisible,
        onTap: onVisibilityTap,
      ),
    );
  }
}

class _PasswordVisibilityToggle extends StatelessWidget {
  const _PasswordVisibilityToggle({
    required this.isVisible,
    required this.onTap,
  });

  final bool isVisible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: SizedBox(
          width: 24,
          height: 24,
          child: isVisible
              ? Assets.icons.eyeOpened.svg(
                  colorFilter: const ColorFilter.mode(
                    AppColors.textBrand,
                    BlendMode.srcIn,
                  ),
                )
              : Assets.icons.eyeClosed.svg(
                  colorFilter: const ColorFilter.mode(
                    AppColors.textBrand,
                    BlendMode.srcIn,
                  ),
                ),
        ),
      ),
    );
  }
}
