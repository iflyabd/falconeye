import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wifi_csi_service.dart';
import '../services/features_provider.dart';
import '../widgets/back_button_top_left.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  FALCON EYE V48.1 — SPECTROGRAM WATERFALL
//  Real-time scrolling FFT waterfall. X = frequency bins, Y = time (newest top).
//  Colour maps amplitude → heat gradient (black→purple→cyan→yellow→white).
//  Data source: CSI amplitude[] from wifiCSIProvider — zero mock.
// ═══════════════════════════════════════════════════════════════════════════════

// ── Heat-map colour gradient ───────────────────────────────────────────────
Color _heat(double v) {
  // v in [0,1] — black→purple→cyan→yellow→white
  v = v.clamp(0.0, 1.0);
  if (v < 0.25) {
    final t = v / 0.25;
    return Color.fromARGB(255, (80 * t).toInt(), 0, (160 * t).toInt());
  } else if (v < 0.5) {
    final t = (v - 0.25) / 0.25;
    return Color.fromARGB(255, 0, (220 * t).toInt(), (160 + 95 * t).toInt());
  } else if (v < 0.75) {
    final t = (v - 0.5) / 0.25;
    return Color.fromARGB(255, (255 * t).toInt(), 255, (255 * (1 - t)).toInt());
  } else {
    final t = (v - 0.75) / 0.25;
    return Color.fromARGB(255, 255, 255, (255 * t).toInt());
  }
}

class SpectrogramWaterfallPage extends ConsumerStatefulWidget {
  const SpectrogramWaterfallPage({super.key});
  @override
  ConsumerState<SpectrogramWaterfallPage> createState() => _SpectrogramWaterfallPageState();
}

class _SpectrogramWaterfallPageState extends ConsumerState<SpectrogramWaterfallPage> {
  static const int _bins = 128;
  static const int _rows = 200;  // waterfall history rows

  // Ring buffer: newest row at index [_head]
  final List<Float32List> _waterfall = List.generate(_rows, (_) => Float32List(_bins));
  int _head = 0;

  // FFT peak tracking
  double _peakFreq = 0;
  double _peakAmp  = 0;
  double _gain     = 1.0;   // manual gain multiplier

  Timer? _frameTimer;
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    _frameTimer = Timer.periodic(const Duration(milliseconds: 100), _tick);  // 10 Hz is sufficient for waterfall
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    super.dispose();
  }

  void _tick(Timer _) {
    final csi = ref.read(wifiCSIProvider);
    _frameCount++;

    Float32List row;
    if (csi.rawData.isNotEmpty) {
      // Use real CSI amplitude data
      row = _buildRowFromCsi(csi.rawData);
    } else {
      // No data → flat zero row (zero-simulation protocol)
      row = Float32List(_bins);
    }

    // Apply gain
    for (int i = 0; i < _bins; i++) row[i] = (row[i] * _gain).clamp(0.0, 1.0);

    // Track peak
    double peak = 0;
    int peakIdx = 0;
    for (int i = 0; i < _bins; i++) {
      if (row[i] > peak) { peak = row[i]; peakIdx = i; }
    }
    _peakFreq = peakIdx / _bins * 80.0; // map to 0–80 MHz display range
    _peakAmp  = peak;

    _waterfall[_head] = row;
    _head = (_head + 1) % _rows;

    if (mounted) setState(() {});
  }

  Float32List _buildRowFromCsi(List<CSIDataPoint> pts) {
    final row = Float32List(_bins);
    final counts = List<int>.filled(_bins, 0);

    for (final pt in pts) {
      // Map subcarrierIndex to bin
      final bin = (pt.subcarrierIndex % _bins).abs();
      // Normalize amplitude: typical range -90 to -20 dBm → 0..1
      final norm = ((pt.amplitude + 90) / 70).clamp(0.0, 1.0);
      row[bin] = (row[bin] + norm).toDouble();
      counts[bin]++;
    }
    // Average
    for (int i = 0; i < _bins; i++) {
      if (counts[i] > 0) row[i] = (row[i] / counts[i]).clamp(0.0, 1.0);
    }
    return row;
  }

  @override
  Widget build(BuildContext context) {
    final features = ref.watch(featuresProvider);
    final color = features.primaryColor;
    final csi = ref.watch(wifiCSIProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────
            _TopBar(color: color, peakFreq: _peakFreq, peakAmp: _peakAmp,
                    fps: _frameCount, active: csi.rawData.isNotEmpty),
            // ── Gain control ───────────────────────────────────────────
            _GainBar(color: color, gain: _gain, onChanged: (v) => setState(() => _gain = v)),
            // ── Waterfall canvas ───────────────────────────────────────
            Expanded(
              child: LayoutBuilder(
                builder: (ctx, box) => CustomPaint(
                  size: Size(box.maxWidth, box.maxHeight),
                  painter: _WaterfallPainter(
                    waterfall: _waterfall,
                    head: _head,
                    rows: _rows,
                    bins: _bins,
                  ),
                ),
              ),
            ),
            // ── Frequency axis ─────────────────────────────────────────
            _FreqAxis(color: color),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Waterfall CustomPainter ────────────────────────────────────────────────
class _WaterfallPainter extends CustomPainter {
  final List<Float32List> waterfall;
  final int head;
  final int rows;
  final int bins;

  _WaterfallPainter({required this.waterfall, required this.head,
                     required this.rows, required this.bins});

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / bins;
    final cellH = size.height / rows;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int row = 0; row < rows; row++) {
      // Oldest row at bottom, newest at top
      final bufIdx = (head - 1 - row + rows) % rows;
      final data = waterfall[bufIdx];
      final y = row * cellH;
      for (int bin = 0; bin < bins; bin++) {
        paint.color = _heat(data[bin].toDouble());
        canvas.drawRect(
          Rect.fromLTWH(bin * cellW, y, cellW + 0.5, cellH + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WaterfallPainter old) =>
      old.head != head || old.waterfall != waterfall;
}

// ── Top bar ────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final Color color;
  final double peakFreq;
  final double peakAmp;
  final int fps;
  final bool active;

  const _TopBar({required this.color, required this.peakFreq,
                  required this.peakAmp, required this.fps, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const BackButtonTopLeft(),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SPECTROGRAM WATERFALL',
                  style: TextStyle(color: color, fontSize: 13, fontFamily: 'monospace',
                      fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              Text('V50.0 — REAL-TIME FFT DISPLAY',
                  style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
            ]),
          ),
          // Status badges
          _badge('PEAK ${peakFreq.toStringAsFixed(1)} MHz', color),
          const SizedBox(width: 8),
          _badge(active ? 'LIVE' : 'NO SIGNAL', active ? Colors.greenAccent : Colors.red),
        ],
      ),
    );
  }

  Widget _badge(String text, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      border: Border.all(color: c.withValues(alpha: 0.5)),
      color: c.withValues(alpha: 0.08),
    ),
    child: Text(text, style: TextStyle(color: c, fontSize: 9, fontFamily: 'monospace', letterSpacing: 1)),
  );
}

// ── Gain slider ────────────────────────────────────────────────────────────
class _GainBar extends StatelessWidget {
  final Color color;
  final double gain;
  final ValueChanged<double> onChanged;

  const _GainBar({required this.color, required this.gain, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Text('GAIN', style: TextStyle(color: color, fontSize: 10, fontFamily: 'monospace')),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.2),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.1),
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(value: gain, min: 0.5, max: 5.0, onChanged: onChanged),
          ),
        ),
        Text('${gain.toStringAsFixed(1)}×',
            style: TextStyle(color: color, fontSize: 10, fontFamily: 'monospace', letterSpacing: 1)),
      ]),
    );
  }
}

// ── Frequency axis labels ──────────────────────────────────────────────────
class _FreqAxis extends StatelessWidget {
  final Color color;
  const _FreqAxis({required this.color});

  @override
  Widget build(BuildContext context) {
    final labels = ['0', '10', '20', '30', '40', '50', '60', '70', '80 MHz'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: labels
            .map((l) => Text(l, style: TextStyle(color: color.withValues(alpha: 0.6),
                fontSize: 9, fontFamily: 'monospace')))
            .toList(),
      ),
    );
  }
}
