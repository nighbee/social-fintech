import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_outlined_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/features/auth/domain/repositories/i_auth_repository.dart';
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
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter email')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authRepository = getIt<IAuthRepository>(
      instanceName: 'AuthRepositoryImpl',
    );
    final result = await authRepository.registerWithEmail(
      email: _emailController.text.trim(),
      password: 'TempPassword123!', // Fixed password
      firstName: 'User', // Fixed first name
      lastName: 'Name', // Fixed last name
      dateOfBirth: '2000-01-01', // Fixed date of birth (YYYY-MM-DD format)
      referral: null, // Fixed referral code
    );

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    result.fold(
      (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      },
      (loginEntity) {
        // Tokens are automatically saved by the repository
        // Navigate to home
        context.go(RoutePaths.home);
      },
    );
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

              CustomButton(
                text: _isLoading ? "Loading..." : "Continue",
                isDisabled: _isLoading,
                onTap: _register,
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
            ],
          ),
        ),
      ),
    );
  }
}
