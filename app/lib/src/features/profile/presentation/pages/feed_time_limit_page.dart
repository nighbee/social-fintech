import 'package:app/src/core/service/injectable/injectable_service.dart';
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
  '30 min',
  '40 min',
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
  final IInteractionSettingsRemote _remote =
      getIt<IInteractionSettingsRemote>();

  bool _loading = true;
  bool _patching = false;
  late String _selectedLabel;

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
    setState(() => _loading = true);
    final result = await _remote.getFeedSettings();
    if (!mounted) return;
    result.fold(
      (e) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      (dto) {
        setState(() {
          _loading = false;
          _selectedLabel =
              feedTimeLimitLabelFromMins(effectiveFeedLimitMins(dto));
        });
      },
    );
  }

  Future<void> _selectOption(String label) async {
    if (_patching || _loading) return;
    if (_selectedLabel == label) return;

    final previous = _selectedLabel;
    setState(() {
      _selectedLabel = label;
      _patching = true;
    });

    final newMins = feedTimeLimitMinsFromLabel(label);
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
        setState(() => _patching = false);
        if (!mounted) return;
        await showStyledMessageDialog<void>(
          context: context,
          message: 'Changes apply in 24 hours.',
          barrierColor: Colors.black.withValues(alpha: 0.72),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.pop(_selectedLabel);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.colorff19191A,
        appBar: CustomAppBar(
          title: 'Feed time limit',
          backgroundColor: AppColors.colorff19191A,
          onLeadingTap: () => context.pop(_selectedLabel),
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
                    enabled: !_patching,
                    onOptionTap: _selectOption,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
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
