import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Human Hologram Painter - renders a wireframe human silhouette
/// with pulsing blood/neural flow effects
class HumanHologramPainter extends CustomPainter {
  final double time;
  final Color primaryColor;
  final bool showNeural;
  final bool showCardio;
  final double heartRate; // BPM for pulse effect

  HumanHologramPainter({
    required this.time,
    required this.primaryColor,
    this.showNeural = true,
    this.showCardio = true,
    this.heartRate = 72,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Head-to-toe scale
    final scale = h * 0.85;
    final top = h * 0.05;
    final headY = top + scale * 0.10;
    final shoulderY = top + scale * 0.20;
    final chestY = top + scale * 0.35;
    final waistY = top + scale * 0.50;
    final hipY = top + scale * 0.55;
    final kneeY = top + scale * 0.75;
    final footY = top + scale * 0.95;

    final bodyW = scale * 0.15;
    final shoulderW = scale * 0.22;
    final armLen = scale * 0.35;

    final pulse = 0.7 + 0.3 * math.sin(time * heartRate / 60 * 2 * math.pi);

    // Background atmospheric glow
    canvas.drawCircle(
      Offset(cx, h * 0.5),
      scale * 0.5,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.04)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
    );

    // ─── Wireframe body ──────────────────────────────────────────────────────
    final wirePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final glowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Head
    final headRadius = scale * 0.08;
    canvas.drawCircle(Offset(cx, headY), headRadius, glowPaint);
    canvas.drawCircle(Offset(cx, headY), headRadius, wirePaint);

    // Neck
    _drawLine(canvas, wirePaint, cx, headY + headRadius, cx, shoulderY);

    // Shoulders
    _drawLine(canvas, wirePaint, cx - shoulderW, shoulderY, cx + shoulderW, shoulderY);

    // Torso
    _drawBodyPath(canvas, wirePaint, cx, shoulderY, shoulderW, bodyW, chestY, waistY, hipY);

    // Arms
    _drawArm(canvas, wirePaint, cx - shoulderW, shoulderY,
        cx - shoulderW - armLen * 0.4, chestY,
        cx - shoulderW - armLen * 0.3, waistY);
    _drawArm(canvas, wirePaint, cx + shoulderW, shoulderY,
        cx + shoulderW + armLen * 0.4, chestY,
        cx + shoulderW + armLen * 0.3, waistY);

    // Legs
    _drawLine(canvas, wirePaint, cx - bodyW * 0.5, hipY, cx - bodyW * 0.7, kneeY);
    _drawLine(canvas, wirePaint, cx + bodyW * 0.5, hipY, cx + bodyW * 0.7, kneeY);
    _drawLine(canvas, wirePaint, cx - bodyW * 0.7, kneeY, cx - bodyW * 0.5, footY);
    _drawLine(canvas, wirePaint, cx + bodyW * 0.7, kneeY, cx + bodyW * 0.5, footY);

    // ─── Cardiovascular System ───────────────────────────────────────────────
    if (showCardio) {
      _drawCardioSystem(canvas, size, cx, headY, shoulderY, chestY, waistY, hipY, scale, pulse);
    }

    // ─── Neural System ───────────────────────────────────────────────────────
    if (showNeural) {
      _drawNeuralSystem(canvas, size, cx, headY, shoulderY, chestY, waistY, scale, time);
    }

    // ─── Scan overlay ────────────────────────────────────────────────────────
    _drawScanOverlay(canvas, size, time, primaryColor);
  }

  void _drawLine(Canvas canvas, Paint paint, double x1, double y1, double x2, double y2) {
    canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
  }

  void _drawBodyPath(Canvas canvas, Paint paint, double cx, double shoulderY,
      double shoulderW, double bodyW, double chestY, double waistY, double hipY) {
    final path = Path()
      ..moveTo(cx - shoulderW, shoulderY)
      ..lineTo(cx - bodyW * 1.1, chestY)
      ..lineTo(cx - bodyW * 0.9, waistY)
      ..lineTo(cx - bodyW * 1.0, hipY)
      ..moveTo(cx + shoulderW, shoulderY)
      ..lineTo(cx + bodyW * 1.1, chestY)
      ..lineTo(cx + bodyW * 0.9, waistY)
      ..lineTo(cx + bodyW * 1.0, hipY)
      // Close chest
      ..moveTo(cx - bodyW * 1.1, chestY)
      ..lineTo(cx + bodyW * 1.1, chestY)
      // Hip line
      ..moveTo(cx - bodyW * 1.0, hipY)
      ..lineTo(cx + bodyW * 1.0, hipY);
    canvas.drawPath(path, paint);
  }

  void _drawArm(Canvas canvas, Paint paint, double sx, double sy, double mx, double my, double ex, double ey) {
    final path = Path()
      ..moveTo(sx, sy)
      ..quadraticBezierTo(mx, my, ex, ey);
    canvas.drawPath(path, paint);
  }

  void _drawCardioSystem(Canvas canvas, Size size, double cx, double headY,
      double shoulderY, double chestY, double waistY, double hipY, double scale, double pulse) {
    final heartX = cx - scale * 0.03;
    final heartY = chestY - scale * 0.02;
    final heartPaint = Paint()
      ..color = const Color(0xFFFF0066).withValues(alpha: pulse * 0.8)
      ..style = PaintingStyle.fill;

    // Heart glow
    canvas.drawCircle(
      Offset(heartX, heartY),
      scale * 0.04 * pulse,
      Paint()
        ..color = const Color(0xFFFF0066).withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Heart beat symbol
    canvas.drawCircle(Offset(heartX, heartY), scale * 0.025 * pulse, heartPaint);

    // Aorta
    final aortaPaint = Paint()
      ..color = const Color(0xFFFF0066).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final aortaPath = Path()
      ..moveTo(heartX, heartY)
      ..quadraticBezierTo(cx + scale * 0.02, headY + scale * 0.05,
          cx, headY - scale * 0.04);
    canvas.drawPath(aortaPath, aortaPaint);

    // Descending aorta
    final descendPath = Path()
      ..moveTo(heartX, heartY)
      ..lineTo(cx - scale * 0.02, waistY)
      ..quadraticBezierTo(cx - scale * 0.05, hipY + scale * 0.05,
          cx - scale * 0.03, hipY + scale * 0.12);
    canvas.drawPath(descendPath, aortaPaint);
  }

  void _drawNeuralSystem(Canvas canvas, Size size, double cx, double headY,
      double shoulderY, double chestY, double waistY, double scale, double time) {
    final neuralPaint = Paint()
      ..color = const Color(0xFF00CCFF).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Spine
    final spineX = cx + scale * 0.01;
    canvas.drawLine(
      Offset(spineX, headY + scale * 0.08),
      Offset(spineX, waistY),
      neuralPaint,
    );

    // Neural branches (vertebrae)
    for (int i = 0; i < 8; i++) {
      final y = headY + scale * 0.10 + i * (waistY - headY - scale * 0.10) / 8;
      final pulse = 0.6 + 0.4 * math.sin(time * 3 + i * 0.8);
      canvas.drawLine(
        Offset(spineX - scale * 0.05 * pulse, y),
        Offset(spineX + scale * 0.05 * pulse, y),
        Paint()
          ..color = const Color(0xFF00CCFF).withValues(alpha: 0.3 * pulse)
          ..strokeWidth = 0.6,
      );
    }

    // Brain activity pulses
    final brainRadius = scale * 0.06;
    for (int i = 0; i < 6; i++) {
      final angle = time * 2 + i * math.pi / 3;
      final bx = cx + math.cos(angle) * brainRadius;
      final by = headY - scale * 0.02 + math.sin(angle) * brainRadius * 0.6;
      canvas.drawCircle(
        Offset(bx, by),
        2,
        Paint()..color = const Color(0xFF00CCFF).withValues(alpha: 0.6),
      );
    }
  }

  void _drawScanOverlay(Canvas canvas, Size size, double time, Color color) {
    // Moving scan line
    final scanY = (time * 60 % size.height);
    canvas.drawLine(
      Offset(0, scanY),
      Offset(size.width, scanY),
      Paint()
        ..color = color.withValues(alpha: 0.2)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(HumanHologramPainter old) =>
      old.time != time || old.showNeural != showNeural || old.showCardio != showCardio;
}
