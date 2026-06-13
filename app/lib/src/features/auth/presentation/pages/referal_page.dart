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
    this.firebaseAuthProvider,
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    super.key,
  });

  final String? email;
  final String? password;
  final String? phoneNumber;
  final String? firebaseIdToken;
  final String? firebaseAuthProvider;
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
  bool _showReferralSuccessAfterRegister = false;
  bool _isHandlingAuthSuccess = false;

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

    _showReferralSuccessAfterRegister = withReferral;

    final referralUserId = _selectedReferralUser?.userId;
    final request = widget.firebaseIdToken != null
        ? _buildFirebaseRegisterRequest(
            withReferral: withReferral,
            referralUserId: referralUserId,
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

  RegisterRequest _buildFirebaseRegisterRequest({
    required bool withReferral,
    required String? referralUserId,
  }) {
    final provider = (widget.firebaseAuthProvider ?? '').trim().toLowerCase();
    if (provider == 'email') {
      return RegisterRequest.firebaseEmail(
        firebaseIdToken: widget.firebaseIdToken!,
        firstName: widget.firstName!,
        lastName: widget.lastName!,
        dateOfBirth: widget.dateOfBirth!,
        referral: withReferral ? referralUserId : '',
      );
    }
    return RegisterRequest.firebasePhone(
      firebaseIdToken: widget.firebaseIdToken!,
      firstName: widget.firstName!,
      lastName: widget.lastName!,
      dateOfBirth: widget.dateOfBirth!,
      referral: withReferral ? referralUserId : '',
    );
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
          loaded: (_) {},
          authenticated: (_) async {
            if (!(ModalRoute.of(context)?.isCurrent ?? false)) {
              return;
            }

            if (_isHandlingAuthSuccess) {
              return;
            }

            _isHandlingAuthSuccess = true;
            try {
              if (_showReferralSuccessAfterRegister &&
                  _selectedReferralUser != null &&
                  context.mounted) {
                context.go(
                  RoutePaths.home,
                  extra: const {'showReferralInviteActivated': true},
                );
                return;
              }
              if (context.mounted) {
                context.go(RoutePaths.home);
              }
            } finally {
              _isHandlingAuthSuccess = false;
            }
          },
          phoneVerificationStarted: (_, __) {},
          emailChecked: (_, __) {},
          magicLinkSent: (_) {},
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
                    color: AppColors.colorffffffff,
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
                    particleCount: 14,
                    particleColors: const [Color(0xFFFFFFFF)],
                    minSize: 1.0,
                    maxSize: 3.0,
                    minDistanceBetweenParticles: 92.0,
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
                            final normalizedValue = value.trim().toLowerCase();
                            final selectedDisplayName =
                                selected.displayName.trim().toLowerCase();
                            final selectedFullName =
                                '${selected.firstName} ${selected.lastName}'
                                    .trim()
                                    .toLowerCase();
                            if (normalizedValue != selectedDisplayName &&
                                normalizedValue != selectedFullName) {
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
