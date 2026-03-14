import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/styled_message_dialog.dart';
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
  late String _selectedLabel;

  @override
  void initState() {
    super.initState();
    _selectedLabel = _resolveInitialSelection(widget.initialSelectionLabel);
  }

  String _resolveInitialSelection(String label) {
    if (_feedTimeLimitOptions.contains(label)) {
      return label;
    }
    return _feedTimeLimitOptions.first;
  }

  Future<void> _selectOption(String label) async {
    if (_selectedLabel == label) {
      return;
    }

    setState(() {
      _selectedLabel = label;
    });

    await showStyledMessageDialog<void>(
      context: context,
      message: 'Changes apply in 24 hours.',
    );
  }

  Future<bool> _handleWillPop() async {
    context.pop(_selectedLabel);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleWillPop,
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time limit',
                  style: TextStyles.bodyLarge.copyWith(
                    color: const Color(0xFFA3A3A3),
                    height: 1.4,
                  ),
                ),
                const Gap(12),
                _FeedTimeLimitOptionsCard(
                  selectedLabel: _selectedLabel,
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
    required this.onOptionTap,
  });

  final String selectedLabel;
  final ValueChanged<String> onOptionTap;

  @override
  Widget build(BuildContext context) {
    return SettingsOptionCard(
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
    );
  }
}
