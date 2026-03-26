import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_outlined_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/core/widgets/particle_animation.dart';
import 'package:app/src/core/widgets/phone_number_formatter.dart';
import 'package:app/src/features/auth/domain/requests/login_request.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class LoginWithNumberPage extends StatefulWidget {
  const LoginWithNumberPage({super.key});

  @override
  State<LoginWithNumberPage> createState() => _LoginWithNumberPageState();
}

class _LoginWithNumberPageState extends State<LoginWithNumberPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _countryController = TextEditingController(
    text: 'Kazakhstan (+7)',
  );
  String _selectedCountryCode = '+7';

  @override
  void initState() {
    super.initState();
    _countryController.addListener(() {});
    _phoneController.text = _selectedCountryCode;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _updateCountryCode(String countryCode, String displayText) {
    setState(() {
      final currentText = _phoneController.text;
      final phoneNumber = currentText.length > _selectedCountryCode.length
          ? currentText.substring(_selectedCountryCode.length)
          : '';

      _selectedCountryCode = countryCode;
      _countryController.text = displayText;
      _phoneController.text = countryCode + phoneNumber;
    });
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.theme.mainBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select Country/Region', style: TextStyles.titleBig),
            Gap(20),
            ListTile(
              title: const Text('Kazakhstan'),
              subtitle: const Text('+7'),
              onTap: () {
                _updateCountryCode('+7', 'Kazakhstan (+7)');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('United States'),
              subtitle: const Text('+1'),
              onTap: () {
                _updateCountryCode('+1', 'United States (+1)');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Russia'),
              subtitle: const Text('+7'),
              onTap: () {
                _updateCountryCode('+7', 'Russia (+7)');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<AuthBloc>(),
      child: Scaffold(
        backgroundColor: context.theme.mainBackground,
        body: Stack(
          children: [
            // Layer 1: Fixed particle background (doesn't scroll)
            Positioned.fill(
              child: IgnorePointer(
                child: ParticleAnimation(
                  particleCount: 25,
                  particleColors: const [
                    Color(0xFFFFFFFF),
                  ],
                  minSize: 4.0,
                  maxSize: 8.0,
                  minDistanceBetweenParticles: 70.0,
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
                  goRegister: () {},
                  loaded: (viewModel) {},
                  authenticated: (loginEntity) {
                    getIt<ProfileBloc>().add(const ProfileEvent.loadProfile());
                    context.go(RoutePaths.home);
                  },
                  phoneVerificationStarted: (verificationId, phoneNumber) {
                    context.pushNamed(
                      RouteNames.loginCode,
                      extra: {
                        'verificationId': verificationId,
                        'phoneNumber': phoneNumber,
                        'isLogin': true,
                      },
                    );
                  },
                  emailChecked: (exists, email) {},
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
                                child:
                                    Text("Log in", style: TextStyles.titleBig),
                              ),
                              Text("or", style: TextStyles.titleBig),
                              TextButton(
                                onPressed: () {
                                  context
                                      .pushReplacementNamed(RouteNames.signup);
                                },
                                child:
                                    Text("Sign up", style: TextStyles.titleBig),
                              ),
                            ],
                          ),
                          Gap(63),
                          CustomTextField(
                            controller: _countryController,
                            labelText: "Country/Region",
                            hintText: "Country/Region",
                            readOnly: true,
                            onTap: _showCountryPicker,
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Icon(
                                Icons.arrow_drop_down,
                                color: AppColors.colorff838383,
                              ),
                            ),
                          ),
                          Gap(16),
                          CustomTextField(
                            controller: _phoneController,
                            labelText: "Phone number",
                            hintText: "Phone number",
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              PhoneNumberFormatter(_selectedCountryCode),
                            ],
                          ),
                          Gap(28),
                          CustomButton(
                            text: "Continue",
                            isDisabled: isLoading,
                            onTap: () {
                              final phoneText = _phoneController.text.trim();
                              final phoneNumber = phoneText
                                  .replaceAll(' ', '')
                                  .replaceAll('-', '');

                              if (phoneNumber.length < 10) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please enter a valid phone number',
                                    ),
                                  ),
                                );
                                return;
                              }

                              context.read<AuthBloc>().add(
                                    AuthEvent.startPhoneVerification(
                                      phoneNumber: phoneNumber,
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
                                  color: AppColors.colorff838383,
                                ),
                              ),
                              Text("or", style: TextStyles.titleTag),
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  height: 1,
                                  color: AppColors.colorff838383,
                                ),
                              ),
                            ],
                          ),
                          Gap(57),
                          Column(
                            spacing: 16,
                            children: [
                              CustomOutlinedButton(
                                text: "Continue with email",
                                onTap: () {
                                  context.pushNamed(RouteNames.emailEntry);
                                },
                              ),
                              CustomButton(
                                text: "Continue with Apple",
                                prefixIcon: Assets.icons.appleLogo.svg(),
                                onTap: () {},
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
                                style:
                                    TextStyles.bodyMain.copyWith(fontSize: 14),
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

