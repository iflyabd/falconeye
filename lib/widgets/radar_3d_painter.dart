// ═══════════════════════════════════════════════════════════════════════════════
// FALCON EYE — REAL 3D SIGNAL POINT CLOUD PAINTER
// Renders only real measured signal sources:
//   • 3D perspective view (top 75%): X/Y/Z from AoA+RSSI triangulation
//   • Top-down radar (bottom 25%): azimuth ring map
// Visual encoding (all derived from real measurements):
//   BLE=cyan  WiFi=green  Cell=orange
//   Size = RSSI strength (larger = stronger signal = closer/less obstructed)
//   Dashed ring = isMoving (RSSI variance > 5 dBm²)
//   Confidence arc = how many samples & how strong
// Camera: drag to orbit, pinch to zoom. No fake effects, no animations.
// ═══════════════════════════════════════════════════════════════════════════════
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/signal_engine.dart';

class RadarPainter3D extends CustomPainter {
  final List<SignalSource> sources;
  final DeviceOrientation orientation;
  final double rotX;   // camera pitch (radians) — negative = looking down
  final double rotY;   // camera yaw (radians)
  final double scale;
  final DateTime tick;

  const RadarPainter3D({
    required this.sources,
    required this.orientation,
    required this.rotX,
    required this.rotY,
    required this.scale,
    required this.tick,
  });

  // ─── 3D → 2D perspective projection ──────────────────────────────────────
  Offset _project(double x, double y, double z, Size sz) {
    // Yaw rotation
    final cy = math.cos(rotY), sy = math.sin(rotY);
    final x1 = x * cy - z * sy;
    final z1 = x * sy + z * cy;
    // Pitch rotation
    final cx = math.cos(rotX), sx = math.sin(rotX);
    final y2 = y * cx - z1 * sx;
    final z2 = y * sx + z1 * cx;
    // Perspective
    final fov   = sz.height * 0.50 * scale;
    final depth = z2 + 9.0; // push scene back
    if (depth < 0.1) return Offset(sz.width / 2, sz.height * 0.38);
    final px = (x1 / depth) * fov + sz.width / 2;
    final py = -(y2 / depth) * fov + sz.height * 0.38;
    return Offset(px, py);
  }

  // ─── Signal type → color ──────────────────────────────────────────────────
  Color _color(String type, double alpha) {
    switch (type) {
      case 'BLE':  return Color.fromRGBO(0,   220, 255, alpha);
      case 'WiFi': return Color.fromRGBO(0,   255, 120, alpha);
      case 'Cell': return Color.fromRGBO(255, 160, 0,   alpha);
      default:     return Color.fromRGBO(200, 200, 200, alpha);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF040810));
    _drawGridAndAxes(canvas, size);
    _drawSources3D(canvas, size);
    _drawRadar2D(canvas, size);
    _drawCompass(canvas, size);
    _drawLegend(canvas, size);
  }

  // ─── 3D grid floor (y=0 plane, ±10m) ─────────────────────────────────────
  void _drawGridAndAxes(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF091509)
      ..strokeWidth = 0.4;

    for (double x = -12; x <= 12; x += 2) {
      canvas.drawLine(_project(x, 0, -12, size), _project(x, 0, 12, size), gridPaint);
    }
    for (double z = -12; z <= 12; z += 2) {
      canvas.drawLine(_project(-12, 0, z, size), _project(12, 0, z, size), gridPaint);
    }

    // Origin = device position
    final origin = _project(0, 0, 0, size);
    canvas.drawCircle(origin, 5,  Paint()..color = const Color(0xFF00FF88)..style = PaintingStyle.fill);
    canvas.drawCircle(origin, 9,  Paint()..color = const Color(0xFF00FF88).withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawCircle(origin, 14, Paint()..color = const Color(0xFF00FF88).withValues(alpha: 0.2)..style = PaintingStyle.stroke..strokeWidth = 1);
    _label(canvas, 'DEVICE', origin + const Offset(12, -8), const Color(0xFF00FF88), 8.5);

    // Altitude reference line (Y axis at origin)
    final up = _project(0, 3, 0, size);
    canvas.drawLine(origin, up, Paint()..color = const Color(0xFF00FF88).withValues(alpha: 0.3)..strokeWidth = 0.8);
  }

  // ─── Draw signal sources in 3D space ─────────────────────────────────────
  void _drawSources3D(Canvas canvas, Size size) {
    if (sources.isEmpty) {
      final c = Offset(size.width / 2, size.height * 0.38);
      _label(canvas, 'No signals detected\nEnable BLE + Location', c, const Color(0xFF2A5A2A), 11);
      return;
    }

    // Painter's algorithm: sort back-to-front
    final sorted = List<SignalSource>.from(sources);
    sorted.sort((a, b) {
      final da = a.x * math.sin(rotY) + a.z * math.cos(rotY);
      final db = b.x * math.sin(rotY) + b.z * math.cos(rotY);
      return db.compareTo(da);
    });

    for (final src in sorted) {
      final pt = _project(src.x, src.y, src.z, size);
      // Clip — only draw within 3D viewport
      if (pt.dx < -80 || pt.dx > size.width + 80 || pt.dy < 0 || pt.dy > size.height * 0.78) continue;

      final rssiNorm = ((src.rssi + 100) / 70.0).clamp(0.0, 1.0);
      final radius   = 3.5 + rssiNorm * 14.0;
      final col      = _color(src.type, 0.9);
      final colFill  = _color(src.type, 0.15);

      // Depth line to floor
      final floor = _project(src.x, 0, src.z, size);
      canvas.drawLine(pt, floor, Paint()..color = col.withValues(alpha: 0.2)..strokeWidth = 0.7);
      canvas.drawCircle(floor, 2.5, Paint()..color = col.withValues(alpha: 0.4)..style = PaintingStyle.fill);

      // Filled circle
      canvas.drawCircle(pt, radius, Paint()..color = colFill..style = PaintingStyle.fill);
      // Border
      canvas.drawCircle(pt, radius, Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);

      // Motion indicator (dashed outer ring)
      if (src.isMoving) {
        _dashedCircle(canvas, pt, radius + 5, col.withValues(alpha: 0.75), 1.5, 8);
      }

      // Confidence arc (how certain we are of position)
      if (src.confidence > 0.05) {
        canvas.drawArc(
          Rect.fromCircle(center: pt, radius: radius + 3),
          -math.pi / 2,
          math.pi * 2 * src.confidence,
          false,
          Paint()..color = col.withValues(alpha: 0.8)..strokeWidth = 1.8..style = PaintingStyle.stroke,
        );
      }

      // Label
      final dist  = src.distance < 100 ? '${src.distance.toStringAsFixed(1)}m' : '>100m';
      final badge = '${_shortType(src.type)} ${src.rssi.toStringAsFixed(0)}dBm $dist';
      _label(canvas, '${src.label}\n$badge', pt + Offset(radius + 5, -10), col, 8.5);
    }
  }

  String _shortType(String t) => t == 'BLE' ? 'BLE' : t == 'WiFi' ? 'WiFi' : 'Cell';

  // ─── 2D radar floor plan (bottom strip) ──────────────────────────────────
  void _drawRadar2D(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.90;
    final maxR = (size.width * 0.44).clamp(0.0, 160.0);

    // Clip to bottom strip
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, size.height * 0.78, size.width, size.height));

    // Background
    canvas.drawRect(
      Rect.fromLTRB(0, size.height * 0.78, size.width, size.height),
      Paint()..color = const Color(0xFF050B05),
    );

    // Range rings: 2m, 5m, 10m, 25m
    for (final rm in [2.0, 5.0, 10.0, 25.0]) {
      final pr = (rm / 30.0 * maxR).clamp(0.0, maxR);
      canvas.drawCircle(Offset(cx, cy), pr,
          Paint()..color = const Color(0xFF0C1A0C)..strokeWidth = 0.7..style = PaintingStyle.stroke);
      _label(canvas, '${rm.toInt()}m', Offset(cx + pr + 2, cy - 7), const Color(0xFF1A3A1A), 7.5);
    }

    // Cardinal spokes
    final spokePaint = Paint()..color = const Color(0xFF0E1E0E)..strokeWidth = 0.5;
    for (int d = 0; d < 360; d += 45) {
      final r2 = d * math.pi / 180;
      canvas.drawLine(Offset(cx, cy),
          Offset(cx + maxR * math.sin(r2), cy - maxR * math.cos(r2)), spokePaint);
    }

    // North arrow (follows device yaw)
    final nRad = -orientation.yaw; // device yaw → magnetic north bearing
    final nx = cx + (maxR - 10) * math.sin(nRad);
    final ny = cy - (maxR - 10) * math.cos(nRad);
    canvas.drawLine(Offset(cx, cy), Offset(nx, ny),
        Paint()..color = const Color(0xFFFF3030)..strokeWidth = 2.0..strokeCap = StrokeCap.round);
    _label(canvas, 'N', Offset(nx - 4, ny - 11), const Color(0xFFFF5050), 8.5);

    // Device dot
    canvas.drawCircle(Offset(cx, cy), 4, Paint()..color = const Color(0xFF00FF88)..style = PaintingStyle.fill);

    // Signal source dots on radar
    for (final src in sources) {
      final scaledDist = (src.distance / 30.0 * maxR).clamp(0.0, maxR);
      final px = cx + scaledDist * math.sin(src.azimuth);
      final py = cy - scaledDist * math.cos(src.azimuth);
      final col    = _color(src.type, 0.9);
      final rN     = ((src.rssi + 100) / 70.0).clamp(0.0, 1.0);
      final radius = 2.5 + rN * 6.5;

      canvas.drawLine(Offset(cx, cy), Offset(px, py),
          Paint()..color = col.withValues(alpha: 0.15)..strokeWidth = 0.5);
      canvas.drawCircle(Offset(px, py), radius,
          Paint()..color = _color(src.type, 0.25)..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(px, py), radius,
          Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = 1.2);
      if (src.isMoving) {
        _dashedCircle(canvas, Offset(px, py), radius + 3, col.withValues(alpha: 0.6), 1.0, 6);
      }
    }
    canvas.restore();
  }

  // ─── Compass (top-right) ──────────────────────────────────────────────────
  void _drawCompass(Canvas canvas, Size size) {
    const cx = 0.0;
    const cy = 44.0;
    final ox = size.width - 44.0;
    const r  = 22.0;
    canvas.drawCircle(Offset(ox + cx, cy), r,
        Paint()..color = const Color(0xFF080E08)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(ox + cx, cy), r,
        Paint()..color = const Color(0xFF1A341A)..style = PaintingStyle.stroke..strokeWidth = 1);
    final nY  = -orientation.yaw;
    final tip = Offset(ox + cx + r * 0.72 * math.sin(nY), cy - r * 0.72 * math.cos(nY));
    canvas.drawLine(Offset(ox + cx, cy), tip,
        Paint()..color = const Color(0xFFFF3030)..strokeWidth = 2.0..strokeCap = StrokeCap.round);
    _label(canvas, 'N', tip + const Offset(-3, -9), const Color(0xFFFF5050), 7.5);
    _label(canvas, '${(_toDeg(orientation.yaw) % 360).toStringAsFixed(0)}°',
        Offset(ox - 4, cy + r + 4), const Color(0xFF2A5A2A), 7.5);
  }

  double _toDeg(double r) => r * 180 / math.pi;

  // ─── Legend ───────────────────────────────────────────────────────────────
  void _drawLegend(Canvas canvas, Size size) {
    const items = [
      ('BLE',  Color(0xFF00DCFF)),
      ('WiFi', Color(0xFF00FF78)),
      ('Cell', Color(0xFFFFA000)),
    ];
    double ox = 8;
    for (final (lbl, col) in items) {
      canvas.drawCircle(Offset(ox + 5, 14), 5, Paint()..color = col..style = PaintingStyle.fill);
      _label(canvas, lbl, Offset(ox + 12, 7), col, 8.5);
      ox += 46;
    }
    _dashedCircle(canvas, Offset(ox + 5, 14), 5, const Color(0xFFFFFFFF).withValues(alpha: 0.7), 1, 6);
    _label(canvas, 'Moving', Offset(ox + 12, 7), const Color(0xFFCCCCCC), 8.5);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  void _dashedCircle(Canvas canvas, Offset c, double r, Color col, double sw, int dashes) {
    final p    = Paint()..color = col..strokeWidth = sw..style = PaintingStyle.stroke;
    final step = math.pi * 2 / dashes;
    for (int i = 0; i < dashes; i += 2) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), i * step, step, false, p);
    }
  }

  void _label(Canvas canvas, String text, Offset pos, Color col, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: col, fontSize: fontSize, fontFamily: 'monospace',
            height: 1.3),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(RadarPainter3D old) =>
      old.sources != sources || old.rotX != rotX ||
      old.rotY != rotY || old.scale != scale || old.tick != tick;
}
