import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_outlined_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    return BlocProvider(
      create: (context) => getIt<AuthBloc>(),
      child: Scaffold(
        backgroundColor: context.theme.mainBackground,
        body: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            state.when(
              initial: () {},
              loading: () {},
              loadingFailure: (message) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message), backgroundColor: Colors.red),
                );
              },
              goRegister: () {},
              loaded: (viewModel) {},
              authenticated: (loginEntity) {
                context.go(RoutePaths.home);
              },
              phoneVerificationStarted: (verificationId, phoneNumber) {},
              emailChecked: (exists, email) {},
            );
          },
          builder: (context, state) {
            final isLoading = state.maybeWhen(
              loading: () => true,
              loaded: (viewModel) => viewModel.isLoading,
              orElse: () => false,
            );

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                child: Column(
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {
                            context.pushReplacementNamed(
                              RouteNames.loginWithEmail,
                            );
                          },
                          child: Text("Log in", style: TextStyles.titleBig),
                        ),

                        Text("or", style: TextStyles.titleBig),

                        TextButton(
                          onPressed: () {},
                          child: Text("Sign up", style: TextStyles.titleBig),
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
                      text: "Continue",
                      onTap: _continueToCreatePassword,
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
                        Text("or", style: TextStyles.titleTag),
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
                          textStyle: TextStyles.titleMain.copyWith(
                            fontSize: 17,
                          ),
                        ),
                        CustomButton(
                          text: "Continue with Google",
                          icon: Assets.icons.googleLogo.svg(),
                          isDisabled: isLoading,
                          onTap: () {
                            context.read<AuthBloc>().add(
                              const AuthEvent.loginWithGoogle(),
                            );
                          },
                          padding: EdgeInsets.symmetric(vertical: 10),
                          textStyle: TextStyles.titleMain.copyWith(
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          "Continuing, I agree with\nTerms and conditions.",
                          textAlign: TextAlign.center,
                          style: TextStyles.bodyMain.copyWith(fontSize: 14),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).viewInsets.bottom + 20,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
