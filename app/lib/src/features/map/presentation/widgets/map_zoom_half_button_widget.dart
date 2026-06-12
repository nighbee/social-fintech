part of 'package:app/src/features/map/presentation/pages/map_page.dart';

class _MapZoomHalfButton extends StatefulWidget {
  const _MapZoomHalfButton({
    required this.onTap,
    required this.icon,
  });

  final VoidCallback onTap;
  final Widget icon;

  @override
  State<_MapZoomHalfButton> createState() => _MapZoomHalfButtonState();
}

class _MapZoomHalfButtonState extends State<_MapZoomHalfButton> {
  Timer? _repeatTimer;

  void _startRepeating() {
    widget.onTap();
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(
      const Duration(milliseconds: 220),
      (_) => widget.onTap(),
    );
  }

  void _stopRepeating() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _stopRepeating();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPressStart: (_) => _startRepeating(),
      onLongPressEnd: (_) => _stopRepeating(),
      onLongPressCancel: _stopRepeating,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(child: widget.icon),
      ),
    );
  }
}
