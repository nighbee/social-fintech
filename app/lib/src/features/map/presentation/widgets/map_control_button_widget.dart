part of 'package:app/src/features/map/presentation/pages/map_page.dart';

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.onTap,
  });

  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Material(
          color: MapUiPalette.controlPanelBackground,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: MapUiPalette.controlPanelBorder),
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
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}
