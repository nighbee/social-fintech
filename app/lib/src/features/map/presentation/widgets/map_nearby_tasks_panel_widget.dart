part of 'package:app/src/features/map/presentation/pages/map_page.dart';

class _MyRequestPanel extends StatelessWidget {
  const _MyRequestPanel({
    required this.task,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onCancel,
  });

  final MapTaskEntity task;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final code = _extractVerificationCode(task.status);
    final requiredText =
        'Required: ${task.workersNeeded} heroes  |  Reward: ${task.reward.toStringAsFixed(0)}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: MapUiPalette.panelBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MapUiPalette.panelBorder),
            boxShadow: [
              BoxShadow(
                color: MapUiPalette.panelTopGlow,
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
              BoxShadow(
                color: MapUiPalette.panelDropShadow,
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: onToggleExpanded,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 15,
                        backgroundColor: Color(0xFF2A3341),
                        child:
                            Icon(Icons.person, color: Colors.white70, size: 16),
                      ),
                      const Gap(10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyles.bodyLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Code:$code',
                              style: TextStyles.bodyMain.copyWith(
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        isExpanded ? 'hide' : 'view my request',
                        style:
                            TextStyles.bodyMain.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.description.isEmpty
                            ? 'No description provided.'
                            : task.description,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyles.bodyMain.copyWith(
                          color: Colors.white70,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        requiredText,
                        style: TextStyles.bodyMain.copyWith(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: InkWell(
                          onTap: onCancel,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xAAE14D4D),
                              ),
                            ),
                            child: Text(
                              'Cancel my request',
                              style: TextStyles.bodyMain.copyWith(
                                color: const Color(0xFFE26D6D),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _extractVerificationCode(String status) {
    if (!status.startsWith('mine|')) {
      return '----';
    }
    final raw = status.substring(5).trim();
    final code = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (code.length >= 4) {
      return code.substring(0, 4);
    }
    if (code.isNotEmpty) {
      return code.padRight(4, '-');
    }
    return '----';
  }
}

class _NearbyTasksPanel extends StatelessWidget {
  const _NearbyTasksPanel({
    required this.tasks,
    required this.onApply,
  });

  final List<MapTaskEntity> tasks;
  final ValueChanged<String> onApply;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final task = tasks.first;
    final hasDescription = task.description.trim().isNotEmpty;
    final description = hasDescription
        ? task.description
        : 'No description provided for this request.';

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 410),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x33202020),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: MapUiPalette.panelBorder),
            boxShadow: [
              BoxShadow(
                color: MapUiPalette.panelTopGlow,
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
              BoxShadow(
                color: MapUiPalette.panelDropShadow,
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF2A3341),
                      backgroundImage: Assets.images.image.provider(),
                    ),
                    const Gap(10),
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyles.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyles.bodyMain.copyWith(
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Required: ${task.workersNeeded} heroes',
                        style: TextStyles.bodyMain.copyWith(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Assets.icons.silverCoin.svg(width: 18, height: 18),
                    const SizedBox(width: 4),
                    Text(
                      task.reward.toStringAsFixed(0),
                      style: TextStyles.bodyMain.copyWith(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: InkWell(
                    onTap: () => onApply(task.id),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5E5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'I can help',
                        style: TextStyles.bodyMain.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
