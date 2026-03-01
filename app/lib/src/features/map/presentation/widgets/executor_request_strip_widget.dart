part of 'package:app/src/features/map/presentation/pages/map_page.dart';

class _ExecutorRequestStrip extends StatelessWidget {
  const _ExecutorRequestStrip({
    required this.message,
    required this.onClose,
  });

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF6D6D6D).withOpacity(0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF656565)),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
            ],
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
                  message,
                  style: TextStyles.bodyMain.copyWith(
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Gap(8),
              const Icon(
                Icons.chat_bubble_outline,
                color: Colors.white70,
                size: 16,
              ),
              const Gap(10),
              InkWell(
                onTap: onClose,
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
            ],
          ),
        ),
      ),
    );
  }
}
