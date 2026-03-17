import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/signal_engine.dart';
import '../services/features_provider.dart';
import '../widgets/back_button_top_left.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  FALCON EYE V50.0 — SIGNAL HEATMAP EXPORT
//  Builds a 2D room-scale heatmap from signal RSSI + position history.
//  Export as PNG to device storage.
// ═══════════════════════════════════════════════════════════════════════════════

class HeatmapExportPage extends ConsumerStatefulWidget {
  const HeatmapExportPage({super.key});
  @override
  ConsumerState<HeatmapExportPage> createState() => _HeatmapExportPageState();
}

class _HeatmapExportPageState extends ConsumerState<HeatmapExportPage> {
  final GlobalKey _repaintKey = GlobalKey();
  String _exportStatus = '';
  bool _exporting = false;
  bool _recording = false;

  // Accumulated signal positions for heatmap
  final List<_SignalHit> _hits = [];

  @override
  Widget build(BuildContext context) {
    final color = ref.watch(featuresProvider).primaryColor;
    final env = ref.watch(signalEngineProvider);

    // Accumulate hits when recording
    if (_recording) {
      for (final s in env.sources) {
        _hits.add(_SignalHit(x: s.x, z: s.z, rssi: s.rssi));
        if (_hits.length > 5000) _hits.removeAt(0);
      }
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
              Text('SIGNAL HEATMAP EXPORT', style: TextStyle(color: color, fontSize: 13,
                  fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              Text('ROOM-SCALE RSSI SPATIAL MAP → PNG EXPORT',
                  style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
            ])),
            _badge(_recording ? '◉ RECORDING' : '○ IDLE',
                _recording ? Colors.greenAccent : Colors.white38),
          ]),
        ),
        // ── Stats ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _stat('HITS', '${_hits.length}', color),
            const SizedBox(width: 6),
            _stat('SOURCES', '${env.sources.length}', color),
            const SizedBox(width: 6),
            _stat('STATUS', _exportStatus.isEmpty ? '---' : _exportStatus.substring(0, math.min(_exportStatus.length, 8)),
                _exportStatus.startsWith('SAVED') ? Colors.greenAccent : color),
          ]),
        ),
        const SizedBox(height: 8),
        // ── Heatmap canvas ───────────────────────────────────────────
        Expanded(
          child: RepaintBoundary(
            key: _repaintKey,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.black,
              child: LayoutBuilder(
                builder: (ctx, box) => CustomPaint(
                  size: Size(box.maxWidth, box.maxHeight),
                  painter: _HeatmapPainter(hits: List.from(_hits), color: color),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // ── Controls ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: _btn(
              _recording ? 'STOP RECORD' : 'START RECORD',
              _recording ? Colors.orange : color,
              () => setState(() { _recording = !_recording; }),
            )),
            const SizedBox(width: 8),
            Expanded(child: _btn('EXPORT PNG', Colors.greenAccent, _exportPng)),
            const SizedBox(width: 8),
            Expanded(child: _btn('CLEAR', Colors.red,
                () => setState(() { _hits.clear(); _exportStatus = ''; }))),
          ]),
        ),
      ])),
    );
  }

  Future<void> _exportPng() async {
    if (_exporting) return;
    setState(() { _exporting = true; _exportStatus = 'EXPORTING...'; });

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() { _exportStatus = 'RENDER ERROR'; _exporting = false; });
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/falcon_heatmap_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      setState(() {
        _exportStatus = 'SAVED: ${file.path.split('/').last}';
        _exporting = false;
      });
    } catch (e) {
      setState(() { _exportStatus = 'ERROR: $e'; _exporting = false; });
    }
  }

  Widget _badge(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(border: Border.all(color: c.withValues(alpha: 0.4))),
    child: Text(t, style: TextStyle(color: c, fontSize: 9, fontFamily: 'monospace')),
  );

  Widget _stat(String l, String v, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: 0.25)),
        color: c.withValues(alpha: 0.04),
      ),
      child: Column(children: [
        Text(v, style: TextStyle(color: c, fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        Text(l, style: const TextStyle(color: Colors.white30, fontSize: 8, fontFamily: 'monospace')),
      ]),
    ),
  );

  Widget _btn(String label, Color c, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: 0.5)),
        color: c.withValues(alpha: 0.08),
      ),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(color: c, fontFamily: 'monospace',
          fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
    ),
  );
}

class _SignalHit {
  final double x, z, rssi;
  _SignalHit({required this.x, required this.z, required this.rssi});
}

class _HeatmapPainter extends CustomPainter {
  final List<_SignalHit> hits;
  final Color color;
  _HeatmapPainter({required this.hits, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (hits.isEmpty) {
      final tp = TextPainter(
        text: TextSpan(text: 'START RECORDING TO BUILD HEATMAP',
            style: TextStyle(color: color.withValues(alpha: 0.3), fontSize: 12,
                fontFamily: 'monospace', letterSpacing: 1)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: size.width);
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height / 2 - 10));
      return;
    }

    // Find bounds of signal positions
    double minX = hits.first.x, maxX = hits.first.x;
    double minZ = hits.first.z, maxZ = hits.first.z;
    for (final h in hits) {
      if (h.x < minX) minX = h.x; if (h.x > maxX) maxX = h.x;
      if (h.z < minZ) minZ = h.z; if (h.z > maxZ) maxZ = h.z;
    }
    final rangeX = (maxX - minX).abs().clamp(1.0, double.infinity);
    final rangeZ = (maxZ - minZ).abs().clamp(1.0, double.infinity);

    final p = Paint();
    p.style = PaintingStyle.fill;
    p.maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);

    // Draw Gaussian blobs for each hit
    for (final h in hits) {
      final sx = (h.x - minX) / rangeX * size.width;
      final sy = (h.z - minZ) / rangeZ * size.height;

      // Normalise RSSI -100...-20 → 0..1
      final intensity = ((h.rssi + 100) / 80).clamp(0.0, 1.0);
      final alpha = (intensity * 0.12).clamp(0.01, 0.15);

      // Heat color
      p.color = _heatColor(intensity, alpha);
      canvas.drawCircle(Offset(sx, sy), 18, p);
    }

    // Grid overlay
    p.maskFilter = null;
    p.color = Colors.white.withValues(alpha: 0.04);
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 0.5;
    for (int i = 0; i < 10; i++) {
      canvas.drawLine(Offset(size.width * i / 10, 0), Offset(size.width * i / 10, size.height), p);
      canvas.drawLine(Offset(0, size.height * i / 10), Offset(size.width, size.height * i / 10), p);
    }
  }

  Color _heatColor(double v, double alpha) {
    if (v < 0.33) return Color.fromRGBO(0, 100, 255, alpha * 2);
    if (v < 0.66) return Color.fromRGBO(0, 255, 150, alpha * 2);
    return Color.fromRGBO(255, 80, 0, alpha * 2);
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) => old.hits.length != hits.length;
}
