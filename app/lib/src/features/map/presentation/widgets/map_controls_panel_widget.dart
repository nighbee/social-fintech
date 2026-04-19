part of 'package:app/src/features/map/presentation/pages/map_page.dart';

class _MapControlsPanel extends StatelessWidget {
  const _MapControlsPanel({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onCurrentLocation,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onCurrentLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MapZoomControlGroup(
          onTapPlus: onZoomIn,
          onTapMinus: onZoomOut,
        ),
        const SizedBox(height: 12),
        _MapControlButton(
          icon: Assets.icons.location.svg(
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(
                MapUiPalette.controlIcon, BlendMode.srcIn),
          ),
          onTap: onCurrentLocation,
        ),
      ],
    );
  }
}
