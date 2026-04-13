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
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
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
                  border: Border.all(
                    color: MapUiPalette.controlPanelBorder,
                    width: 0.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: MapUiPalette.panelDropShadow,
                      blurRadius: 4,
                      spreadRadius: 0,
                      offset: Offset(0, 0),
                    ),
                  ],
                ),
                child: Center(child: icon),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
