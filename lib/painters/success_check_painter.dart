import 'package:flutter/material.dart';
import 'dart:math' as math;

class SuccessCheckPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  SuccessCheckPainter({
    required this.progress,
    this.color = Colors.green,
    this.strokeWidth = 6.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // Draw background circle
    if (progress <= 0.5) {
      final bgPaint = Paint()
        ..color = color.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width * 0.35,
        bgPaint,
      );
    }

    // Draw animated circle
    if (progress < 0.5) {
      final circleProgress = math.min(1.0, progress * 2);
      final rect = Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width * 0.35,
      );
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * circleProgress,
        false,
        paint,
      );
    } else {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width * 0.35,
        paint,
      );

      // Draw check mark with spring effect
      if (progress > 0.5) {
        final checkProgress = ((progress - 0.5) * 2).clamp(0.0, 1.0);
        final springEffect = math.sin(checkProgress * math.pi * 2) * 0.07 * (1 - checkProgress);
        
        final path = Path();
        final startPoint = Offset(
          size.width * 0.3,
          size.height * 0.5,
        );
        final midPoint = Offset(
          size.width * 0.45,
          size.height * 0.65,
        );
        final endPoint = Offset(
          size.width * 0.7,
          size.height * 0.35,
        );

        path.moveTo(startPoint.dx, startPoint.dy + (springEffect * size.height));
        
        if (checkProgress <= 0.5) {
          final currentProgress = checkProgress * 2;
          path.lineTo(
            startPoint.dx + (midPoint.dx - startPoint.dx) * currentProgress,
            startPoint.dy + (midPoint.dy - startPoint.dy) * currentProgress + (springEffect * size.height),
          );
        } else {
          path.lineTo(midPoint.dx, midPoint.dy + (springEffect * size.height));
          final currentProgress = (checkProgress - 0.5) * 2;
          path.lineTo(
            midPoint.dx + (endPoint.dx - midPoint.dx) * currentProgress,
            midPoint.dy + (endPoint.dy - midPoint.dy) * currentProgress + (springEffect * size.height),
          );
        }

        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
