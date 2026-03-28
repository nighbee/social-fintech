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
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 44,
          decoration: BoxDecoration(
            color: MapUiPalette.controlPanelBackground,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapZoomHalfButton(
                onTap: onTapPlus,
                icon: Assets.icons.plusIcon.svg(
                  width: 28,
                  height: 28,
                  colorFilter:
                      const ColorFilter.mode(MapUiPalette.controlIcon, BlendMode.srcIn),
                ),
              ),
              const Divider(height: 1, thickness: 1, color: MapUiPalette.controlPanelBorder),
              _MapZoomHalfButton(
                onTap: onTapMinus,
                icon: Container(
                  width: 28,
                  height: 1,
                  decoration: BoxDecoration(
                    color: MapUiPalette.controlIcon,
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
