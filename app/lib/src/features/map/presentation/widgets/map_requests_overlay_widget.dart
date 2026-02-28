part of 'package:app/src/features/map/presentation/pages/map_page.dart';

class _RequestsOverlay extends StatelessWidget {
  const _RequestsOverlay({
    required this.applications,
  });

  final List<MapTaskApplicationEntity> applications;

  @override
  Widget build(BuildContext context) {
    if (applications.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: applications
            .map(
              (application) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 11,
                      backgroundColor: Color(0xFF2A3341),
                      child: Icon(
                        Icons.person,
                        color: Colors.white70,
                        size: 14,
                      ),
                    ),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        '${application.applicantId} wants to help you',
                        style: TextStyles.bodyMain.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    if (application.status == 'pending')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Code: ${application.id ?? "Wait"}',
                          style: TextStyles.bodyMain.copyWith(
                            color: Colors.white70,
                            fontSize: 12,
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
