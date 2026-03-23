part of 'package:app/src/features/map/presentation/pages/map_page.dart';

class _RequestsOverlay extends StatelessWidget {
  const _RequestsOverlay({
    required this.applications,
    required this.selectedApplicationId,
    required this.onAccept,
    required this.onReject,
  });

  final List<MapTaskApplicationEntity> applications;
  final String? selectedApplicationId;
  final ValueChanged<MapTaskApplicationEntity> onAccept;
  final ValueChanged<MapTaskApplicationEntity> onReject;

  @override
  Widget build(BuildContext context) {
    if (applications.isEmpty) {
      return const SizedBox.shrink();
    }

    MapTaskApplicationEntity? selected;
    if (selectedApplicationId != null) {
      for (final app in applications) {
        if (app.id == selectedApplicationId) {
          selected = app;
          break;
        }
      }
    }
    final visibleApps =
        selected == null ? applications : <MapTaskApplicationEntity>[selected];

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF6D6D6D).withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF656565)),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: visibleApps
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
                            selectedApplicationId == application.id
                                ? '${_compactApplicant(application.applicantId)} has arrived'
                                : '${_compactApplicant(application.applicantId)} wants to help you',
                            style: TextStyles.bodyMain.copyWith(
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Gap(8),
                        if (selectedApplicationId == application.id) ...[
                          const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const Gap(10),
                          InkWell(
                            onTap: () => onReject(application),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.close,
                                color: Color(0xFFEF4444),
                                size: 18,
                              ),
                            ),
                          ),
                        ] else ...[
                          InkWell(
                            onTap: () => onReject(application),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.close,
                                color: Color(0xFFEF4444),
                                size: 18,
                              ),
                            ),
                          ),
                          const Gap(8),
                          InkWell(
                            onTap: () => onAccept(application),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.check,
                                color: Color(0xFF22C55E),
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  String _compactApplicant(String applicantId) {
    if (applicantId.trim().isEmpty) {
      return 'User';
    }

    final trimmed = applicantId.trim();
    if (trimmed.length <= 18) {
      return trimmed;
    }
    return trimmed.substring(0, 18);
  }
}
