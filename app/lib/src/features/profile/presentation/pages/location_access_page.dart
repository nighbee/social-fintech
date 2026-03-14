import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/features/profile/presentation/widgets/settings/settings_option_widgets.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

const List<String> _locationAccessOptions = <String>[
  'Never',
  'Ask next time or when i share',
  'While using the app',
  'Always',
];

class LocationAccessPage extends StatefulWidget {
  const LocationAccessPage({
    super.key,
    required this.initialSelectionLabel,
    required this.initialPreciseLocationEnabled,
  });

  final String initialSelectionLabel;
  final bool initialPreciseLocationEnabled;

  @override
  State<LocationAccessPage> createState() => _LocationAccessPageState();
}

class _LocationAccessPageState extends State<LocationAccessPage> {
  late String _selectedLabel;
  late bool _isPreciseLocationEnabled;

  @override
  void initState() {
    super.initState();
    _selectedLabel = _resolveInitialSelection(widget.initialSelectionLabel);
    _isPreciseLocationEnabled = widget.initialPreciseLocationEnabled;
  }

  String _resolveInitialSelection(String label) {
    if (_locationAccessOptions.contains(label)) {
      return label;
    }
    return _locationAccessOptions.first;
  }

  Map<String, dynamic> _buildResult() {
    return <String, dynamic>{
      'selectedLabel': _selectedLabel,
      'isPreciseLocationEnabled': _isPreciseLocationEnabled,
    };
  }

  bool get _showsPreciseLocationSection => _selectedLabel != 'Never';

  Future<bool> _handleWillPop() async {
    context.pop(_buildResult());
    return false;
  }

  void _selectOption(String label) {
    if (_selectedLabel == label) {
      return;
    }

    setState(() {
      _selectedLabel = label;
      if (!_showsPreciseLocationSection) {
        _isPreciseLocationEnabled = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        backgroundColor: AppColors.colorff19191A,
        appBar: CustomAppBar(
          title: 'Location access',
          backgroundColor: AppColors.colorff19191A,
          onLeadingTap: () => context.pop(_buildResult()),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allow location access',
                  style: TextStyles.bodyLarge.copyWith(
                    color: const Color(0xFFA3A3A3),
                    height: 1.4,
                  ),
                ),
                const Gap(12),
                _LocationAccessOptionsCard(
                  selectedLabel: _selectedLabel,
                  onOptionTap: _selectOption,
                ),
                const Gap(16),
                const SettingsHelperText(
                  text:
                      'App explanation: "Geolocation will be only visible to allies you have added to the map. You can disable it at any time in the application settings"',
                ),
                if (_showsPreciseLocationSection) ...[
                  const Gap(20),
                  SettingsSwitchCard(
                    title: 'Precise location',
                    value: _isPreciseLocationEnabled,
                    onChanged: (value) {
                      setState(() {
                        _isPreciseLocationEnabled = value;
                      });
                    },
                  ),
                  const Gap(12),
                  const SettingsHelperText(
                    text:
                        'Allows app to use your specific location. With this setting off, app can only determine your approximate location.',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationAccessOptionsCard extends StatelessWidget {
  const _LocationAccessOptionsCard({
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
          for (final option in _locationAccessOptions)
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
