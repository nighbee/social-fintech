import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_outlined_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class LoginWithEmailPage extends StatefulWidget {
  const LoginWithEmailPage({super.key});

  @override
  State<LoginWithEmailPage> createState() => _LoginWithEmailPageState();
}

class _LoginWithEmailPageState extends State<LoginWithEmailPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.mainBackground,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      "Log in",
                      style: context.theme.textStyles.titleLarge,
                    ),
                  ),

                  Text("or", style: context.theme.textStyles.titleLarge),

                  TextButton(
                    onPressed: () {
                      context.pushReplacementNamed(RouteNames.signupWithEmail);
                    },
                    child: Text(
                      "Sign up",
                      style: context.theme.textStyles.titleLarge,
                    ),
                  ),
                ],
              ),
              Gap(63),
              CustomTextField(
                controller: _emailController,
                labelText: "E-mail",
                hintText: "E-mail",
                keyboardType: TextInputType.emailAddress,
              ),

              Gap(16),

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

              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () {
                    context.pushNamed(RouteNames.changePassword);
                  },
                  child: Text(
                    "Forgot your password?",
                    style: context.theme.textStyles.caption.copyWith(
                      fontSize: 14,
                      color: AppColors.textGray2,
                    ),
                  ),
                ),
              ),

              Gap(28),

              CustomButton(
                text: "Continue",
                onTap: () {
                  context.pushNamed(RouteNames.home);
                },
              ),

              Gap(57),

              Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      height: 1,
                      color: AppColors.textGray2,
                    ),
                  ),
                  Text("or", style: context.theme.textStyles.bodyBold),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      height: 1,
                      color: AppColors.textGray2,
                    ),
                  ),
                ],
              ),
              Gap(57),
              Column(
                spacing: 16,
                children: [
                  CustomOutlinedButton(
                    text: "Continue with number",
                    onTap: () {
                      context.pushNamed(RouteNames.login);
                    },
                  ),
                  CustomButton(
                    text: "Continue with Apple",
                    icon: Assets.icons.appleLogo.svg(),
                    onTap: () {},
                    padding: EdgeInsets.symmetric(vertical: 10),
                    textStyle: context.theme.textStyles.bodyMediumBold.copyWith(
                      fontSize: 17,
                    ),
                  ),
                  CustomButton(
                    text: "Continue with Google",
                    icon: Assets.icons.googleLogo.svg(),
                    onTap: () {},
                    padding: EdgeInsets.symmetric(vertical: 10),
                    textStyle: context.theme.textStyles.bodyMediumBold.copyWith(
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    "Continuing, I agree with\nTerms and conditions.",
                    textAlign: TextAlign.center,
                    style: context.theme.textStyles.caption.copyWith(
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
