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
      borderRadius: BorderRadius.circular(6),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x33202020),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0x992B2B2C),
                width: 0.5,
              ),
            ),
            child: Column(
              children: visibleApps.map(
                (application) {
                  final normalizedStatus =
                      application.status.trim().toLowerCase();
                  final isAcceptedLike =
                      selectedApplicationId == application.id ||
                          normalizedStatus == 'accepted' ||
                          normalizedStatus == 'code_verified' ||
                          normalizedStatus == 'confirmed';

                  return Container(
                    constraints: const BoxConstraints(minHeight: 54),
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        _ResolvedApplicantAvatar(application: application),
                        const Gap(10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: _displayApplicantName(application),
                                  style: TextStyles.bodyMain.copyWith(
                                    color: const Color(0xFFCACACA),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                TextSpan(
                                  text: isAcceptedLike
                                      ? ' has arrived'
                                      : ' wants to help you',
                                  style: TextStyles.bodyMain.copyWith(
                                    color: const Color(0xFF9B9B9B),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Gap(8),
                        if (isAcceptedLike) ...[
                          const Icon(
                            Icons.chat_bubble_outline,
                            color: Color(0xFFD4D4D4),
                            size: 17,
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
                                size: 19,
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
                                size: 19,
                              ),
                            ),
                          ),
                          const Gap(10),
                          InkWell(
                            onTap: () => onAccept(application),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.check,
                                color: Color(0xFF22C55E),
                                size: 19,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ).toList(),
            ),
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

  String _displayApplicantName(MapTaskApplicationEntity application) {
    final username = application.applicantUsername.trim();
    if (username.isNotEmpty) {
      return username;
    }
    return _compactApplicant(application.applicantId);
  }
}

class _ResolvedApplicantAvatar extends StatelessWidget {
  const _ResolvedApplicantAvatar({required this.application});

  final MapTaskApplicationEntity application;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: MapAvatarResolverService.instance.resolveAvatar(
        fallbackUrl: application.applicantAvatarUrl,
        userId: application.applicantId,
        username: application.applicantUsername,
      ),
      builder: (context, snapshot) {
        final avatarUrl = snapshot.data?.trim() ?? '';
        return CircleAvatar(
          radius: 12,
          backgroundColor: const Color(0xFF2A3341),
          backgroundImage:
              avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
          child: avatarUrl.isNotEmpty
              ? null
              : const Icon(
                  Icons.person,
                  color: Colors.white70,
                  size: 14,
                ),
        );
      },
    );
  }
}
