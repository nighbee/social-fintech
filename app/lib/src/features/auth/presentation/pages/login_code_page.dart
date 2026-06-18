// ignore_for_file: unused_field

import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/code_input_field.dart';
import 'package:app/src/core/widgets/particle_animation.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class LoginCodePage extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final bool isLogin;

  const LoginCodePage({
    super.key,
    this.verificationId = '',
    this.phoneNumber = '',
    this.isLogin = true,
  });

  @override
  State<LoginCodePage> createState() => _LoginCodePageState();
}

class _LoginCodePageState extends State<LoginCodePage> {
  String _code = '';

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<AuthBloc>(),
      child: Scaffold(
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
                  particleColors: [Color(0xFFFFFFFF)],
                  minSize: 1.0,
                  maxSize: 3.0,
                  minDistanceBetweenParticles: 92.0,
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
                    if (!(ModalRoute.of(context)?.isCurrent ?? false)) {
                      return;
                    }
                    final firebaseIdToken =
                        context.read<AuthBloc>().viewModel.firebaseIdToken;
                    context.pushNamed(
                      RouteNames.info,
                      extra: {
                        'phoneNumber': widget.phoneNumber,
                        'firebaseIdToken': firebaseIdToken,
                        'firebaseAuthProvider': 'phone',
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
                          Text("Enter the code", style: TextStyles.titleXBig),
                          Gap(16),
                          Text(
                            "Enter the code we've sent by SMS to ${widget.phoneNumber}:",
                            style: TextStyles.bodyLarge,
                          ),
                          Gap(40),
                          Center(
                            child: CodeInputField(
                              length: 6,
                              onChanged: (code) {
                                setState(() {
                                  _code = code;
                                });
                              },
                            ),
                          ),
                          Gap(40),
                          CustomButton(
                            text: "Continue",
                            isDisabled: isLoading || _code.length != 6,
                            onTap: () {
                              if (_code.length == 6) {
                                context.read<AuthBloc>().add(
                                      AuthEvent.verifyOtpCode(
                                        verificationId: widget.verificationId,
                                        code: _code,
                                        isLogin: widget.isLogin,
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
