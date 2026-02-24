import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/core/widgets/particle_animation.dart';
import 'package:app/src/features/auth/domain/requests/register_request.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReferalPage extends StatefulWidget {
  const ReferalPage({
    this.email,
    this.password,
    this.phoneNumber,
    this.firebaseIdToken,
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    super.key,
  });

  final String? email;
  final String? password;
  final String? phoneNumber;
  final String? firebaseIdToken;
  final String? firstName;
  final String? lastName;
  final String? dateOfBirth;

  @override
  State<ReferalPage> createState() => _ReferalPageState();
}

class _ReferalPageState extends State<ReferalPage> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  bool _validateNickname = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  String? _nicknameValidator(String? value) {
    if (!_validateNickname) return null;
    if ((value?.trim() ?? '').isEmpty) {
      return 'Please enter nickname or tap Skip';
    }
    return null;
  }

  RegisterRequest? _buildRequest({required String referral}) {
    if (widget.firebaseIdToken != null) {
      if (widget.firstName == null ||
          widget.lastName == null ||
          widget.dateOfBirth == null) {
        _showMissingDataError();
        return null;
      }

      return RegisterRequest.firebasePhone(
        firebaseIdToken: widget.firebaseIdToken!,
        firstName: widget.firstName!,
        lastName: widget.lastName!,
        dateOfBirth: widget.dateOfBirth!,
        referral: referral,
      );
    }

    if (widget.email == null ||
        widget.password == null ||
        widget.firstName == null ||
        widget.lastName == null ||
        widget.dateOfBirth == null) {
      _showMissingDataError();
      return null;
    }

    return RegisterRequest.email(
      email: widget.email!,
      password: widget.password!,
      firstName: widget.firstName!,
      lastName: widget.lastName!,
      dateOfBirth: widget.dateOfBirth!,
      referral: referral,
    );
  }

  void _showMissingDataError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Missing registration data')),
    );
  }

  void _dispatchRegister({required bool withReferral}) {
    if (withReferral) {
      setState(() {
        _validateNickname = true;
      });
      final isValid = _formKey.currentState?.validate() ?? false;
      if (!isValid) return;
    }

    final request = _buildRequest(
      referral: withReferral ? _nicknameController.text.trim() : '',
    );
    if (request == null) return;

    getIt<AuthBloc>().add(AuthEvent.register(request: request));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
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
          loaded: (_) {},
          authenticated: (_) {
            context.go(RoutePaths.home);
          },
          phoneVerificationStarted: (_, __) {},
          emailChecked: (_, __) {},
        );
      },
      builder: (context, state) {
        final isLoading = state.maybeWhen(
          loading: () => true,
          loaded: (viewModel) => viewModel.isLoading,
          orElse: () => false,
        );

        return Scaffold(
          backgroundColor: context.theme.mainBackground,
          appBar: CustomAppBar(
            title: 'Code',
            backgroundColor: Colors.transparent,
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () => _dispatchRegister(withReferral: false),
                child: Text(
                  'Skip',
                  style: TextStyles.titleHeadline.copyWith(
                    color: AppColors.whiteBackground,
                  ),
                ),
              ),
            ],
          ),
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
              SafeArea(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Gap(40),
                        Text('Have you been invited?',
                            style: TextStyles.titleXBig),
                        Gap(16),
                        Text(
                          'If you came based on a recommendation, specify the nickname of the person who invited you. We will give him 1 seal as a token of gratitude.',
                          style: TextStyles.bodyLarge,
                        ),
                        Gap(40),
                        CustomTextField(
                          controller: _nicknameController,
                          labelText: 'Nickname',
                          hintText: '',
                          validator: _nicknameValidator,
                          prefixIcon: Assets.icons.atsign.svg(
                            width: 30,
                            height: 30,
                            colorFilter: const ColorFilter.mode(
                              AppColors.whiteBackground,
                              BlendMode.srcIn,
                            ),
                          ),
                          suffixIcon: _nicknameController.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _nicknameController.clear();
                                    });
                                    if (_validateNickname) {
                                      _formKey.currentState?.validate();
                                    }
                                  },
                                  child: Assets.icons.close.svg(
                                    width: 16,
                                    height: 16,
                                    colorFilter: const ColorFilter.mode(
                                      AppColors.textGray2,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                )
                              : null,
                          onChanged: (_) {
                            setState(() {});
                            if (_validateNickname) {
                              _formKey.currentState?.validate();
                            }
                          },
                        ),
                        Gap(40),
                        CustomButton(
                          text: isLoading ? 'Loading...' : 'Confirm',
                          isDisabled: isLoading,
                          onTap: () => _dispatchRegister(withReferral: true),
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).viewInsets.bottom + 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
