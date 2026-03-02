part of 'package:app/src/features/map/presentation/pages/map_page.dart';

class _MapZoomControlGroup extends StatelessWidget {
  const _MapZoomControlGroup({
    required this.onTapPlus,
    required this.onTapMinus,
  });

  final VoidCallback onTapPlus;
  final VoidCallback onTapMinus;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 42,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapZoomHalfButton(
                onTap: onTapPlus,
                icon: Assets.icons.plusIcon.svg(
                  width: 28,
                  height: 28,
                  colorFilter: const ColorFilter.mode(
                    Color.fromARGB(255, 189, 188, 188),
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFF656565)),
              _MapZoomHalfButton(
                onTap: onTapMinus,
                icon: Container(
                  width: 28,
                  height: 1,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 189, 188, 188),
                    borderRadius: BorderRadius.circular(2),
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
