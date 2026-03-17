import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vmath;

class Orientation3DView extends StatelessWidget {
  final double roll;  // radians
  final double pitch; // radians
  final double yaw;   // radians
  final Color wireColor;
  final Color fillColor;

  const Orientation3DView({super.key,
    required this.roll,
    required this.pitch,
    required this.yaw,
    this.wireColor = const Color(0xFF00E5FF),
    this.fillColor = const Color(0x3300E5FF),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        return CustomPaint(
          size: Size.square(size),
          painter: _CubePainter(roll: roll, pitch: pitch, yaw: yaw, wire: wireColor, fill: fillColor),
        );
      },
    );
  }
}

class _CubePainter extends CustomPainter {
  final double roll, pitch, yaw; // radians
  final Color wire, fill;
  _CubePainter({required this.roll, required this.pitch, required this.yaw, required this.wire, required this.fill});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.shortestSide * 0.35;

    // 3D cube vertices (-1..1)
    final List<vmath.Vector3> verts = [
      vmath.Vector3(-1, -1, -1), vmath.Vector3(1, -1, -1), vmath.Vector3(1, 1, -1), vmath.Vector3(-1, 1, -1),
      vmath.Vector3(-1, -1, 1),  vmath.Vector3(1, -1, 1),  vmath.Vector3(1, 1, 1),  vmath.Vector3(-1, 1, 1),
    ];

    // Rotation Rz(yaw)*Ry(pitch)*Rx(roll)
    final m = vmath.Matrix4.identity()
      ..rotateZ(yaw)
      ..rotateY(pitch)
      ..rotateX(roll);

    // Apply transform
    final transformed = verts.map((v) => m.transform3(vmath.Vector3.copy(v))).toList();

    // Simple perspective projection
    const double fov = 1.2; // radians
    final double d = 1 / math.tan(fov / 2);

    Offset project(vmath.Vector3 v) {
      // Shift z to be positive
      final double z = v.z + 3; // move cube forward
      final double px = (v.x * d) / z;
      final double py = (v.y * d) / z;
      return Offset(px * scale + center.dx, py * scale + center.dy);
    }

    final pts = transformed.map(project).toList();

    final edges = [
      [0,1],[1,2],[2,3],[3,0], // back face
      [4,5],[5,6],[6,7],[7,4], // front face
      [0,4],[1,5],[2,6],[3,7], // connections
    ];

    final faceFront = [4,5,6,7];

    final paintWire = Paint()
      ..color = wire
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintFill = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;

    // Draw horizon plane (xy after pitch/roll)
    final horizonRadius = size.shortestSide * 0.45;
    final horizon = Path()
      ..addOval(Rect.fromCircle(center: center, radius: horizonRadius));
    canvas.drawPath(horizon, Paint()
      ..color = fill.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill);

    // Draw filled front face for depth cue
    final facePath = Path()
      ..moveTo(pts[faceFront[0]].dx, pts[faceFront[0]].dy)
      ..lineTo(pts[faceFront[1]].dx, pts[faceFront[1]].dy)
      ..lineTo(pts[faceFront[2]].dx, pts[faceFront[2]].dy)
      ..lineTo(pts[faceFront[3]].dx, pts[faceFront[3]].dy)
      ..close();
    canvas.drawPath(facePath, paintFill);

    // Draw cube edges
    for (final e in edges) {
      canvas.drawLine(pts[e[0]], pts[e[1]], paintWire);
    }

    // Crosshair
    final ch = Paint()..color = wire.withValues(alpha: 0.8)..strokeWidth = 1.5;
    canvas.drawLine(Offset(center.dx - 12, center.dy), Offset(center.dx + 12, center.dy), ch);
    canvas.drawLine(Offset(center.dx, center.dy - 12), Offset(center.dx, center.dy + 12), ch);
  }

  @override
  bool shouldRepaint(covariant _CubePainter old) {
    return old.roll != roll || old.pitch != pitch || old.yaw != yaw || old.wire != wire || old.fill != fill;
    }
}
