import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/particle_animation.dart';
import 'package:app/src/features/auth/domain/entities/user_search_entity.dart';
import 'package:app/src/features/auth/domain/requests/register_request.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:app/src/features/auth/presentation/widgets/referral_autocomplete_field.dart';
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
  final _nicknameFocusNode = FocusNode();

  bool _validateNickname = false;
  UserSearchEntity? _selectedReferralUser;

  @override
  void dispose() {
    _nicknameController.dispose();
    _nicknameFocusNode.dispose();
    super.dispose();
  }

  String? _nicknameValidator(String? value) {
    if (!_validateNickname) return null;
    if ((value?.trim() ?? '').isEmpty) {
      return 'Please enter nickname or tap Skip';
    }
    if (_selectedReferralUser == null) {
      return 'Please select user from list';
    }
    return null;
  }

  void _dispatchRegister({required bool withReferral}) {
    if (withReferral) {
      setState(() {
        _validateNickname = true;
      });
      if (_selectedReferralUser == null) {
        _formKey.currentState?.validate();
        return;
      }
      final isValid = _formKey.currentState?.validate() ?? false;
      if (!isValid) return;
    }

    final referralUserId = _selectedReferralUser?.userId;
    final request = widget.firebaseIdToken != null
        ? RegisterRequest.firebasePhone(
            firebaseIdToken: widget.firebaseIdToken!,
            firstName: widget.firstName!,
            lastName: widget.lastName!,
            dateOfBirth: widget.dateOfBirth!,
            referral: withReferral ? referralUserId : '',
          )
        : RegisterRequest.email(
            email: widget.email!,
            password: widget.password!,
            firstName: widget.firstName!,
            lastName: widget.lastName!,
            dateOfBirth: widget.dateOfBirth!,
            referral: withReferral ? referralUserId : '',
          );

    getIt<AuthBloc>().add(AuthEvent.register(request: request));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      bloc: getIt<AuthBloc>(),
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
        final searchData = state.maybeWhen(
          loaded: (viewModel) => viewModel.userSearchResults,
          orElse: () => <UserSearchEntity>[],
        );

        final isSearchLoading = state.maybeWhen(
          loaded: (viewModel) => viewModel.isUserSearchLoading,
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
                        const Gap(40),
                        Text('Have you been invited?',
                            style: TextStyles.titleXBig),
                        const Gap(16),
                        Text(
                          'If you came based on a recommendation, specify the nickname of the person who invited you. We will give him 1 seal as a token of gratitude.',
                          style: TextStyles.bodyLarge,
                        ),
                        const Gap(40),
                        ReferralAutocompleteField(
                          controller: _nicknameController,
                          focusNode: _nicknameFocusNode,
                          searchData: searchData,
                          isSearchLoading: isSearchLoading,
                          validateNickname: _validateNickname,
                          formKey: _formKey,
                          validator: _nicknameValidator,
                          onSelectedUser: (user) {
                            setState(() {
                              _selectedReferralUser = user;
                            });
                          },
                          onInputChanged: (value) {
                            final selected = _selectedReferralUser;
                            if (selected == null) return;
                            final selectedFullName =
                                '${selected.firstName} ${selected.lastName}'
                                    .trim();
                            if (value.trim() != selectedFullName) {
                              setState(() {
                                _selectedReferralUser = null;
                              });
                            }
                          },
                        ),
                        const Gap(40),
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
