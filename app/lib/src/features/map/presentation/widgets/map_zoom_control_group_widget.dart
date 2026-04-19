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
      borderRadius: BorderRadius.circular(6),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 44,
            decoration: BoxDecoration(
              color: MapUiPalette.controlPanelBackground,
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapZoomHalfButton(
                  onTap: onTapPlus,
                  icon: SizedBox(
                    width: 20,
                    height: 20,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 18,
                          height: 2,
                          decoration: BoxDecoration(
                            color: MapUiPalette.controlIcon,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 18,
                          decoration: BoxDecoration(
                            color: MapUiPalette.controlIcon,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: MapUiPalette.controlPanelBorder),
                _MapZoomHalfButton(
                  onTap: onTapMinus,
                  icon: Transform.translate(
                    offset: const Offset(0, -0.5),
                    child: Container(
                      width: 18,
                      height: 2,
                      decoration: BoxDecoration(
                        color: MapUiPalette.controlIcon,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
