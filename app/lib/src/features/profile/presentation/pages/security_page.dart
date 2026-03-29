import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:app/src/features/profile/data/models/interaction_settings_dto.dart';
import 'package:app/src/features/profile/data/sources/remote/i_interaction_settings_remote.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:app/src/features/profile/presentation/models/delete_account_flow_data.dart';
import 'package:app/src/features/profile/presentation/widgets/settings/settings_option_widgets.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// Бэкенд: `sms` → id экрана 2FA — `phone`.
List<String> _mapApiTwoFaMethodsToUi(List<String> api) {
  return api
      .map((m) {
        switch (m) {
          case 'sms':
            return 'phone';
          default:
            return m;
        }
      })
      .toList(growable: false);
}

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final IInteractionSettingsRemote _remote =
      getIt<IInteractionSettingsRemote>();

  bool _loading = true;
  bool _twoFaEnabled = false;
  List<String> _twoFaMethodIds = const <String>[];
  int _activeSessionCount = 0;
  List<Map<String, dynamic>> _sessionMaps = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadSecurity();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadSecurity() async {
    setState(() => _loading = true);
    final overview = await _remote.getSecurityOverview();
    final sessions = await _remote.listSessions();
    if (!mounted) return;

    SecurityOverviewDto? ov;
    overview.fold((e) => _showSnack(e.message), (v) => ov = v);

    List<SessionItemDto>? list;
    sessions.fold((e) => _showSnack(e.message), (v) => list = v);

    setState(() {
      _loading = false;
      if (ov != null) {
        _twoFaEnabled = ov!.twoFaEnabled;
        _twoFaMethodIds = _mapApiTwoFaMethodsToUi(ov!.twoFaMethods);
        _activeSessionCount = ov!.activeSessions;
      }
      if (list != null) {
        _sessionMaps =
            list!.map((s) => s.toActiveSessionsPageMap()).toList();
        if (list!.isNotEmpty) {
          _activeSessionCount = list!.length;
        }
      }
    });
  }

  Future<void> _openChangePasswordPage() async {
    await context.pushNamed(RouteNames.profileSecurityChangePassword);
  }

  Future<void> _openTwoFactorPage() async {
    final result = await context.pushNamed(
      RouteNames.profileSecurityTwoFactor,
      extra: <String, dynamic>{
        'selectedMethodIds': _twoFaMethodIds,
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
      _twoFaMethodIds = selectedMethodIds;
    });
    await _loadSecurity();
  }

  Future<void> _openActiveSessionsPage() async {
    await context.pushNamed(
      RouteNames.profileSecurityActiveSessions,
      extra: <String, dynamic>{
        'sessions': _sessionMaps,
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
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.colorff838383,
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SecuritySectionLabel(title: 'Login'),
                        const Gap(12),
                        SettingsOptionCard(
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _SecurityMenuRow(
                                title: 'Change password',
                                onTap: _openChangePasswordPage,
                              ),
                              const Gap(12),
                              _SecurityMenuRow(
                                title: '2-Step Verification',
                                trailingValue:
                                    _twoFaEnabled ? 'On' : 'Off',
                                onTap: _openTwoFactorPage,
                              ),
                            ],
                          ),
                        ),
                        const Gap(20),
                        const _SecuritySectionLabel(title: 'Devices'),
                        const Gap(12),
                        SettingsOptionCard(
                          padding: const EdgeInsets.fromLTRB(
                            12,
                            16,
                            12,
                            10,
                          ),
                          child: _SecurityMenuRow(
                            title: 'Active Sessions',
                            trailingValue: '$_activeSessionCount',
                            onTap: _openActiveSessionsPage,
                          ),
                        ),
                        const Gap(20),
                        const _SecuritySectionLabel(title: 'Account'),
                        const Gap(12),
                        SettingsOptionCard(
                          padding: const EdgeInsets.fromLTRB(
                            12,
                            16,
                            12,
                            10,
                          ),
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
      style: TextStyles.bodyMain.copyWith(
        color: AppColors.colorff838383,
        fontSize: 13,
        height: 20 / 13,
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
                    color: AppColors.colorff838383,
                    height: 21 / 17,
                  ),
                ),
              ],
              const Gap(8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: AppColors.colorff838383,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
