part of '../../pages/allies_page.dart';

class _Avatar extends StatelessWidget {
  const _Avatar({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: imageUrl.trim().isEmpty
          ? Container(
              width: 48,
              height: 48,
              color: const Color(0xFF232324),
              alignment: Alignment.center,
              child: const Icon(
                Icons.person,
                color: Color(0xFF6D6D6D),
                size: 22,
              ),
            )
          : Image.network(
              imageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 48,
                  height: 48,
                  color: const Color(0xFF232324),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF6D6D6D),
                    size: 22,
                  ),
                );
              },
            ),
    );
  }
}
