import 'package:app/src/core/constants/regex_constants.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/core/widgets/particle_animation.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class EmailEntryPage extends StatefulWidget {
  const EmailEntryPage({super.key});

  @override
  State<EmailEntryPage> createState() => _EmailEntryPageState();
}

class _EmailEntryPageState extends State<EmailEntryPage> {
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegexConstants.email.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<AuthBloc>(),
      child: Scaffold(
        backgroundColor: context.theme.mainBackground,
        appBar: const CustomAppBar(
            title: 'Email', backgroundColor: Colors.transparent),
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
                  authenticated: (loginEntity) {},
                  phoneVerificationStarted: (verificationId, phoneNumber) {},
                  emailChecked: (exists, email) {
                    context.pushNamed(
                      RouteNames.emailPassword,
                      extra: {'email': email, 'isNewUser': !exists},
                    );
                  },
                  magicLinkSent: (email) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Check your email: $email'),
                      ),
                    );
                  },
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                              height: MediaQuery.of(context).size.height * 0.1),
                          Text("Enter your email", style: TextStyles.titleXBig),
                          Gap(16),
                          Text(
                            "We'll check if you have an account",
                            style: TextStyles.bodyLarge,
                          ),
                          Gap(40),
                          CustomTextField(
                            controller: _emailController,
                            labelText: "Email",
                            hintText: "your@email.com",
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (value) => setState(() {}),
                          ),
                          Gap(40),
                          CustomButton(
                            text: isLoading ? "Loading..." : "Continue",
                            isDisabled: isLoading ||
                                !_isValidEmail(_emailController.text),
                            backgroundColor: Colors.transparent,
                            border: Border.all(color: Colors.white38),
                            textStyle: TextStyles.titleMain.copyWith(
                              color: Colors.white,
                            ),
                            onTap: () {
                              if (_isValidEmail(_emailController.text)) {
                                context.read<AuthBloc>().add(
                                      AuthEvent.checkEmail(
                                        email: _emailController.text.trim(),
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
