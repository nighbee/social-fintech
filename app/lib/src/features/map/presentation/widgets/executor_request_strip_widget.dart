part of 'package:app/src/features/map/presentation/pages/map_page.dart';

class _ExecutorRequestStrip extends StatelessWidget {
  const _ExecutorRequestStrip({
    required this.message,
    required this.creatorName,
    required this.avatarUrl,
    required this.onCloseTap,
  });

  final String message;
  final String creatorName;
  final String avatarUrl;
  final VoidCallback onCloseTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF202020).withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              FutureBuilder<String>(
                future: MapAvatarResolverService.instance.resolveAvatar(
                  fallbackUrl: avatarUrl,
                  username: creatorName,
                ),
                builder: (context, snapshot) {
                  final resolvedUrl = snapshot.data?.trim() ?? '';
                  return CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFF2A3341),
                    backgroundImage:
                        resolvedUrl.isNotEmpty ? NetworkImage(resolvedUrl) : null,
                    child: resolvedUrl.isNotEmpty
                        ? null
                        : const Icon(
                            Icons.person,
                            color: Colors.white70,
                            size: 14,
                          ),
                  );
                },
              ),
              const Gap(14),
              Expanded(
                child: Text(
                  message,
                  style: TextStyles.titleMain.copyWith(
                    color: const Color(0xFFCECECE),
                    fontSize: 16,
                    height: 1.1,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Gap(10),
              const Icon(
                Icons.chat_bubble_outline,
                color: Color(0xFFD4D4D4),
                size: 19,
              ),
              const Gap(14),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onCloseTap,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    color: Color(0xFFEF4444),
                    size: 21,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
