part of 'package:app/src/features/map/presentation/pages/map_page.dart';

class _MapZoomHalfButton extends StatelessWidget {
  const _MapZoomHalfButton({
    required this.onTap,
    required this.icon,
  });

  final VoidCallback onTap;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,


        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(child: icon),
        ),
      ),
    );
  }
}
