import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class CreatePasswordPage extends StatefulWidget {
  const CreatePasswordPage({super.key});

  @override
  State<CreatePasswordPage> createState() => _CreatePasswordPageState();
}

class _CreatePasswordPageState extends State<CreatePasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _email;

  @override
  void initState() {
    super.initState();
    // Get email from route extra
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
      if (extra != null) {
        setState(() {
          _email = extra['email'] as String?;
        });
      }
    });
    _passwordController.addListener(() {
      setState(() {});
    });
    _confirmPasswordController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    return _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.mainBackground,
      appBar: const CustomAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Gap(40),
              Text(
                "Create a password",
                style: context.theme.textStyles.titleXLarge,
              ),
              Gap(16),
              Text(
                "It needs to be at least 8 characters long and contain a number or symbol",
                style: context.theme.textStyles.bodyMedium,
              ),
              Gap(40),
              CustomTextField(
                controller: _passwordController,
                labelText: "Password",
                hintText: "Password",
                obscureText: !_isPasswordVisible,
                suffixIcon: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _isPasswordVisible
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: Assets.icons.eyeOpened.svg(
                              width: 20,
                              height: 20,
                              colorFilter: const ColorFilter.mode(
                                AppColors.textGray2,
                                BlendMode.srcIn,
                              ),
                            ),
                          )
                        : SizedBox(
                            height: 20,
                            width: 20,
                            child: Assets.icons.eyeClosed.svg(
                              width: 20,
                              height: 20,
                              colorFilter: const ColorFilter.mode(
                                AppColors.textGray2,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              Gap(16),
              CustomTextField(
                controller: _confirmPasswordController,
                labelText: "Password",
                hintText: "Re-enter your password",
                obscureText: !_isConfirmPasswordVisible,
                suffixIcon: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _isConfirmPasswordVisible
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: Assets.icons.eyeOpened.svg(
                              width: 20,
                              height: 20,
                              colorFilter: const ColorFilter.mode(
                                AppColors.textGray2,
                                BlendMode.srcIn,
                              ),
                            ),
                          )
                        : SizedBox(
                            height: 20,
                            width: 20,
                            child: Assets.icons.eyeClosed.svg(
                              height: 20,
                              width: 20,
                              colorFilter: const ColorFilter.mode(
                                AppColors.textGray2,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              Gap(40),
              CustomButton(
                text: "Create",
                onTap: () {
                  if (_isFormValid) {
                    if (_passwordController.text !=
                        _confirmPasswordController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Passwords do not match')),
                      );
                      return;
                    }
                    // Navigate to info page with email and password
                    context.pushNamed(
                      RouteNames.info,
                      extra: {
                        'email': _email,
                        'password': _passwordController.text,
                      },
                    );
                  }
                },
                isDisabled: !_isFormValid,
              ),
              Gap(20),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
            ],
          ),
        ),
      ),
    );
  }
}
