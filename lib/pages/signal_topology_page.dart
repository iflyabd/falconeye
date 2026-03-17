import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/signal_engine.dart';
import '../services/features_provider.dart';
import '../widgets/back_button_top_left.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  FALCON EYE V50.0 — SIGNAL TOPOLOGY MAP
//  2D force-directed graph showing signal sources as nodes.
//  Edge weight = signal strength similarity. Pan + pinch to navigate.
// ═══════════════════════════════════════════════════════════════════════════════

class SignalTopologyPage extends ConsumerStatefulWidget {
  const SignalTopologyPage({super.key});
  @override
  ConsumerState<SignalTopologyPage> createState() => _SignalTopologyPageState();
}

class _SignalTopologyPageState extends ConsumerState<SignalTopologyPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  double _panX = 0, _panY = 0;
  double _scale = 1.0;
  double _scaleStart = 1.0;
  Offset _panStart = Offset.zero;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = ref.watch(featuresProvider).primaryColor;
    final env = ref.watch(signalEngineProvider);
    final sources = env.sources;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: Column(children: [
        _Header(color: color, nodeCount: sources.length),
        Expanded(
          child: GestureDetector(
            onScaleStart: (d) {
              _scaleStart = _scale;
              _panStart = d.localFocalPoint;
            },
            onScaleUpdate: (d) {
              setState(() {
                _scale = (_scaleStart * d.scale).clamp(0.3, 4.0);
                final delta = d.localFocalPoint - _panStart;
                _panX += delta.dx;
                _panY += delta.dy;
                _panStart = d.localFocalPoint;
              });
            },
            child: LayoutBuilder(
              builder: (ctx, box) => AnimatedBuilder(
                animation: _animCtrl,
                builder: (_, __) => CustomPaint(
                  size: Size(box.maxWidth, box.maxHeight),
                  painter: _TopologyPainter(
                    sources: sources,
                    color: color,
                    panX: _panX,
                    panY: _panY,
                    scale: _scale,
                    t: _animCtrl.value,
                  ),
                ),
              ),
            ),
          ),
        ),
        _Legend(color: color),
      ])),
    );
  }
}

class _TopologyPainter extends CustomPainter {
  final List<SignalSource> sources;
  final Color color;
  final double panX, panY, scale, t;

  _TopologyPainter({required this.sources, required this.color,
                    required this.panX, required this.panY,
                    required this.scale, required this.t});

  // Map signal source to stable 2D position (polar layout by type)
  Offset _nodePos(SignalSource s, Size size) {
    final cx = size.width / 2 + panX;
    final cy = size.height / 2 + panY;

    // Use source id hash for stable position
    final hash = s.id.hashCode;
    final angle = (hash % 360) * math.pi / 180.0;
    final radiusBase = switch (s.type) {
      'BLE'  => 100.0,
      'WiFi' => 160.0,
      'Cell' => 220.0,
      _      => 140.0,
    };
    final r = (radiusBase + (hash % 50)) * scale;

    return Offset(cx + math.cos(angle) * r, cy + math.sin(angle) * r);
  }

  Color _typeColor(String type) => switch (type) {
    'BLE'  => const Color(0xFF00BBFF),
    'WiFi' => const Color(0xFF00FF88),
    'Cell' => const Color(0xFFFF8800),
    _      => const Color(0xFFAAAAAA),
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (sources.isEmpty) {
      final p = Paint()..color = color.withValues(alpha: 0.2);
      final tp = TextPainter(
        text: TextSpan(
          text: 'NO SIGNAL SOURCES\nSTART SCANNING',
          style: TextStyle(color: color.withValues(alpha: 0.4), fontSize: 14,
              fontFamily: 'monospace', letterSpacing: 2),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: size.width);
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height / 2 - 20));
      return;
    }

    final positions = {for (final s in sources) s.id: _nodePos(s, size)};

    // ── Draw edges ─────────────────────────────────────────────────
    final edgePaint = Paint()..strokeWidth = 0.5;
    for (int i = 0; i < sources.length; i++) {
      for (int j = i + 1; j < sources.length; j++) {
        final a = sources[i], b = sources[j];
        // Connect same-type sources, or strong signals
        if (a.type != b.type && a.rssi < -70 && b.rssi < -70) continue;
        final diff = (a.rssi - b.rssi).abs();
        if (diff > 25) continue;

        final alpha = (1.0 - diff / 25.0) * 0.25;
        edgePaint.color = color.withValues(alpha: alpha);
        canvas.drawLine(positions[a.id]!, positions[b.id]!, edgePaint);
      }
    }

    // ── Draw nodes ─────────────────────────────────────────────────
    for (final s in sources) {
      final pos = positions[s.id]!;
      final nc = _typeColor(s.type);
      // Signal strength → node radius
      final radius = ((s.rssi + 100) / 70 * 12 + 4).clamp(4.0, 20.0) * scale;

      // Pulse ring
      final pulse = (1.0 + math.sin(t * math.pi * 2 + s.id.hashCode * 0.1)) / 2;
      final ringPaint = Paint()
        ..color = nc.withValues(alpha: 0.15 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(pos, radius * (1 + pulse * 0.5), ringPaint);

      // Node fill
      final fill = Paint()
        ..color = nc.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, radius, fill);

      // Node border
      final border = Paint()
        ..color = nc
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(pos, radius, border);

      // Label
      if (scale > 0.6) {
        final label = s.label.length > 10 ? s.label.substring(0, 10) : s.label;
        final tp = TextPainter(
          text: TextSpan(text: label,
              style: TextStyle(color: Colors.white, fontSize: 8 * scale, fontFamily: 'monospace')),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy + radius + 2));

        // RSSI
        final rssiTp = TextPainter(
          text: TextSpan(text: '${s.rssi.toInt()}dB',
              style: TextStyle(color: nc, fontSize: 7 * scale, fontFamily: 'monospace')),
          textDirection: TextDirection.ltr,
        )..layout();
        rssiTp.paint(canvas, Offset(pos.dx - rssiTp.width / 2, pos.dy + radius + 12 * scale));
      }
    }

    // ── Centre node (device) ────────────────────────────────────────
    final cx = size.width / 2 + panX;
    final cy = size.height / 2 + panY;
    final cp = Paint()..color = color.withValues(alpha: 0.9);
    canvas.drawCircle(Offset(cx, cy), 8 * scale, cp);
    final cp2 = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), 10 * scale, cp2);

    final dtp = TextPainter(
      text: TextSpan(text: 'DEVICE',
          style: TextStyle(color: color, fontSize: 7 * scale, fontFamily: 'monospace')),
      textDirection: TextDirection.ltr,
    )..layout();
    dtp.paint(canvas, Offset(cx - dtp.width / 2, cy + 12 * scale));
  }

  @override
  bool shouldRepaint(_TopologyPainter old) => old.sources.length != sources.length || old.t != t || old.panX != panX || old.panY != panY;
}

class _Header extends StatelessWidget {
  final Color color;
  final int nodeCount;
  const _Header({required this.color, required this.nodeCount});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      const BackButtonTopLeft(),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SIGNAL TOPOLOGY MAP', style: TextStyle(color: color, fontSize: 13,
            fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        Text('FORCE-DIRECTED SIGNAL GRAPH • $nodeCount NODES',
            style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
      ])),
    ]),
  );
}

class _Legend extends StatelessWidget {
  final Color color;
  const _Legend({required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _dot(const Color(0xFF00BBFF), 'BLE'),
      const SizedBox(width: 16),
      _dot(const Color(0xFF00FF88), 'WiFi'),
      const SizedBox(width: 16),
      _dot(const Color(0xFFFF8800), 'Cell'),
      const SizedBox(width: 16),
      _dot(color, 'Device'),
    ]),
  );

  Widget _dot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'monospace')),
  ]);
}
