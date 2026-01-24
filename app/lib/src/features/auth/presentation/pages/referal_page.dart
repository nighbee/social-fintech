import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReferalPage extends StatefulWidget {
  const ReferalPage({super.key});

  @override
  State<ReferalPage> createState() => _ReferalPageState();
}

class _ReferalPageState extends State<ReferalPage> {
  final TextEditingController _nicknameController = TextEditingController();
  bool _isLoading = false;
  String? _email;
  String? _password;
  String? _firstName;
  String? _lastName;
  String? _dateOfBirth;

  @override
  void initState() {
    super.initState();
    // Get registration data from route extra
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
      if (extra != null) {
        setState(() {
          _email = extra['email'] as String?;
          _password = extra['password'] as String?;
          _firstName = extra['firstName'] as String?;
          _lastName = extra['lastName'] as String?;
          _dateOfBirth = extra['dateOfBirth'] as String?;
        });
      }
    });
    _nicknameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_email == null ||
        _password == null ||
        _firstName == null ||
        _lastName == null ||
        _dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing registration data')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authRepository = getIt<IAuthRepository>(
      instanceName: 'AuthRepositoryImpl',
    );

    final result = await authRepository.registerWithEmail(
      email: _email!,
      password: _password!,
      firstName: _firstName!,
      lastName: _lastName!,
      dateOfBirth: _dateOfBirth!,
      referral: _nicknameController.text.trim(),
    );

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    result.fold(
      (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      },
      (loginEntity) {
        // Tokens are automatically saved by the repository
        // Navigate to home
        context.go(RoutePaths.home);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.mainBackground,
      appBar: CustomAppBar(
        title: 'Code',
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _register,
            child: Text(
              'Skip',
              style: context.theme.textStyles.bodyMedium.copyWith(
                color: AppColors.whiteBackground,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Gap(40),
              Text(
                "Have you been invited?",
                style: context.theme.textStyles.titleXLarge,
              ),
              Gap(16),
              Text(
                "If you came based on a recommendation, specify the nickname of the person who invited you. We will give him 1 seal as a token of gratitude.",
                style: context.theme.textStyles.bodyMedium,
              ),
              Gap(40),
              CustomTextField(
                controller: _nicknameController,
                labelText: "Nickname",
                hintText: "",
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
                onChanged: (value) {
                  setState(() {});
                },
              ),
              Gap(40),
              CustomButton(
                text: _isLoading ? "Loading..." : "Confirm",
                isDisabled: _isLoading,
                onTap: _register,
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
            ],
          ),
        ),
      ),
    );
  }
}
