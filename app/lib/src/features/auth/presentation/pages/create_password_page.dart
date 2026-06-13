import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/features/auth/presentation/widgets/password_visibility_toggle.dart';
import 'package:app/src/core/widgets/particle_animation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class CreatePasswordPage extends StatefulWidget {
  const CreatePasswordPage({required this.email, super.key});

  final String email;

  @override
  State<CreatePasswordPage> createState() => _CreatePasswordPageState();
}

class _CreatePasswordPageState extends State<CreatePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _pwController = TextEditingController();
  final _confirmPwController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _pwController.addListener(() {
      setState(() {});
    });
    _confirmPwController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _pwController.dispose();
    _confirmPwController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    return _pwController.text.isNotEmpty &&
        _confirmPwController.text.isNotEmpty;
  }

  String? _passwordValidator(String? value) {
    final password = value?.trim() ?? '';
    if (password.isEmpty) return 'Please enter password';
    if (password.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    final confirm = value?.trim() ?? '';
    if (confirm.isEmpty) return 'Please confirm password';
    if (confirm != _pwController.text.trim()) return 'Passwords do not match';
    return null;
  }

  void _onCreateTap() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    context.pushNamed(
      RouteNames.info,
      extra: {
        'email': widget.email,
        'password': _pwController.text.trim(),
      },
    );
  }

  void _toggleVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.mainBackground,
      appBar: const CustomAppBar(
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ParticleAnimation(
                particleCount: 14,
                particleColors: const [
                  Color(0xFFFFFFFF),
                ],
                minSize: 1.0,
                maxSize: 3.0,
                minDistanceBetweenParticles: 92.0,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Gap(40),
                    Text("Create a password", style: TextStyles.titleXBig),
                    Gap(16),
                    Text(
                      "It needs to be at least 8 characters long and contain a number or symbol",
                      style: TextStyles.bodyLarge,
                    ),
                    Gap(40),
                    CustomTextField(
                      controller: _pwController,
                      labelText: "Password",
                      hintText: "Password",
                      obscureText: !_isPasswordVisible,
                      validator: _passwordValidator,
                      suffixIcon: PasswordVisibilityToggle(
                        isVisible: _isPasswordVisible,
                        onTap: _toggleVisibility,
                      ),
                    ),
                    Gap(16),
                    CustomTextField(
                      controller: _confirmPwController,
                      labelText: "Password",
                      hintText: "Re-enter your password",
                      obscureText: !_isPasswordVisible,
                      validator: _confirmPasswordValidator,
                      suffixIcon: PasswordVisibilityToggle(
                        isVisible: _isPasswordVisible,
                        onTap: _toggleVisibility,
                      ),
                    ),
                    Gap(40),
                    CustomButton(
                      text: "Create",
                      onTap: _onCreateTap,
                      isDisabled: !_isFormValid,
                    ),
                    Gap(20),
                    SizedBox(
                        height: MediaQuery.of(context).viewInsets.bottom + 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
