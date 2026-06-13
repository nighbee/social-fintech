import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/neutral_track_switch.dart';
import 'package:app/src/features/home/domain/repositories/i_home_repository.dart';
import 'package:app/src/features/profile/data/models/interaction_settings_dto.dart';
import 'package:app/src/features/profile/data/sources/remote/i_interaction_settings_remote.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum _NotificationPreference {
  goldHonor,
  medal,
  rank,
  tasks,
  comments,
  likes,
}

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final IInteractionSettingsRemote _remote =
      getIt<IInteractionSettingsRemote>();
  final IHomeRepository _homeRepository =
      getIt<IHomeRepository>(instanceName: 'HomeRepositoryImpl');

  NotificationSettingsDto? _settings;
  bool _isLoading = true;
  String? _errorMessage;
  final Set<_NotificationPreference> _updating = {};
  bool _isUpdatingQuietHours = false;
  bool _isMarkingAllRead = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _remote.getNotificationSettings();
    if (!mounted) return;
    result.fold(
      (error) {
        setState(() {
          _isLoading = false;
          _errorMessage = error.message;
        });
      },
      (settings) {
        setState(() {
          _isLoading = false;
          _settings = settings;
        });
      },
    );
  }

  NotificationSettingsDto _copyWithPreference(
    NotificationSettingsDto settings,
    _NotificationPreference preference,
    bool value,
  ) {
    return NotificationSettingsDto(
      notifyGoldHonor: preference == _NotificationPreference.goldHonor
          ? value
          : settings.notifyGoldHonor,
      notifyMedalUnlocked: preference == _NotificationPreference.medal
          ? value
          : settings.notifyMedalUnlocked,
      notifyRankIncreased: preference == _NotificationPreference.rank
          ? value
          : settings.notifyRankIncreased,
      notifyTaskUpdates: preference == _NotificationPreference.tasks
          ? value
          : settings.notifyTaskUpdates,
      notifyCommentsReplies: preference == _NotificationPreference.comments
          ? value
          : settings.notifyCommentsReplies,
      notifyLikesReactions: preference == _NotificationPreference.likes
          ? value
          : settings.notifyLikesReactions,
      quietHoursStart: settings.quietHoursStart,
      quietHoursEnd: settings.quietHoursEnd,
    );
  }

  Future<void> _updatePreference(
    _NotificationPreference preference,
    bool value,
  ) async {
    final previous = _settings;
    if (previous == null || _updating.contains(preference)) return;

    setState(() {
      _settings = _copyWithPreference(previous, preference, value);
      _updating.add(preference);
    });

    final result = await _remote.patchNotificationSettings(
      notifyGoldHonor:
          preference == _NotificationPreference.goldHonor ? value : null,
      notifyMedal: preference == _NotificationPreference.medal ? value : null,
      notifyRank: preference == _NotificationPreference.rank ? value : null,
      notifyTasks: preference == _NotificationPreference.tasks ? value : null,
      notifyComments:
          preference == _NotificationPreference.comments ? value : null,
      notifyLikes: preference == _NotificationPreference.likes ? value : null,
    );
    if (!mounted) return;

    result.fold(
      (error) {
        setState(() {
          _settings = previous;
          _updating.remove(preference);
        });
        _showError(error.message);
      },
      (_) {
        setState(() {
          _updating.remove(preference);
        });
      },
    );
  }

  Future<void> _selectQuietHours() async {
    if (_isUpdatingQuietHours) return;
    final settings = _settings;
    if (settings == null) return;

    final start = await _showDarkTimePicker(
      initialTime: _parseTime(settings.quietHoursStart) ??
          const TimeOfDay(hour: 22, minute: 0),
      helpText: 'Do not disturb starts',
    );
    if (start == null || !mounted) return;

    final end = await _showDarkTimePicker(
      initialTime: _parseTime(settings.quietHoursEnd) ??
          const TimeOfDay(hour: 7, minute: 0),
      helpText: 'Do not disturb ends',
    );
    if (end == null || !mounted) return;

    final startValue = _timeToApi(start);
    final endValue = _timeToApi(end);
    setState(() {
      _isUpdatingQuietHours = true;
    });
    final result = await _remote.patchNotificationSettings(
      quietHoursStart: startValue,
      quietHoursEnd: endValue,
    );
    if (!mounted) return;
    result.fold(
      (error) {
        setState(() {
          _isUpdatingQuietHours = false;
        });
        _showError(error.message);
      },
      (_) {
        setState(() {
          _isUpdatingQuietHours = false;
          _settings = NotificationSettingsDto(
            notifyGoldHonor: settings.notifyGoldHonor,
            notifyMedalUnlocked: settings.notifyMedalUnlocked,
            notifyRankIncreased: settings.notifyRankIncreased,
            notifyTaskUpdates: settings.notifyTaskUpdates,
            notifyCommentsReplies: settings.notifyCommentsReplies,
            notifyLikesReactions: settings.notifyLikesReactions,
            quietHoursStart: startValue,
            quietHoursEnd: endValue,
          );
        });
      },
    );
  }

  Future<void> _markAllAsRead() async {
    if (_isMarkingAllRead) return;
    setState(() {
      _isMarkingAllRead = true;
    });
    final result = await _homeRepository.markAllNotificationsRead();
    if (!mounted) return;
    result.fold(
      (error) {
        setState(() {
          _isMarkingAllRead = false;
        });
        _showError(error.message);
      },
      (_) {
        setState(() {
          _isMarkingAllRead = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      },
    );
  }

  Future<TimeOfDay?> _showDarkTimePicker({
    required TimeOfDay initialTime,
    required String helpText,
  }) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: helpText,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.textBrand,
              surface: Color(0xFF202020),
              onSurface: AppColors.textBrand,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _timeToApi(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  String? _quietHoursLabel(NotificationSettingsDto settings) {
    final start = _parseTime(settings.quietHoursStart);
    final end = _parseTime(settings.quietHoursEnd);
    if (start == null || end == null) return null;
    return '${_timeToApi(start)} - ${_timeToApi(end)}';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SafeArea(
        child: Column(
          children: [
            _NotificationSettingsHeader(onBack: () => context.pop()),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.textBrand),
      );
    }
    if (_errorMessage != null || _settings == null) {
      return Center(
        child: TextButton(
          onPressed: _loadSettings,
          child: Text(
            'Failed to load settings. Tap to retry',
            style: TextStyles.bodyLarge.copyWith(color: AppColors.textBrand),
          ),
        ),
      );
    }

    final settings = _settings!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      children: [
        const _SectionTitle('Push Notifications'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.colorff202020,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              _PreferenceRow(
                label: 'Gold Honor received',
                value: settings.notifyGoldHonor,
                onChanged: (value) => _updatePreference(
                  _NotificationPreference.goldHonor,
                  value,
                ),
              ),
              _PreferenceRow(
                label: 'Medal unlocked',
                value: settings.notifyMedalUnlocked,
                onChanged: (value) => _updatePreference(
                  _NotificationPreference.medal,
                  value,
                ),
              ),
              _PreferenceRow(
                label: 'Rank increased',
                value: settings.notifyRankIncreased,
                onChanged: (value) => _updatePreference(
                  _NotificationPreference.rank,
                  value,
                ),
              ),
              _PreferenceRow(
                label: 'Task updates',
                value: settings.notifyTaskUpdates,
                onChanged: (value) => _updatePreference(
                  _NotificationPreference.tasks,
                  value,
                ),
              ),
              _PreferenceRow(
                label: 'Comments & Replies',
                value: settings.notifyCommentsReplies,
                onChanged: (value) => _updatePreference(
                  _NotificationPreference.comments,
                  value,
                ),
              ),
              _PreferenceRow(
                label: 'Likes & Reactions',
                value: settings.notifyLikesReactions,
                onChanged: (value) => _updatePreference(
                  _NotificationPreference.likes,
                  value,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const _SectionTitle('Quiet Hours'),
        const SizedBox(height: 12),
        Material(
          color: AppColors.colorff202020,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: _selectQuietHours,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Do not disturb',
                          style: TextStyles.bodyLarge.copyWith(
                            color: AppColors.textBrand,
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                        if (_quietHoursLabel(settings) case final label?)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              label,
                              style: TextStyles.bodyLarge.copyWith(
                                color: AppColors.textGray2,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_isUpdatingQuietHours)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textGray2,
                      ),
                    )
                  else
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textGray2,
                      size: 28,
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        const _SectionTitle('Notification Center'),
        const SizedBox(height: 12),
        Material(
          color: AppColors.colorff202020,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: _isMarkingAllRead ? null : _markAllAsRead,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Mark all as read',
                      style: TextStyles.bodyLarge.copyWith(
                        color: AppColors.textBrand,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (_isMarkingAllRead)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textGray2,
                      ),
                    )
                  else
                    const Icon(
                      Icons.done_all_rounded,
                      color: AppColors.textGray2,
                      size: 22,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationSettingsHeader extends StatelessWidget {
  const _NotificationSettingsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          const SizedBox(width: 8),
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textBrand,
              size: 20,
            ),
          ),
          Expanded(
            child: Text(
              'Notifications setting',
              textAlign: TextAlign.center,
              style: TextStyles.titleHeadline.copyWith(
                color: AppColors.textBrand,
                fontSize: 22,
                fontWeight: FontWeight.w500,
                height: 1.1,
                letterSpacing: -0.44,
              ),
            ),
          ),
          const SizedBox(width: 56),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyles.bodyLarge.copyWith(
        color: AppColors.textGray2,
        fontSize: 16,
        height: 1.4,
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyles.bodyLarge.copyWith(
                color: AppColors.textBrand,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
          NeutralTrackSwitch(
            value: value,
            onChanged: onChanged,
            scale: 0.82,
          ),
        ],
      ),
    );
  }
}
