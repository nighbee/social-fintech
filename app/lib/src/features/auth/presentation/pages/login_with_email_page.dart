import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_outlined_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/core/widgets/particle_animation.dart';
import 'package:app/src/core/widgets/styled_message_dialog.dart';
import 'package:app/src/features/auth/domain/requests/login_request.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    return BlocProvider.value(
      value: getIt<AuthBloc>(),
      child: Scaffold(
        backgroundColor: context.theme.mainBackground,
        body: Stack(
          children: [
            // Layer 1: Fixed particle background (doesn't scroll)
            Positioned.fill(
              child: IgnorePointer(
                child: ParticleAnimation(
                  particleCount: 14,
                  particleColors: [
                    // AppColors.textGray2.withValues(0.2),
                    const Color(0xFFFFFFFF),
                  ],
                  minSize: 1.0,
                  maxSize: 3.0,
                  minDistanceBetweenParticles: 92.0,
                ),
              ),
            ),
            // Layer 2: Scrollable content (scrolls independently)
            BlocListener<AuthBloc, AuthState>(
              listener: (context, state) {
                state.when(
                  initial: () {},
                  loading: () {},
                  loadingFailure: (message) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: Colors.red,
                      ),
                    );
                  },
                  goRegister: () {
                    final authBloc = context.read<AuthBloc>();
                    final firebaseIdToken = authBloc.viewModel.firebaseIdToken;
                    final firebaseAuthProvider =
                        authBloc.viewModel.firebaseAuthProvider;
                    context.pushNamed(
                      RouteNames.info,
                      extra: {
                        'firebaseIdToken': firebaseIdToken,
                        'firebaseAuthProvider': firebaseAuthProvider,
                      },
                    );
                  },
                  loaded: (viewModel) {},
                  authenticated: (loginEntity) {
                    if (!(ModalRoute.of(context)?.isCurrent ?? false)) {
                      return;
                    }
                    getIt<ProfileBloc>().add(const ProfileEvent.loadProfile());
                    context.go(RoutePaths.home);
                  },
                  phoneVerificationStarted: (verificationId, phoneNumber) {},
                  emailChecked: (exists, email) {},
                  magicLinkSent: (email) {},
                );
              },
              child: SafeArea(
                child: BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isLoading = state.maybeWhen(
                      loading: () => true,
                      loaded: (viewModel) => viewModel.isLoading,
                      orElse: () => false,
                    );

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.1,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () {},
                                child: Text(
                                  "Log in",
                                  style: TextStyles.titleBig,
                                ),
                              ),
                              Text("or", style: TextStyles.titleBig),
                              TextButton(
                                onPressed: () {
                                  context.pushReplacementNamed(
                                    RouteNames.signupWithEmail,
                                  );
                                },
                                child: Text(
                                  "Sign up",
                                  style: TextStyles.titleBig,
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
                            backgroundColor: context.theme.mainBackground,
                          ),
                          Gap(16),
                          CustomTextField(
                            controller: _passwordController,
                            labelText: "Password",
                            hintText: "Password",
                            obscureText: !_isPasswordVisible,
                            backgroundColor: context.theme.mainBackground,
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
                              onTap: () => showStyledMessageDialog<void>(
                                context: context,
                                message:
                                    'Password recovery is not available yet. '
                                    'Please contact support.',
                              ),
                              child: Text(
                                "Forgot your password?",
                                style: TextStyles.bodyMain.copyWith(
                                  fontSize: 14,
                                  color: AppColors.textGray2,
                                ),
                              ),
                            ),
                          ),
                          Gap(28),
                          CustomButton(
                            text: isLoading ? "Loading..." : "Continue",
                            isDisabled: isLoading,
                            onTap: () {
                              if (_emailController.text.isEmpty ||
                                  _passwordController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please fill all fields'),
                                  ),
                                );
                                return;
                              }
                              context.read<AuthBloc>().add(
                                    AuthEvent.login(
                                      request: LoginRequest.email(
                                        email: _emailController.text.trim(),
                                        password: _passwordController.text,
                                      ),
                                    ),
                                  );
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
                                text: "Continue with number",
                                onTap: () {
                                  context.pushNamed(RouteNames.login);
                                },
                              ),
                              CustomButton(
                                text: "Continue with Apple",
                                prefixIcon: Assets.icons.appleLogo.svg(),
                                isDisabled: isLoading,
                                onTap: () {
                                  context.read<AuthBloc>().add(
                                        AuthEvent.login(
                                            request: LoginRequest.social(
                                                provider:
                                                    SocialProvider.apple)),
                                      );
                                },
                                padding: EdgeInsets.symmetric(vertical: 10),
                                textStyle: TextStyles.titleMain.copyWith(
                                  fontSize: 17,
                                ),
                              ),
                              CustomButton(
                                text: "Continue with Google",
                                prefixIcon: Assets.icons.googleLogo.svg(),
                                isDisabled: isLoading,
                                onTap: () {
                                  context.read<AuthBloc>().add(
                                        AuthEvent.login(
                                            request: LoginRequest.social(
                                                provider:
                                                    SocialProvider.google)),
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
                                style: TextStyles.bodyMain.copyWith(
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height:
                                MediaQuery.of(context).viewInsets.bottom + 20,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
