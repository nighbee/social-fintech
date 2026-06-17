import 'dart:async';

import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/service/storage/app_storage/storage_service.dart';
import 'package:app/src/features/profile/data/local/location_access_prefs.dart';
import 'package:app/src/features/profile/data/models/interaction_settings_dto.dart';
import 'package:app/src/features/profile/data/sources/remote/i_interaction_settings_remote.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/neutral_track_switch.dart';
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
  bool _participateInDistrictRankings = true;
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
    _loadFeedTimeLimitLabel();
    _loadLocationAccessFromPrefs();
  }

  Future<void> _loadFeedTimeLimitLabel() async {
    final result = await getIt<IInteractionSettingsRemote>().getFeedSettings();
    if (!mounted) return;
    result.fold((_) {}, (dto) {
      setState(() {
        _feedTimeLimitLabel =
            feedTimeLimitLabelFromMins(effectiveFeedLimitMins(dto));
      });
    });
  }

  Future<void> _loadLocationAccessFromPrefs() async {
    await prefsInstance.initialize();
    if (!mounted) return;
    final loaded = readLocationAccessPrefs(
      initialLabel: _locationAccessLabel,
      initialPrecise: _isPreciseLocationEnabled,
    );
    setState(() {
      _locationAccessLabel = loaded.label;
      _isPreciseLocationEnabled = loaded.precise;
    });
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;

    setState(() {
      _appVersion =
          packageInfo.version.isEmpty ? _appVersion : packageInfo.version;
    });
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
    context.go(RoutePaths.login);
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
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
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
                  const Gap(28),
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
                  const Gap(28),
                  _SettingsSection(
                    title: 'Invitations',
                    child: _SettingsGroupCard(
                      children: [
                        _SettingsRow(
                          title: 'My referral code',
                          onTap: () => context.pushNamed(
                            RouteNames.profileInviteGoldenHonor,
                            extra: {'userId': _resolveCurrentUserId()},
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(28),
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
                  const Gap(20),
                  _SettingsGroupCard(
                    children: [
                      _SettingsRow.destructive(
                        title: 'Log out',
                        onTap: _logout,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
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
            color: const Color(0xFFA3A3A3),
            fontSize: 13,
            height: 18 / 13,
          ),
        ),
        const Gap(12),
        child,
      ],
    );
  }
}

class _SettingsGroupCard extends StatelessWidget {
  const _SettingsGroupCard({required this.children});

  final List<Widget> children;

  static const _fill = Color(0xFF202020);
  static const _radius = 6.0;
  static const _padding = EdgeInsets.fromLTRB(12, 14, 12, 14);
  static const _rowGap = 16.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Padding(
        padding: _padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1) SizedBox(height: _rowGap),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    this.onTap,
    this.trailingValue,
  })  : showChevron = true,
        destructive = false,
        switchValue = null,
        onSwitchChanged = null,
        compact = false;

  const _SettingsRow.switchTile({
    required this.title,
    required bool value,
    required ValueChanged<bool> onChanged,
  })  : onTap = null,
        trailingValue = null,
        showChevron = false,
        destructive = false,
        switchValue = value,
        onSwitchChanged = onChanged,
        compact = false;

  const _SettingsRow.value({
    required this.title,
    required String value,
  })  : onTap = null,
        trailingValue = value,
        showChevron = false,
        destructive = false,
        switchValue = null,
        onSwitchChanged = null,
        compact = false;

  const _SettingsRow.destructive({
    required this.title,
    required this.onTap,
  })  : trailingValue = null,
        showChevron = false,
        destructive = true,
        switchValue = null,
        onSwitchChanged = null,
        compact = false;

  final String title;
  final VoidCallback? onTap;
  final String? trailingValue;
  final bool showChevron;
  final bool destructive;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;

  /// Второстепенная строка (меньше шрифт) — например «Have you been invited?»
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rowTextColor =
        destructive ? AppColors.colorffEF4444 : AppColors.colorffffffff;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: destructive
            ? onTap
            : switchValue != null && onSwitchChanged != null
                ? null
                : onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: switchValue != null ? 4 : (compact ? 4 : 10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: compact
                      ? TextStyles.bodyMain.copyWith(
                          fontSize: 13,
                          height: 1.25,
                          color: destructive
                              ? rowTextColor
                              : const Color(0xFF9A9A9A),
                        )
                      : TextStyles.bodyLarge.copyWith(
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
                NeutralTrackSwitch(
                  value: switchValue!,
                  onChanged: onSwitchChanged!,
                ),
              if (showChevron)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: compact ? 18 : 20,
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
