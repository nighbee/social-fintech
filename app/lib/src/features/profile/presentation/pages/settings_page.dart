import 'dart:async';

import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.currentUserId,
  });

  final String? currentUserId;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _participateInDistrictRankings = false;
  String _feedTimeLimitLabel = 'No limit';
  String _locationAccessLabel = 'Never';
  bool _isPreciseLocationEnabled = false;
  String _appVersion = '1.0.0';
  bool _showFeedbackBanner = false;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;

    setState(() {
      _appVersion =
          packageInfo.version.isEmpty ? _appVersion : packageInfo.version;
    });
  }

  void _showPlaceholderMessage(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title is not available yet.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.colorff202020,
      ),
    );
  }

  String? _resolveCurrentUserId() {
    final routeUserId = widget.currentUserId?.trim();
    if (routeUserId != null && routeUserId.isNotEmpty) {
      return routeUserId;
    }

    return getIt<ProfileBloc>().state.maybeWhen(
      loaded: (viewModel) => viewModel.profile.userId,
      orElse: () => null,
    );
  }

  void _logout() {
    getIt<AuthBloc>().add(const AuthEvent.logout());
    context.go(RoutePaths.loginWithEmail);
  }

  Future<void> _openReportBug() async {
    final result = await context.pushNamed(RouteNames.profileReportBug);
    if (!mounted || result != true) return;

    _feedbackTimer?.cancel();
    setState(() {
      _showFeedbackBanner = true;
    });
    _feedbackTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _showFeedbackBanner = false;
      });
    });
  }

  Future<void> _openFeedTimeLimitPage() async {
    final result = await context.pushNamed(
      RouteNames.profileFeedTimeLimit,
      extra: {'initialSelectionLabel': _feedTimeLimitLabel},
    );
    if (!mounted || result is! String || result.isEmpty) {
      return;
    }

    setState(() {
      _feedTimeLimitLabel = result;
    });
  }

  Future<void> _openLocationAccessPage() async {
    final result = await context.pushNamed(
      RouteNames.profileLocationAccess,
      extra: <String, dynamic>{
        'initialSelectionLabel': _locationAccessLabel,
        'initialPreciseLocationEnabled': _isPreciseLocationEnabled,
      },
    );
    if (!mounted || result is! Map<String, dynamic>) {
      return;
    }

    final selectedLabel = result['selectedLabel'] as String?;
    final isPreciseLocationEnabled =
        result['isPreciseLocationEnabled'] as bool? ?? false;
    if (selectedLabel == null || selectedLabel.isEmpty) {
      return;
    }

    setState(() {
      _locationAccessLabel = selectedLabel;
      _isPreciseLocationEnabled = isPreciseLocationEnabled;
    });
  }

  String _locationAccessSummaryLabel() {
    switch (_locationAccessLabel) {
      case 'Ask next time or when i share':
        return 'Ask next time';
      case 'While using the app':
        return 'While using';
      default:
        return _locationAccessLabel;
    }
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      appBar: const CustomAppBar(
        title: 'Settings',
        backgroundColor: AppColors.colorff19191A,
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SettingsSection(
                    title: 'Social & Experience',
                    child: _SettingsGroupCard(
                      children: [
                        _SettingsRow(
                          title: 'Interactions',
                          onTap: () =>
                              context.pushNamed(RouteNames.profileInteractions),
                        ),
                        _SettingsRow.switchTile(
                          title: 'Participate in district rankings',
                          value: _participateInDistrictRankings,
                          onChanged: (value) {
                            setState(() {
                              _participateInDistrictRankings = value;
                            });
                          },
                        ),
                        _SettingsRow(
                          title: 'Feed time limit',
                          trailingValue: _feedTimeLimitLabel,
                          onTap: _openFeedTimeLimitPage,
                        ),
                      ],
                    ),
                  ),
                  const Gap(24),
                  _SettingsSection(
                    title: 'Account & System',
                    child: _SettingsGroupCard(
                      children: [
                        _SettingsRow(
                          title: 'Security',
                          onTap: () => context.pushNamed(
                            RouteNames.profileSecurity,
                          ),
                        ),
                        _SettingsRow(
                          title: 'Location access',
                          trailingValue: _locationAccessSummaryLabel(),
                          onTap: _openLocationAccessPage,
                        ),
                      ],
                    ),
                  ),
                  const Gap(24),
                  _SettingsSection(
                    title: 'Invitations',
                    child: _SettingsGroupCard(
                      children: [
                        _SettingsRow(
                          title: 'Invite & Earn Golden Honor',
                          onTap: () => context.pushNamed(
                            RouteNames.profileInviteGoldenHonor,
                            extra: {'userId': _resolveCurrentUserId()},
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(24),
                  _SettingsSection(
                    title: 'Support & About',
                    child: _SettingsGroupCard(
                      children: [
                        _SettingsRow(
                          title: 'Contact Us',
                          onTap: () =>
                              context.pushNamed(RouteNames.profileContactUs),
                        ),
                        _SettingsRow(
                          title: 'Report a bug',
                          onTap: _openReportBug,
                        ),
                        _SettingsRow(
                          title: 'Terms & Conditions',
                          onTap: () => context.pushNamed(
                            RouteNames.profileTermsConditions,
                          ),
                        ),
                        _SettingsRow.value(
                          title: 'App version',
                          value: _appVersion,
                        ),
                      ],
                    ),
                  ),
                  const Gap(24),
                  _SettingsGroupCard(
                    children: [
                      _SettingsRow.destructive(
                        title: 'Log out',
                        onTap: _logout,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_showFeedbackBanner)
              const Positioned(
                left: 12,
                right: 12,
                bottom: 16,
                child: _SettingsFeedbackBanner(),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsFeedbackBanner extends StatelessWidget {
  const _SettingsFeedbackBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundNeutralSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.colorffffffff,
            size: 24,
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thank you!',
                  style: TextStyles.bodyLarge.copyWith(
                    color: AppColors.colorffffffff,
                    fontWeight: FontWeight.w600,
                    height: 19 / 16,
                  ),
                ),
                const Gap(4),
                Text(
                  'Your feedback helps BrightBund improve.',
                  style: TextStyles.bodyMain.copyWith(
                    color: AppColors.colorff87898f,
                    fontSize: 16,
                    height: 22 / 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyles.bodyMain.copyWith(
            color: AppColors.colorffa9a9a9,
            fontSize: 14,
            height: 20 / 14,
          ),
        ),
        const Gap(10),
        child,
      ],
    );
  }
}

class _SettingsGroupCard extends StatelessWidget {
  const _SettingsGroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.colorff202020,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.colorff3F3F40,
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.colorff2A2A2B,
                indent: 16,
                endIndent: 16,
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    this.onTap,
    this.trailingValue,
    this.showChevron = true,
    this.destructive = false,
    this.switchValue,
    this.onSwitchChanged,
  });

  const _SettingsRow.switchTile({
    required this.title,
    required bool value,
    required ValueChanged<bool> onChanged,
  })  : onTap = null,
        trailingValue = null,
        showChevron = false,
        destructive = false,
        switchValue = value,
        onSwitchChanged = onChanged;

  const _SettingsRow.value({
    required this.title,
    required String value,
  })  : onTap = null,
        trailingValue = value,
        showChevron = false,
        destructive = false,
        switchValue = null,
        onSwitchChanged = null;

  const _SettingsRow.destructive({
    required this.title,
    required this.onTap,
  })  : trailingValue = null,
        showChevron = false,
        destructive = true,
        switchValue = null,
        onSwitchChanged = null;

  final String title;
  final VoidCallback? onTap;
  final String? trailingValue;
  final bool showChevron;
  final bool destructive;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;

  @override
  Widget build(BuildContext context) {
    final rowTextColor =
        destructive ? AppColors.colorffEF4444 : AppColors.colorffffffff;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: switchValue != null && onSwitchChanged != null
            ? () => onSwitchChanged!(!switchValue!)
            : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyles.bodyLarge.copyWith(
                    color: rowTextColor,
                    height: 20 / 16,
                  ),
                ),
              ),
              if (trailingValue != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    trailingValue!,
                    style: TextStyles.bodyMain.copyWith(
                      color: AppColors.colorff838383,
                      fontSize: 14,
                      height: 20 / 14,
                    ),
                  ),
                ),
              if (switchValue != null)
                Transform.scale(
                  scale: 0.84,
                  child: Switch(
                    value: switchValue!,
                    onChanged: onSwitchChanged,
                    activeTrackColor: AppColors.colorff74afe3,
                    inactiveTrackColor: AppColors.colorff3F3F40,
                    inactiveThumbColor: AppColors.colorffffffff,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              if (showChevron)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.colorff838383,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
