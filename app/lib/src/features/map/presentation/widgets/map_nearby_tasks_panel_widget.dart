part of 'package:app/src/features/map/presentation/pages/map_page.dart';

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

    final visibleTasks = tasks.length > 2 ? tasks.take(2).toList() : tasks;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: visibleTasks
            .map(
              (task) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: Colors.white70,
                      size: 15,
                    ),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyles.bodyMain.copyWith(color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      task.reward.toString(),
                      style: TextStyles.bodyMain.copyWith(color: Colors.white54),
                    ),
                    const Gap(8),
                    InkWell(
                      onTap: () => onApply(task.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'I can help',
                          style: TextStyles.bodyMain.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
