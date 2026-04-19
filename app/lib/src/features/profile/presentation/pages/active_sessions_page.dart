import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/features/profile/presentation/widgets/settings/settings_option_widgets.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ActiveSessionsPage extends StatelessWidget {
  const ActiveSessionsPage({
    super.key,
    required this.sessions,
  });

  final List<Map<String, dynamic>> sessions;

  @override
  Widget build(BuildContext context) {
    final currentSessions = sessions
        .map(_ActiveSessionItem.fromMap)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      appBar: const CustomAppBar(
        title: 'Active sessions',
        backgroundColor: AppColors.colorff19191A,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Current device',
                style: TextStyles.bodyMain.copyWith(
                  color: AppColors.colorff838383,
                  fontSize: 13,
                  height: 20 / 13,
                ),
              ),
              const Gap(12),
              if (currentSessions.isEmpty)
                Text(
                  'No active sessions.',
                  style: TextStyles.bodyLarge.copyWith(
                    color: AppColors.colorff838383,
                    height: 1.4,
                  ),
                )
              else
                for (var index = 0; index < currentSessions.length; index++) ...[
                  if (index > 0) const Gap(12),
                  SettingsOptionCard(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                    child: _ActiveSessionCard(item: currentSessions[index]),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({
    required this.item,
  });

  final _ActiveSessionItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.deviceName,
          style: TextStyles.bodyLarge.copyWith(
            color: AppColors.textBrand,
            height: 1.35,
          ),
        ),
        const Gap(4),
        Text(
          item.details,
          style: TextStyles.bodyMain.copyWith(
            fontSize: 12,
            height: 16 / 12,
            color: AppColors.colorff838383,
          ),
        ),
      ],
    );
  }
}

class _ActiveSessionItem {
  const _ActiveSessionItem({
    required this.deviceName,
    required this.details,
  });

  factory _ActiveSessionItem.fromMap(Map<String, dynamic> map) {
    return _ActiveSessionItem(
      deviceName: map['deviceName'] as String? ?? 'Unknown device',
      details: map['details'] as String? ?? '',
    );
  }

  final String deviceName;
  final String details;
}
