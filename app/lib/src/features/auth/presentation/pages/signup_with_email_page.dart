import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_outlined_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SignupWithEmailPage extends StatefulWidget {
  const SignupWithEmailPage({super.key});

  @override
  State<SignupWithEmailPage> createState() => _SignupWithEmailPageState();
}

class _SignupWithEmailPageState extends State<SignupWithEmailPage> {
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _continueToCreatePassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter email')));
      return;
    }

    // Navigate to create password page with email
    context.pushNamed(
      RouteNames.createPassword,
      extra: {'email': _emailController.text.trim()},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.mainBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.1),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      context.pushReplacementNamed(RouteNames.loginWithEmail);
                    },
                    child: Text(
                      "Log in",
                      style: context.theme.textStyles.titleLarge,
                    ),
                  ),

                  Text("or", style: context.theme.textStyles.titleLarge),

                  TextButton(
                    onPressed: () {},
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
                labelText: "Email",
                hintText: "Email",
                keyboardType: TextInputType.emailAddress,
              ),
              Gap(28),
              CustomButton(text: "Continue", onTap: _continueToCreatePassword),

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
                    text: "Continue with phone",
                    onTap: () {
                      context.pushNamed(RouteNames.signup);
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
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
            ],
          ),
        ),
      ),
    );
  }
}
