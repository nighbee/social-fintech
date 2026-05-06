import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/core/widgets/particle_animation.dart';
import 'package:app/src/features/auth/domain/requests/login_request.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class EmailPasswordPage extends StatefulWidget {
  final String email;
  final bool isNewUser;

  const EmailPasswordPage({
    super.key,
    required this.email,
    required this.isNewUser,
  });

  @override
  State<EmailPasswordPage> createState() => _EmailPasswordPageState();
}

class _EmailPasswordPageState extends State<EmailPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidPassword() {
    if (_passwordController.text.length < 8) return false;
    if (!widget.isNewUser) return true;
    return _passwordController.text == _confirmPasswordController.text;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<AuthBloc>(),
      child: Scaffold(
        backgroundColor: context.theme.mainBackground,
        appBar: const CustomAppBar(
            title: 'Password', backgroundColor: Colors.transparent),
        body: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ParticleAnimation(
                  particleCount: 25,
                  particleColors: const [Color(0xFFFFFFFF)],
                  minSize: 4.0,
                  maxSize: 8.0,
                  minDistanceBetweenParticles: 70.0,
                ),
              ),
            ),
            BlocListener<AuthBloc, AuthState>(
              listener: (context, state) {
                state.when(
                  initial: () {},
                  loading: () {},
                  loadingFailure: (message) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(message), backgroundColor: Colors.red),
                    );
                  },
                  goRegister: () {
                    final authBloc = context.read<AuthBloc>();
                    final firebaseIdToken = authBloc.viewModel.firebaseIdToken;
                    final firebaseAuthProvider =
                        authBloc.viewModel.firebaseAuthProvider;
                    if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
                      return;
                    }
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
                    context.go(RoutePaths.home);
                  },
                  phoneVerificationStarted: (verificationId, phoneNumber) {},
                  emailChecked: (exists, email) {},
                  magicLinkSent: (email) {},
                );
              },
              child: BlocBuilder<AuthBloc, AuthState>(
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Gap(40),
                          Text(
                            widget.isNewUser
                                ? "Create your account"
                                : "Welcome back!",
                            style: TextStyles.titleXBig,
                          ),
                          Gap(16),
                          Text(
                            widget.email,
                            style: TextStyles.bodyLarge.copyWith(
                              color: AppColors.colorff74afe3,
                            ),
                          ),
                          Gap(40),
                          CustomTextField(
                            controller: _passwordController,
                            labelText: "Password",
                            hintText: widget.isNewUser
                                ? "At least 8 characters"
                                : "Enter password",
                            obscureText: !_isPasswordVisible,
                            onChanged: (value) => setState(() {}),
                            suffixIcon: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: _isPasswordVisible
                                    ? Assets.icons.eyeOpened.svg(
                                        width: 20,
                                        height: 20,
                                        colorFilter: ColorFilter.mode(
                                          AppColors.colorff74afe3,
                                          BlendMode.srcIn,
                                        ),
                                      )
                                    : Assets.icons.eyeClosed.svg(
                                        width: 20,
                                        height: 20,
                                        colorFilter: ColorFilter.mode(
                                          AppColors.colorff838383,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          if (widget.isNewUser) ...[
                            Gap(16),
                            CustomTextField(
                              controller: _confirmPasswordController,
                              labelText: "Confirm Password",
                              hintText: "Re-enter password",
                              obscureText: !_isConfirmPasswordVisible,
                              onChanged: (value) => setState(() {}),
                              suffixIcon: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isConfirmPasswordVisible =
                                        !_isConfirmPasswordVisible;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: _isConfirmPasswordVisible
                                      ? Assets.icons.eyeOpened.svg(
                                          width: 20,
                                          height: 20,
                                          colorFilter: ColorFilter.mode(
                                            AppColors.colorff74afe3,
                                            BlendMode.srcIn,
                                          ),
                                        )
                                      : Assets.icons.eyeClosed.svg(
                                          width: 20,
                                          height: 20,
                                          colorFilter: ColorFilter.mode(
                                            AppColors.colorff838383,
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                          Gap(40),
                          CustomButton(
                            text: isLoading
                                ? "Loading..."
                                : (widget.isNewUser ? "Continue" : "Login"),
                            isDisabled: isLoading || !_isValidPassword(),
                            onTap: () {
                              if (!_isValidPassword()) return;

                              if (widget.isNewUser) {
                                context.read<AuthBloc>().add(
                                      AuthEvent.checkEmail(email: widget.email),
                                    );

                                final bloc = context.read<AuthBloc>();
                                bloc.add(
                                    AuthEvent.checkEmail(email: widget.email));

                                Future.delayed(
                                    const Duration(milliseconds: 100), () {
                                  if (!mounted) return;
                                  context.pushNamed(
                                    RouteNames.info,
                                    extra: {
                                      'email': widget.email,
                                      'password':
                                          _passwordController.text.trim(),
                                    },
                                  );
                                });
                              } else {
                                context.read<AuthBloc>().add(
                                      AuthEvent.login(
                                        request: LoginRequest.email(
                                          email: widget.email,
                                          password:
                                              _passwordController.text.trim(),
                                        ),
                                      ),
                                    );
                              }
                            },
                          ),
                          Gap(20),
                          SizedBox(
                            height:
                                MediaQuery.of(context).viewInsets.bottom + 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
