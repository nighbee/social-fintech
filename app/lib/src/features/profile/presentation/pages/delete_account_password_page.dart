import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/core/widgets/styled_message_dialog.dart';
import 'package:app/src/features/profile/presentation/models/delete_account_flow_data.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class DeleteAccountPasswordPage extends StatefulWidget {
  const DeleteAccountPasswordPage({
    super.key,
    required this.flowData,
  });

  final DeleteAccountFlowData flowData;

  @override
  State<DeleteAccountPasswordPage> createState() =>
      _DeleteAccountPasswordPageState();
}

class _DeleteAccountPasswordPageState
    extends State<DeleteAccountPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  bool get _canContinue => _passwordController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_handleTextChanged);
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

  Future<void> _handleContinue() async {
    if (!_canContinue) {
      return;
    }

    final result = await context.pushNamed(
      RouteNames.profileSecurityDeleteAccountConfirm,
      extra: widget.flowData.toExtra(),
    );
    if (!mounted || result != true) {
      return;
    }

    context.pop(true);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_handleTextChanged);
    _passwordController.dispose();
    super.dispose();
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
              Center(
                child: _DeleteAccountAvatar(
                  avatarUrl: widget.flowData.avatarUrl,
                  displayName: widget.flowData.resolvedDisplayName,
                ),
              ),
              const Gap(32),
              Text(
                'Enter your password to delete your account',
                textAlign: TextAlign.center,
                style: TextStyles.titleBig.copyWith(
                  fontSize: 24,
                  height: 1.2,
                  letterSpacing: -0.48,
                  color: AppColors.textBrand,
                ),
              ),
              const Gap(32),
              CustomTextField(
                controller: _passwordController,
                labelText: 'Password',
                hintText: 'Password',
                showLabel: false,
                obscureText: !_isPasswordVisible,
                height: 46,
                borderRadius: 8,
                backgroundColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
                containerPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                customBorder: Border.all(
                  color: AppColors.textBrand,
                  width: 1,
                ),
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  size: 24,
                  color: AppColors.textBrand,
                ),
                hintStyle: TextStyles.bodyMain.copyWith(
                  fontSize: 16,
                  height: 1.4,
                  color: const Color(0xFFA3A3A3),
                ),
                textStyle: TextStyles.bodyMain.copyWith(
                  fontSize: 16,
                  height: 1.4,
                  color: AppColors.textBrand,
                ),
                suffixIcon: _DeleteAccountPasswordVisibilityToggle(
                  isVisible: _isPasswordVisible,
                  onTap: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
              const Gap(32),
              CustomButton(
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
              const Gap(8),
              Center(
                child: TextButton(
                  onPressed: _handleForgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFA3A3A3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    'Forgot your password?',
                    style: TextStyles.bodyMain.copyWith(
                      fontSize: 14,
                      height: 1.4,
                      color: const Color(0xFFA3A3A3),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountAvatar extends StatelessWidget {
  const _DeleteAccountAvatar({
    required this.avatarUrl,
    required this.displayName,
  });

  final String avatarUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final trimmedAvatarUrl = avatarUrl.trim();
    final trimmedDisplayName = displayName.trim();
    final avatarLetter = trimmedDisplayName.isEmpty
        ? 'B'
        : trimmedDisplayName.substring(0, 1).toUpperCase();

    return Container(
      width: 146,
      height: 146,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x404C4C4C),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: trimmedAvatarUrl.isEmpty
            ? Container(
                color: const Color(0xFF2A2A2B),
                alignment: Alignment.center,
                child: Text(
                  avatarLetter,
                  style: TextStyles.titleBig.copyWith(
                    fontSize: 42,
                    height: 1,
                    color: AppColors.textBrand,
                  ),
                ),
              )
            : CustomNetworkImage(
                imageUrl: trimmedAvatarUrl,
                width: 146,
                height: 146,
              ),
      ),
    );
  }
}

class _DeleteAccountPasswordVisibilityToggle extends StatelessWidget {
  const _DeleteAccountPasswordVisibilityToggle({
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
