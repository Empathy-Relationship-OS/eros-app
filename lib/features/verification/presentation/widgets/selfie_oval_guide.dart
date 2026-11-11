import 'package:flutter/material.dart';

/// Dims the camera preview outside an oval where the face goes.
class SelfieOvalGuide extends StatelessWidget {
  const SelfieOvalGuide({super.key});

  /// The oval's rectangle in a [size] canvas: centred, a little above the middle.
  static Rect ovalIn(Size size) {
    final width = size.width * 0.72;
    final height = width * 1.35;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.45),
      width: width,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) => const IgnorePointer(
        child: ExcludeSemantics(
          child: CustomPaint(painter: _OvalGuidePainter(), size: Size.infinite),
        ),
      );
}

class _OvalGuidePainter extends CustomPainter {
  const _OvalGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final oval = SelfieOvalGuide.ovalIn(size);
    final shade = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addOval(oval),
    );
    canvas.drawPath(shade, Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawOval(
      oval,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_OvalGuidePainter oldDelegate) => false;
}
