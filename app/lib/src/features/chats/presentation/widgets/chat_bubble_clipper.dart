import 'package:flutter/material.dart';

/// Скруглённый прямоугольник + маленький «хвост» снизу слева / справа (как в Figma).
class ChatBubbleClipper extends CustomClipper<Path> {
  ChatBubbleClipper({
    required this.outgoing,
    this.cornerRadius = 10,
    this.tailWidth = 9,
    this.tailHeight = 5,
  });

  final bool outgoing;
  final double cornerRadius;
  final double tailWidth;
  final double tailHeight;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = cornerRadius.clamp(2.0, 18.0);
    final tw = tailWidth;
    final th = tailHeight;
    final bodyBottom = (h - th).clamp(r * 2, h);

    final path = Path();
    if (outgoing) {
      _addOutgoing(path, w, h, r, tw, th, bodyBottom);
    } else {
      _addIncoming(path, w, h, r, tw, th, bodyBottom);
    }
    return path;
  }

  void _addOutgoing(
    Path path,
    double w,
    double h,
    double r,
    double tw,
    double th,
    double bodyBottom,
  ) {
    path.moveTo(r, 0);
    path.lineTo(w - r, 0);
    path.arcToPoint(Offset(w, r), radius: Radius.circular(r));
    path.lineTo(w, bodyBottom - r);
    path.arcToPoint(Offset(w - r, bodyBottom), radius: Radius.circular(r));
    final tailRight = w - 6;
    final tailLeft = tailRight - tw;
    path.lineTo(tailRight - tw * 0.35, bodyBottom);
    path.lineTo(tailRight - tw * 0.5, h);
    path.lineTo(tailLeft + tw * 0.15, bodyBottom);
    path.lineTo(r, bodyBottom);
    path.arcToPoint(Offset(0, bodyBottom - r), radius: Radius.circular(r));
    path.lineTo(0, r);
    path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));
  }

  void _addIncoming(
    Path path,
    double w,
    double h,
    double r,
    double tw,
    double th,
    double bodyBottom,
  ) {
    path.moveTo(r, 0);
    path.lineTo(w - r, 0);
    path.arcToPoint(Offset(w, r), radius: Radius.circular(r));
    path.lineTo(w, bodyBottom - r);
    path.arcToPoint(Offset(w - r, bodyBottom), radius: Radius.circular(r));
    path.lineTo(6 + tw * 0.85, bodyBottom);
    path.lineTo(6 + tw * 0.5, h);
    path.lineTo(6 - tw * 0.15, bodyBottom);
    path.lineTo(r, bodyBottom);
    path.arcToPoint(Offset(0, bodyBottom - r), radius: Radius.circular(r));
    path.lineTo(0, r);
    path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));
  }

  @override
  bool shouldReclip(covariant ChatBubbleClipper oldClipper) {
    return oldClipper.outgoing != outgoing ||
        oldClipper.cornerRadius != cornerRadius ||
        oldClipper.tailWidth != tailWidth ||
        oldClipper.tailHeight != tailHeight;
  }
}
