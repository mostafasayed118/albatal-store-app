import 'package:flutter/material.dart';

/// A subtle procedural fabric-weave texture painted over a base color.
///
/// This is intentionally *honest* placeholder art — not a photograph or a
/// realistic texture. The cross-hatch pattern evokes woven cloth without
/// pretending to be a real fabric image. It gives the swatch more tactile
/// presence than a flat color block, and the pattern scales to any size.
///
/// When real product photography is supplied, this painter is removed
/// and `Image.asset` takes its place — the rest of the widget tree
/// is unchanged.
class FabricWeavePainter extends CustomPainter {
  FabricWeavePainter({
    required this.baseColor,
    this.threadCount = 12,
    this.threadColor,
  });

  final Color baseColor;
  final int threadCount;
  final Color? threadColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Base fill.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = baseColor,
    );

    final lineColor = threadColor ?? Color.lerp(baseColor, Colors.white, 0.15)!;
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final dx = size.width / threadCount;
    final dy = size.height / threadCount;

    // Horizontal threads.
    for (var i = 1; i < threadCount; i++) {
      final y = dy * i;
      // Slight waviness via a tiny offset per line for organic feel.
      final wobble = (i.isEven ? 0.5 : -0.5);
      canvas.drawLine(
        Offset(0, y + wobble),
        Offset(size.width, y + wobble),
        paint,
      );
    }

    // Vertical threads.
    for (var i = 1; i < threadCount; i++) {
      final x = dx * i;
      final wobble = (i.isEven ? -0.5 : 0.5);
      canvas.drawLine(
        Offset(x + wobble, 0),
        Offset(x + wobble, size.height),
        paint,
      );
    }

    // Diagonal highlight — a single faint diagonal that reinforces the
    // woven feel without overpowering the base color.
    final diagPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.08)
      ..strokeWidth = size.shortestSide * 0.12
      ..strokeCap = StrokeCap.round;
    final mid = Offset(size.width / 2, size.height / 2);
    final halfDiag = size.shortestSide * 0.28;
    canvas.drawLine(
      mid + Offset(-halfDiag, -halfDiag),
      mid + Offset(halfDiag, halfDiag),
      diagPaint,
    );
  }

  @override
  bool shouldRepaint(covariant FabricWeavePainter oldDelegate) =>
      oldDelegate.baseColor != baseColor ||
      oldDelegate.threadCount != threadCount ||
      oldDelegate.threadColor != threadColor;
}
