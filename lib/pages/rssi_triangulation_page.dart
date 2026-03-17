import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/signal_engine.dart';
import '../services/features_provider.dart';
import '../widgets/back_button_top_left.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  FALCON EYE V50.0 — MULTI-PATH RSSI TRIANGULATION
//  Uses 3+ BLE/WiFi beacons to compute a 2D position estimate.
//  Algorithm: Weighted-centroid from log-distance path loss distances.
//  Renders on a floor-plan canvas with anchor nodes and estimated position.
// ═══════════════════════════════════════════════════════════════════════════════

class RssiTriangulationPage extends ConsumerStatefulWidget {
  const RssiTriangulationPage({super.key});
  @override
  ConsumerState<RssiTriangulationPage> createState() => _RssiTriangulationPageState();
}

class _RssiTriangulationPageState extends ConsumerState<RssiTriangulationPage> {
  // Pin positions for anchors (user-draggable in canvas)
  final Map<String, Offset> _anchors = {};
  static const double _canvasW = 300;
  static const double _canvasH = 300;

  @override
  Widget build(BuildContext context) {
    final color = ref.watch(featuresProvider).primaryColor;
    final env = ref.watch(signalEngineProvider);

    // Use top 8 sources with best RSSI as anchors
    final sources = env.sources.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
    final anchors = sources.take(8).toList();

    // Assign stable canvas positions to anchors
    for (int i = 0; i < anchors.length; i++) {
      final s = anchors[i];
      if (!_anchors.containsKey(s.id)) {
        // Place in circle pattern
        final angle = (i / anchors.length) * 2 * math.pi;
        _anchors[s.id] = Offset(
          _canvasW / 2 + math.cos(angle) * 100,
          _canvasH / 2 + math.sin(angle) * 100,
        );
      }
    }

    // Compute estimated position via weighted centroid
    Offset? estimatedPos;
    if (anchors.length >= 3) {
      estimatedPos = _weightedCentroid(anchors);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: Column(children: [
        // ── Header ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            const BackButtonTopLeft(),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('RSSI TRIANGULATION', style: TextStyle(color: color, fontSize: 13,
                  fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              Text('2D POSITION ESTIMATE FROM ${anchors.length} BEACONS — NO GPS',
                  style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
            ])),
          ]),
        ),
        // ── Canvas ──────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: _canvasH,
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.3)),
            color: Colors.black,
          ),
          child: anchors.length < 3
              ? Center(child: Text('NEED 3+ SIGNAL SOURCES\n(${anchors.length} found)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color.withValues(alpha: 0.5),
                      fontFamily: 'monospace', letterSpacing: 1)))
              : CustomPaint(
                  painter: _TriangulationPainter(
                    anchors: anchors,
                    anchorPositions: _anchors,
                    estimatedPos: estimatedPos,
                    color: color,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        // ── Stats & anchor list ─────────────────────────────────────
        if (estimatedPos != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: color.withValues(alpha: 0.3)),
                color: color.withValues(alpha: 0.06),
              ),
              child: Row(children: [
                Icon(Icons.my_location, color: color, size: 14),
                const SizedBox(width: 8),
                Text('ESTIMATED POSITION: (${estimatedPos.dx.toStringAsFixed(1)}, ${estimatedPos.dy.toStringAsFixed(1)}) relative units',
                    style: TextStyle(color: color, fontSize: 10, fontFamily: 'monospace')),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: anchors.length,
            itemBuilder: (_, i) {
              final s = anchors[i];
              final dist = _distance(s.rssi.toDouble());
              final c = s.type == 'BLE' ? const Color(0xFF00BBFF)
                  : s.type == 'WiFi' ? const Color(0xFF00FF88)
                  : const Color(0xFFFF8800);
              return Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: c.withValues(alpha: 0.25)),
                  color: c.withValues(alpha: 0.03),
                ),
                child: Row(children: [
                  Container(width: 8, height: 8,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.label, style: const TextStyle(color: Colors.white,
                      fontSize: 10, fontFamily: 'monospace'))),
                  Text('${s.rssi.toInt()} dBm', style: TextStyle(color: c, fontSize: 10, fontFamily: 'monospace')),
                  const SizedBox(width: 8),
                  Text('~${dist.toStringAsFixed(1)}m',
                      style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
                ]),
              );
            },
          ),
        ),
      ])),
    );
  }

  double _distance(double rssi) {
    const txPower = -59.0;
    const n = 2.7;
    return math.pow(10.0, (txPower - rssi) / (10.0 * n)).toDouble();
  }

  Offset _weightedCentroid(List<SignalSource> sources) {
    double wSum = 0;
    double xSum = 0, ySum = 0;
    for (final s in sources) {
      final dist = _distance(s.rssi.toDouble());
      final weight = 1.0 / (dist * dist + 0.01);
      final pos = _anchors[s.id] ?? const Offset(_canvasW / 2, _canvasH / 2);
      xSum += pos.dx * weight;
      ySum += pos.dy * weight;
      wSum += weight;
    }
    return Offset(xSum / wSum, ySum / wSum);
  }
}

class _TriangulationPainter extends CustomPainter {
  final List<SignalSource> anchors;
  final Map<String, Offset> anchorPositions;
  final Offset? estimatedPos;
  final Color color;

  _TriangulationPainter({required this.anchors, required this.anchorPositions,
                          required this.estimatedPos, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // ── Grid ─────────────────────────────────────────────────────
    paint.color = Colors.white.withValues(alpha: 0.04);
    paint.strokeWidth = 0.5;
    for (int i = 0; i < 10; i++) {
      canvas.drawLine(Offset(0, size.height * i / 10), Offset(size.width, size.height * i / 10), paint);
      canvas.drawLine(Offset(size.width * i / 10, 0), Offset(size.width * i / 10, size.height), paint);
    }

    // ── Draw distance circles from each anchor ────────────────────
    for (final s in anchors) {
      final pos = anchorPositions[s.id];
      if (pos == null) continue;
      final dist = math.pow(10.0, (-59.0 - s.rssi) / (10.0 * 2.7));
      final radius = (dist * 20).clamp(10.0, 150.0);

      final c = s.type == 'BLE' ? const Color(0xFF00BBFF)
          : s.type == 'WiFi' ? const Color(0xFF00FF88)
          : const Color(0xFFFF8800);

      paint.color = c.withValues(alpha: 0.08);
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(pos, radius.toDouble(), paint);

      paint.color = c.withValues(alpha: 0.3);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 0.8;
      canvas.drawCircle(pos, radius.toDouble(), paint);

      // Anchor node
      paint.color = c;
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(pos, 5, paint);

      // Label
      final tp = TextPainter(
        text: TextSpan(text: s.label.length > 8 ? s.label.substring(0, 8) : s.label,
            style: TextStyle(color: c, fontSize: 8, fontFamily: 'monospace')),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pos.dx + 6, pos.dy - 6));
    }

    // ── Draw estimated position ───────────────────────────────────
    if (estimatedPos != null) {
      // Lines from anchors to estimate
      for (final s in anchors) {
        final pos = anchorPositions[s.id];
        if (pos == null) continue;
        paint.color = color.withValues(alpha: 0.15);
        paint.strokeWidth = 0.5;
        paint.style = PaintingStyle.stroke;
        canvas.drawLine(pos, estimatedPos!, paint);
      }

      // Pulsing estimated position marker
      paint.color = color.withValues(alpha: 0.15);
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(estimatedPos!, 14, paint);

      paint.color = color;
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.5;
      canvas.drawCircle(estimatedPos!, 10, paint);

      paint.color = color;
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(estimatedPos!, 4, paint);

      // Cross-hair
      paint.strokeWidth = 1;
      canvas.drawLine(estimatedPos! + const Offset(-14, 0), estimatedPos! + const Offset(14, 0), paint);
      canvas.drawLine(estimatedPos! + const Offset(0, -14), estimatedPos! + const Offset(0, 14), paint);
    }
  }

  @override
  bool shouldRepaint(_TriangulationPainter old) => old.anchors.length != anchors.length || old.color != color;
}
