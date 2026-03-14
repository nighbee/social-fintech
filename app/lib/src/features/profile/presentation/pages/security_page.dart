import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:app/src/features/profile/presentation/models/delete_account_flow_data.dart';
import 'package:app/src/features/profile/presentation/widgets/settings/settings_option_widgets.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  List<String> _twoFactorMethodIds = const <String>[];

  final List<_SecuritySessionItem> _activeSessions =
      const <_SecuritySessionItem>[
        _SecuritySessionItem(
          deviceName: 'iPhone 17 Pro Max',
          details: 'Almaty, Kazakhstan - online',
        ),
      ];

  bool get _isTwoFactorEnabled => _twoFactorMethodIds.length >= 2;

  Future<void> _openChangePasswordPage() async {
    await context.pushNamed(RouteNames.profileSecurityChangePassword);
  }

  Future<void> _openTwoFactorPage() async {
    final result = await context.pushNamed(
      RouteNames.profileSecurityTwoFactor,
      extra: <String, dynamic>{
        'selectedMethodIds': _twoFactorMethodIds,
      },
    );
    if (!mounted || result is! Map<String, dynamic>) {
      return;
    }

    final selectedMethodIds =
        (result['selectedMethodIds'] as List<dynamic>?)
            ?.whereType<String>()
            .toList();
    if (selectedMethodIds == null) {
      return;
    }

    setState(() {
      _twoFactorMethodIds = selectedMethodIds;
    });
  }

  Future<void> _openActiveSessionsPage() async {
    await context.pushNamed(
      RouteNames.profileSecurityActiveSessions,
      extra: <String, dynamic>{
        'sessions': _activeSessions
            .map(
              (session) => <String, dynamic>{
                'deviceName': session.deviceName,
                'details': session.details,
              },
            )
            .toList(),
      },
    );
  }

  DeleteAccountFlowData _resolveDeleteAccountFlowData() {
    final profileState = getIt<ProfileBloc>().state;
    final authState = getIt<AuthBloc>().state;

    final displayName = profileState.maybeWhen(
      loading: (viewModel) => viewModel.profile.displayName,
      loaded: (viewModel) => viewModel.profile.displayName,
      orElse: () => '',
    );
    final avatarUrl = profileState.maybeWhen(
      loading: (viewModel) => viewModel.profile.avatarUrl,
      loaded: (viewModel) => viewModel.profile.avatarUrl,
      orElse: () => '',
    );
    final email = authState.maybeWhen(
      authenticated: (loginEntity) => loginEntity.user.email,
      emailChecked: (_, email) => email,
      loaded: (viewModel) => viewModel.email ?? '',
      orElse: () => '',
    ).trim();
    final phoneNumber = authState.maybeWhen(
      phoneVerificationStarted: (_, phoneNumber) => phoneNumber,
      orElse: () => DeleteAccountFlowData.defaultPhoneNumber,
    ).trim();

    return DeleteAccountFlowData(
      verificationMethod: email.isNotEmpty
          ? DeleteAccountFlowData.emailMethod
          : DeleteAccountFlowData.phoneMethod,
      displayName: displayName,
      avatarUrl: avatarUrl,
      email: email,
      phoneNumber: phoneNumber,
    );
  }

  Future<void> _openDeleteAccountFlow() async {
    await context.pushNamed(
      RouteNames.profileSecurityDeleteAccount,
      extra: _resolveDeleteAccountFlowData().toExtra(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      appBar: const CustomAppBar(
        title: 'Security',
        backgroundColor: AppColors.colorff19191A,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SecuritySectionLabel(title: 'Login'),
              const Gap(12),
              SettingsOptionCard(
                child: Column(
                  children: [
                    _SecurityMenuRow(
                      title: 'Change password',
                      onTap: _openChangePasswordPage,
                    ),
                    _SecurityMenuRow(
                      title: '2-Step Verification',
                      trailingValue: _isTwoFactorEnabled ? 'On' : 'Off',
                      onTap: _openTwoFactorPage,
                    ),
                  ],
                ),
              ),
              const Gap(20),
              const _SecuritySectionLabel(title: 'Devices'),
              const Gap(12),
              SettingsOptionCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: _SecurityMenuRow(
                  title: 'Active Sessions',
                  trailingValue: '${_activeSessions.length}',
                  onTap: _openActiveSessionsPage,
                ),
              ),
              const Gap(20),
              const _SecuritySectionLabel(title: 'Account'),
              const Gap(12),
              SettingsOptionCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: _SecurityMenuRow(
                  title: 'Delete account',
                  isDestructive: true,
                  onTap: _openDeleteAccountFlow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecuritySectionLabel extends StatelessWidget {
  const _SecuritySectionLabel({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyles.bodyLarge.copyWith(
        color: const Color(0xFFA3A3A3),
        height: 1.4,
      ),
    );
  }
}

class _SecurityMenuRow extends StatelessWidget {
  const _SecurityMenuRow({
    required this.title,
    required this.onTap,
    this.trailingValue,
    this.isDestructive = false,
  });

  final String title;
  final String? trailingValue;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyles.bodyLarge.copyWith(
                    color: isDestructive
                        ? AppColors.colorffEF4444
                        : AppColors.textBrand,
                    height: 1.4,
                  ),
                ),
              ),
              if (trailingValue != null) ...[
                const Gap(12),
                Text(
                  trailingValue!,
                  style: TextStyles.bodyLarge.copyWith(
                    fontSize: 17,
                    color: const Color(0xFFA3A3A3),
                    height: 21 / 17,
                  ),
                ),
              ],
              const Gap(8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: Color(0xFFA3A3A3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecuritySessionItem {
  const _SecuritySessionItem({
    required this.deviceName,
    required this.details,
  });

  final String deviceName;
  final String details;
}
