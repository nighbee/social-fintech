import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_outlined_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class LoginWithNumberPage extends StatefulWidget {
  const LoginWithNumberPage({super.key});

  @override
  State<LoginWithNumberPage> createState() => _LoginWithNumberPageState();
}

class _LoginWithNumberPageState extends State<LoginWithNumberPage> {
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
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
              Text(
                "Log in or Sign up",
                style: context.theme.textStyles.titleLarge,
              ),
              Gap(63),
              CustomTextField(
                controller: _phoneController,
                labelText: "Phone number",
                hintText: "Phone number",
                keyboardType: TextInputType.phone,
              ),

              Gap(28),

              CustomButton(
                text: "Continue",
                onTap: () {
                  context.pushNamed(RouteNames.code);
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
                  Text("or", style: context.theme.textStyles.dividerText),
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
                    text: "Continue with email",
                    onTap: () {
                      context.pushNamed(RouteNames.loginWithEmail);
                    },
                  ),
                  CustomButton(
                    text: "Continue with Apple",
                    icon: Assets.icons.appleLogo.svg(),
                    onTap: () {},
                    padding: EdgeInsets.symmetric(vertical: 10),
                    textStyle: context.theme.textStyles.buttonText.copyWith(
                      fontSize: 17,
                    ),
                  ),
                  CustomButton(
                    text: "Continue with Google",
                    icon: Assets.icons.googleLogo.svg(),
                    onTap: () {},
                    padding: EdgeInsets.symmetric(vertical: 10),
                    textStyle: context.theme.textStyles.buttonText.copyWith(
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    "Continuing, I agree with\nTerms and conditions.",
                    textAlign: TextAlign.center,
                    style: context.theme.textStyles.labelText.copyWith(
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

