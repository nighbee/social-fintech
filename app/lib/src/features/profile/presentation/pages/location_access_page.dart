import 'package:app/gen/fonts.gen.dart';
import 'package:app/src/core/service/storage/app_storage/storage_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/features/profile/data/local/location_access_prefs.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// База Figma: Lora 18 / 400, `rgba(202,202,202,1)` — чуть больше воздуха, чем 21px, чтобы не «сжимало»
const Color _kLocationOptionTextColor = Color(0xFFCACACA);

const TextStyle _kLocationOptionTextStyle = TextStyle(
  fontFamily: FontFamily.lora,
  fontSize: 18,
  fontWeight: FontWeight.w400,
  height: 24 / 18,
  letterSpacing: 0.2,
  color: _kLocationOptionTextColor,
);

/// Подписи и пояснения — sans (системный), не Lora
const TextStyle _kSectionLabelStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w400,
  height: 20 / 13,
  color: Color(0xFFA3A3A3),
);

const TextStyle _kHelperSansStyle = TextStyle(
  fontSize: 12,
  height: 1.45,
  letterSpacing: 0.15,
  color: Color(0xFFA3A3A3),
);

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
  bool _loading = true;
  bool _saving = false;
  late String _selectedLabel;
  late bool _isPreciseLocationEnabled;

  @override
  void initState() {
    super.initState();
    _selectedLabel = kLocationAccessOptionLabels
            .contains(widget.initialSelectionLabel)
        ? widget.initialSelectionLabel
        : kLocationAccessOptionLabels.first;
    _isPreciseLocationEnabled = widget.initialPreciseLocationEnabled;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await prefsInstance.initialize();
    if (!mounted) return;
    final loaded = readLocationAccessPrefs(
      initialLabel: widget.initialSelectionLabel,
      initialPrecise: widget.initialPreciseLocationEnabled,
    );
    setState(() {
      _loading = false;
      _selectedLabel = loaded.label;
      _isPreciseLocationEnabled = loaded.precise;
    });
  }

  Map<String, dynamic> _buildResult() {
    return <String, dynamic>{
      'selectedLabel': _selectedLabel,
      'isPreciseLocationEnabled': _isPreciseLocationEnabled,
    };
  }

  bool get _showsPreciseLocationSection => _selectedLabel != 'Never';

  Future<void> _selectOption(String label) async {
    if (_saving || _loading) return;
    if (_selectedLabel == label) return;

    final previousLabel = _selectedLabel;
    final previousPrecise = _isPreciseLocationEnabled;
    final newPrecise = label == 'Never' ? false : _isPreciseLocationEnabled;

    setState(() {
      _selectedLabel = label;
      _isPreciseLocationEnabled = newPrecise;
      _saving = true;
    });

    try {
      await prefsInstance.initialize();
      await writeLocationAccessPrefs(
        label: label,
        precise: newPrecise,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _selectedLabel = previousLabel;
        _isPreciseLocationEnabled = previousPrecise;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _onPreciseChanged(bool value) async {
    if (_saving || _loading) return;
    final previous = _isPreciseLocationEnabled;
    setState(() {
      _isPreciseLocationEnabled = value;
      _saving = true;
    });

    try {
      await prefsInstance.initialize();
      await writeLocationAccessPrefs(
        label: _selectedLabel,
        precise: value,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPreciseLocationEnabled = previous);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.pop(_buildResult());
        }
      },
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Allow location access',
                      style: _kSectionLabelStyle,
                    ),
                    const Gap(12),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.colorff838383,
                          ),
                        ),
                      )
                    else
                      Opacity(
                        opacity: _saving ? 0.55 : 1,
                        child: AbsorbPointer(
                          absorbing: _saving,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _LocationAccessOptionsCard(
                                selectedLabel: _selectedLabel,
                                onOptionTap: _selectOption,
                              ),
                              const Gap(16),
                              const Text(
                                'Your exact location is never shared with other users. The map shows only your region (district/city/country), and leaderboard markers are placed at region centers.',
                                style: _kHelperSansStyle,
                              ),
                              if (_showsPreciseLocationSection) ...[
                                const Gap(20),
                                _PreciseLocationCard(
                                  value: _isPreciseLocationEnabled,
                                  onChanged: _onPreciseChanged,
                                ),
                                const Gap(12),
                                const Text(
                                  'Precise location improves region detection on your device. Other users still cannot see your exact point.',
                                  style: _kHelperSansStyle,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma: padding T16 R12 B10 L12, gap 12, radius 6 (контейнер до ~238px по макету — высота от контента)
class _LocationAccessOptionsCard extends StatelessWidget {
  const _LocationAccessOptionsCard({
    required this.selectedLabel,
    required this.onOptionTap,
  });

  final String selectedLabel;
  final ValueChanged<String> onOptionTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.colorff202020,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < kLocationAccessOptionLabels.length; i++) ...[
            if (i > 0) const Gap(14),
            _LocationAccessOptionRow(
              label: kLocationAccessOptionLabels[i],
              isSelected: kLocationAccessOptionLabels[i] == selectedLabel,
              onTap: () => onOptionTap(kLocationAccessOptionLabels[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationAccessOptionRow extends StatelessWidget {
  const _LocationAccessOptionRow({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: _kLocationOptionTextStyle,
                ),
              ),
              const Gap(8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  width: 22,
                  height: 24,
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreciseLocationCard extends StatelessWidget {
  const _PreciseLocationCard({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.colorff202020,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              'Precise location',
              style: _kLocationOptionTextStyle,
            ),
          ),
          _LocationPreciseSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _LocationPreciseSwitch extends StatelessWidget {
  const _LocationPreciseSwitch({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  static const Color _trackOff = Color(0xFF39393D);
  static const Color _trackOn = Color(0xFFC2C1C1);

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.9,
      alignment: Alignment.centerRight,
      child: CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: _trackOn,
        inactiveTrackColor: _trackOff,
        thumbColor: Colors.white,
      ),
    );
  }
}
