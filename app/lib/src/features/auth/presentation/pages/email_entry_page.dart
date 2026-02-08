import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
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
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<AuthBloc>(),
      child: Scaffold(
        backgroundColor: context.theme.mainBackground,
        appBar: const CustomAppBar(title: 'Email'),
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
              authenticated: (loginEntity) {},
              phoneVerificationStarted: (verificationId, phoneNumber) {},
              emailChecked: (exists, email) {
                context.pushNamed(
                  RouteNames.emailPassword,
                  extra: {
                    'email': email,
                    'isNewUser': !exists,
                  },
                );
              },
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                    Text(
                      "Enter your email",
                      style: context.theme.textStyles.titleXLarge,
                    ),
                    Gap(16),
                    Text(
                      "We'll check if you have an account",
                      style: context.theme.textStyles.bodyMedium,
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
                      text: isLoading ? "Checking..." : "Continue",
                      isDisabled: isLoading || !_isValidEmail(_emailController.text),
                      onTap: () {
                        if (_isValidEmail(_emailController.text)) {
                          context.read<AuthBloc>().add(
                            AuthEvent.checkEmail(email: _emailController.text.trim()),
                          );
                        }
                      },
                    ),
                    Gap(20),
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
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
