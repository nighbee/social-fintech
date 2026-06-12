import 'dart:async';

import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/service/storage/app_storage/storage_service.dart';
import 'package:app/src/core/service/storage/key_store.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/styled_message_dialog.dart';
import 'package:app/src/features/profile/data/models/interaction_settings_dto.dart';
import 'package:app/src/features/profile/data/sources/remote/i_interaction_settings_remote.dart';
import 'package:app/src/features/profile/presentation/widgets/settings/settings_option_widgets.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

const List<String> _feedTimeLimitOptions = <String>[
  'No limit',
  '20 min',
  '40 min',
  '60 min',
];

class FeedTimeLimitPage extends StatefulWidget {
  const FeedTimeLimitPage({
    super.key,
    required this.initialSelectionLabel,
  });

  final String initialSelectionLabel;

  @override
  State<FeedTimeLimitPage> createState() => _FeedTimeLimitPageState();
}

class _FeedTimeLimitPageState extends State<FeedTimeLimitPage> {
  static const Duration _localChangeLockDuration = Duration(hours: 24);
  static const Duration _patchDebounce = Duration(milliseconds: 500);

  final IInteractionSettingsRemote _remote =
      getIt<IInteractionSettingsRemote>();

  bool _loading = true;
  bool _patching = false;
  late String _selectedLabel;
  DateTime? _localChangeLockedUntil;
  int _currentMins = 20;
  int? _pendingMins;
  DateTime? _pendingApplyAt;
  int? _requestedMins;
  Timer? _confirmationTimer;

  @override
  void initState() {
    super.initState();
    _selectedLabel = _resolveInitialSelection(widget.initialSelectionLabel);
    _load();
  }

  String _resolveInitialSelection(String label) {
    if (_feedTimeLimitOptions.contains(label)) {
      return label;
    }
    return _feedTimeLimitOptions.first;
  }

  Future<void> _load() async {
    await _loadLocalLock();
    setState(() => _loading = true);
    final result = await _remote.getFeedSettings();
    if (!mounted) return;
    await result.fold(
      (e) async {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      (dto) async {
        final now = DateTime.now().toUtc();
        final pendingApplyAt = dto.pendingApplyAt?.toUtc();
        if (pendingApplyAt != null && pendingApplyAt.isAfter(now)) {
          await _setLocalLock(lockUntilUtc: pendingApplyAt);
        }
        final confirmedMins = _requestedMins;
        final wasConfirmed = dto.pendingMins == null &&
            confirmedMins != null &&
            dto.currentMins == confirmedMins;

        setState(() {
          _loading = false;
          _currentMins = dto.currentMins;
          _pendingMins = dto.pendingMins;
          _pendingApplyAt = pendingApplyAt;
          _selectedLabel = feedTimeLimitLabelFromMins(
            dto.pendingMins ?? dto.currentMins,
          );
        });
        _scheduleConfirmationRefresh();

        if (dto.pendingMins == null) {
          await _clearLocalChangeTracking();
        }
        if (wasConfirmed && mounted) {
          await showStyledMessageDialog<void>(
            context: context,
            title: 'Feed time limit updated',
            message:
                '${feedTimeLimitLabelFromMins(dto.currentMins)} is now active.',
            barrierColor: Colors.black.withValues(alpha: 0.72),
          );
        }
      },
    );
  }

  Future<void> _loadLocalLock() async {
    await prefsInstance.initialize();
    final raw =
        prefsInstance.get<String>(KeyStore.feedTimeLimitChangeLockedUntil);
    final rawRequestedAt =
        prefsInstance.get<String>(KeyStore.feedTimeLimitChangeRequestedAt);
    _requestedMins =
        prefsInstance.get<int>(KeyStore.feedTimeLimitChangeRequestedMins);

    if ((raw == null || raw.isEmpty) &&
        rawRequestedAt != null &&
        rawRequestedAt.isNotEmpty) {
      final requestedAt = DateTime.tryParse(rawRequestedAt)?.toUtc();
      if (requestedAt != null) {
        final inferredLockUntil = requestedAt.add(_localChangeLockDuration);
        if (inferredLockUntil.isAfter(DateTime.now().toUtc())) {
          await _setLocalLock(
            lockUntilUtc: inferredLockUntil,
            requestedAtUtc: requestedAt,
          );
          return;
        }
      }
      await prefsInstance.remove(KeyStore.feedTimeLimitChangeRequestedAt);
    }

    if (raw == null || raw.isEmpty) {
      _localChangeLockedUntil = null;
      return;
    }

    final parsed = DateTime.tryParse(raw)?.toUtc();
    if (parsed == null || !parsed.isAfter(DateTime.now().toUtc())) {
      await prefsInstance.remove(KeyStore.feedTimeLimitChangeLockedUntil);
      _localChangeLockedUntil = null;
      return;
    }

    _localChangeLockedUntil = parsed;
  }

  Future<void> _setLocalLock({
    required DateTime lockUntilUtc,
    DateTime? requestedAtUtc,
  }) async {
    await prefsInstance.initialize();
    final requestedAt =
        requestedAtUtc ?? lockUntilUtc.subtract(_localChangeLockDuration);
    await prefsInstance.set<String>(
      KeyStore.feedTimeLimitChangeLockedUntil,
      lockUntilUtc.toIso8601String(),
    );
    await prefsInstance.set<String>(
      KeyStore.feedTimeLimitChangeRequestedAt,
      requestedAt.toIso8601String(),
    );
    _localChangeLockedUntil = lockUntilUtc;
  }

  Future<void> _clearLocalChangeTracking() async {
    await prefsInstance.remove(KeyStore.feedTimeLimitChangeLockedUntil);
    await prefsInstance.remove(KeyStore.feedTimeLimitChangeRequestedAt);
    await prefsInstance.remove(KeyStore.feedTimeLimitChangeRequestedMins);
    _localChangeLockedUntil = null;
    _requestedMins = null;
  }

  void _scheduleConfirmationRefresh() {
    _confirmationTimer?.cancel();
    if (_pendingMins == null) {
      return;
    }

    final now = DateTime.now().toUtc();
    final applyAt = _pendingApplyAt;
    final delay = applyAt != null && applyAt.isAfter(now)
        ? applyAt.difference(now) + const Duration(seconds: 2)
        : const Duration(minutes: 1);
    _confirmationTimer = Timer(delay, _load);
  }

  Duration _remainingLockDuration() {
    final lockUntil = _localChangeLockedUntil;
    if (lockUntil == null) {
      return Duration.zero;
    }
    final now = DateTime.now().toUtc();
    if (!lockUntil.isAfter(now)) {
      return Duration.zero;
    }
    return lockUntil.difference(now);
  }

  bool get _isChangeLocked =>
      _pendingMins != null || _remainingLockDuration() > Duration.zero;

  String _lockLabel(Duration remaining) {
    final totalMinutes = remaining.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  Future<void> _selectOption(String label) async {
    if (_patching || _loading) return;
    if (_selectedLabel == label) return;

    if (_isChangeLocked) {
      final remaining = _remainingLockDuration();
      final message = remaining > Duration.zero
          ? 'Your change is scheduled. It should apply in ${_lockLabel(remaining)}.'
          : 'Your change is waiting for server confirmation.';
      await showStyledMessageDialog<void>(
        context: context,
        message: message,
        barrierColor: Colors.black.withValues(alpha: 0.72),
      );
      return;
    }

    final previous = _selectedLabel;
    setState(() {
      _selectedLabel = label;
      _patching = true;
    });

    final newMins = feedTimeLimitMinsFromLabel(label);
    await Future<void>.delayed(_patchDebounce);
    final result = await _remote.patchFeedSettings(newMins);
    if (!mounted) return;

    result.fold(
      (e) {
        setState(() {
          _selectedLabel = previous;
          _patching = false;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      (_) async {
        final requestedAt = DateTime.now().toUtc();
        final lockUntil = DateTime.now().toUtc().add(_localChangeLockDuration);
        await prefsInstance.set<int>(
          KeyStore.feedTimeLimitChangeRequestedMins,
          newMins,
        );
        _requestedMins = newMins;
        await _setLocalLock(
          lockUntilUtc: lockUntil,
          requestedAtUtc: requestedAt,
        );
        await _load();
        if (!mounted) return;
        setState(() => _patching = false);
        await showStyledMessageDialog<void>(
          context: context,
          message:
              'Change scheduled. It becomes active only after server confirmation.',
          barrierColor: Colors.black.withValues(alpha: 0.72),
        );
      },
    );
  }

  @override
  void dispose() {
    _confirmationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.pop(feedTimeLimitLabelFromMins(_currentMins));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.colorff19191A,
        appBar: CustomAppBar(
          title: 'Feed time limit',
          backgroundColor: AppColors.colorff19191A,
          onLeadingTap: () =>
              context.pop(feedTimeLimitLabelFromMins(_currentMins)),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time limit',
                  style: TextStyles.bodyMain.copyWith(
                    color: AppColors.colorff838383,
                    fontSize: 13,
                    height: 20 / 13,
                  ),
                ),
                const Gap(24),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.colorff838383,
                      ),
                    ),
                  )
                else
                  _FeedTimeLimitOptionsCard(
                    selectedLabel: _selectedLabel,
                    enabled: !_patching && !_isChangeLocked,
                    onOptionTap: _selectOption,
                  ),
                if (!_loading && _isChangeLocked) ...[
                  const Gap(14),
                  Text(
                    _pendingStatusLabel(),
                    style: TextStyles.bodyMain.copyWith(
                      color: AppColors.colorff838383,
                      fontSize: 13,
                      height: 20 / 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _pendingStatusLabel() {
    final pendingMins = _pendingMins;
    if (pendingMins == null) {
      return 'Current limit: ${feedTimeLimitLabelFromMins(_currentMins)}.';
    }

    final applyAt = _pendingApplyAt;
    final now = DateTime.now().toUtc();
    final pendingLabel = feedTimeLimitLabelFromMins(pendingMins);
    final currentLabel = feedTimeLimitLabelFromMins(_currentMins);
    if (applyAt != null && applyAt.isAfter(now)) {
      return 'Current: $currentLabel. $pendingLabel is scheduled in '
          '${_lockLabel(applyAt.difference(now))}.';
    }
    return 'Current: $currentLabel. Waiting for server confirmation that '
        '$pendingLabel is active.';
  }
}

class _FeedTimeLimitOptionsCard extends StatelessWidget {
  const _FeedTimeLimitOptionsCard({
    required this.selectedLabel,
    required this.enabled,
    required this.onOptionTap,
  });

  final String selectedLabel;
  final bool enabled;
  final ValueChanged<String> onOptionTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: AbsorbPointer(
        absorbing: !enabled,
        child: SettingsOptionCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            children: [
              for (final option in _feedTimeLimitOptions)
                SettingsOptionRow(
                  label: option,
                  isSelected: option == selectedLabel,
                  onTap: () => onOptionTap(option),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
