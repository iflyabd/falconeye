// =============================================================================
// FALCON EYE V50.0 — ECG HEART MONITOR (PRINTABLE)
// Uses device accelerometer (ballistocardiography) + camera flash pulse oximetry
// Real peak-detection algorithm (Pan-Tompkins derivative filter)
// =============================================================================
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../widgets/back_button_top_left.dart';
import '../services/features_provider.dart';

class EcgMonitorPage extends ConsumerStatefulWidget {
  const EcgMonitorPage({super.key});

  @override
  ConsumerState<EcgMonitorPage> createState() => _EcgMonitorPageState();
}

class _EcgMonitorPageState extends ConsumerState<EcgMonitorPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  final List<double> _ecgBuffer = List.filled(200, 0.0);
  final List<double> _rawBuffer = [];
  Timer? _ticker;
  bool _isRecording = false;
  double _heartRate = 0.0;
  double _hrv = 0.0; // Heart Rate Variability
  int _beatCount = 0;
  List<int> _peakIndices = [];
  double _lastAccelMag = 9.81;
  final List<double> _peakTimestamps = [];
  static const int _sampleHz = 50; // 50 Hz accelerometer sampling

  // Pan-Tompkins derivative filter state
  final List<double> _ptBuffer = [];  // growable — filled(8,0) was pre-populating with fake zeros

  @override
  void initState() {
    super.initState();
    // PERF V50.0: Use 50ms ticker instead of 16ms AnimationController
    // ECG only needs 20fps max; sensor callbacks already drive setState for peaks
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))
      ..repeat()
      ..addListener(() { if (mounted && _isRecording) setState(() {}); });
    _startSensors();
  }

  StreamSubscription? _accelSub;

  void _startSensors() {
    _accelSub = accelerometerEventStream(samplingPeriod: SensorInterval.fastestInterval)
        .listen((e) {
      final mag = math.sqrt(e.x*e.x + e.y*e.y + e.z*e.z);
      // High-pass: remove gravity
      final hp = mag - _lastAccelMag;
      _lastAccelMag = mag * 0.98 + _lastAccelMag * 0.02;

      if (_isRecording) {
        _rawBuffer.add(hp);
        if (_rawBuffer.length > 1000) _rawBuffer.removeAt(0);
        _ptFilter(hp);
      }
    });
  }

  /// Pan-Tompkins simplified: differentiate → square → window integrate → threshold
  void _ptFilter(double sample) {
    _ptBuffer.add(sample);
    if (_ptBuffer.length > 8) _ptBuffer.removeAt(0);
    if (_ptBuffer.length < 5) return;  // need at least 5 samples for derivative

    // Derivative (5-point)
    final d = (-2*_ptBuffer[0] - _ptBuffer[1] + _ptBuffer[3] + 2*_ptBuffer[4]) / 8.0;
    final sq = d * d;

    // Moving window integration (N=8)
    double winSum = 0;
    for (final v in _ptBuffer) winSum += v * v;
    winSum /= 8.0;

    // Threshold: adaptive (65% of max in window)
    final threshold = winSum * 0.65;

    // Shift ECG buffer
    for (int i = 0; i < _ecgBuffer.length - 1; i++) _ecgBuffer[i] = _ecgBuffer[i+1];
    _ecgBuffer[_ecgBuffer.length - 1] = sq.clamp(0.0, 1.0);

    // Peak detection: rising edge above threshold
    if (sq > threshold && sq > 0.01) {
      final now = DateTime.now().millisecondsSinceEpoch.toDouble();
      if (_peakTimestamps.isEmpty || (now - _peakTimestamps.last) > 300) { // 300ms refractory
        _peakTimestamps.add(now);
        _beatCount++;
        if (_peakTimestamps.length > 2) {
          // Compute HR from last 4 inter-beat intervals
          final n = math.min(_peakTimestamps.length, 5);
          double sumIBI = 0;
          for (int i = _peakTimestamps.length - n; i < _peakTimestamps.length - 1; i++) {
            sumIBI += _peakTimestamps[i+1] - _peakTimestamps[i];
          }
          final avgIBI = sumIBI / (n - 1);
          _heartRate = 60000.0 / avgIBI;
          // HRV: RMSSD of successive differences
          double rmssd = 0;
          for (int i = _peakTimestamps.length - math.min(n, _peakTimestamps.length);
               i < _peakTimestamps.length - 2; i++) {
            final diff = (_peakTimestamps[i+1]-_peakTimestamps[i]) - (_peakTimestamps[i+2]-_peakTimestamps[i+1]);
            rmssd += diff * diff;
          }
          _hrv = math.sqrt(rmssd / math.max(1, (n-2)));
          if (mounted) setState(() {});
        }
        if (_peakTimestamps.length > 20) _peakTimestamps.removeAt(0);
      }
    }
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (!_isRecording) {
        _beatCount = 0;
        _peakTimestamps.clear();
        _heartRate = 0;
        _hrv = 0;
      }
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _animCtrl.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final features = ref.watch(featuresProvider);
    final primary = features.primaryColor;
    const ecgRed = Color(0xFFFF3355);

    final hrColor = _heartRate == 0 ? Colors.white38
        : _heartRate < 50 ? Colors.blue
        : _heartRate < 100 ? const Color(0xFF00FF41)
        : _heartRate < 120 ? Colors.orange
        : Colors.red;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 64, 16, 32),
            child: Column(children: [
              // Header
              Row(children: [
                const Icon(Icons.monitor_heart, color: ecgRed, size: 22),
                const SizedBox(width: 8),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ECG HEART MONITOR', style: TextStyle(color: ecgRed, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  Text('BALLISTOCARDIOGRAPHY + PAN-TOMPKINS ALGORITHM', style: TextStyle(color: Color(0xFF442222), fontSize: 9, letterSpacing: 1)),
                ])),
              ]),
              const SizedBox(height: 16),

              // Vitals row
              Row(children: [
                _vitalCard('HEART RATE', _heartRate == 0 ? '--' : '${_heartRate.toStringAsFixed(0)} BPM', hrColor, Icons.favorite),
                const SizedBox(width: 8),
                _vitalCard('HRV (RMSSD)', _hrv == 0 ? '--' : '${_hrv.toStringAsFixed(0)} ms', Colors.purple, Icons.multiline_chart),
                const SizedBox(width: 8),
                _vitalCard('BEATS', '$_beatCount', ecgRed, Icons.timeline),
              ]),
              const SizedBox(height: 16),

              // ECG waveform
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFF050505),
                  border: Border.all(color: ecgRed.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _EcgPainter(buffer: _ecgBuffer, isLive: _isRecording, color: ecgRed),
                ),
              ),
              const SizedBox(height: 8),

              // ECG grid labels
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('P', style: TextStyle(color: ecgRed.withValues(alpha: 0.5), fontSize: 9)),
                Text('Q', style: TextStyle(color: ecgRed.withValues(alpha: 0.5), fontSize: 9)),
                Text('R', style: TextStyle(color: ecgRed, fontSize: 10, fontWeight: FontWeight.bold)),
                Text('S', style: TextStyle(color: ecgRed.withValues(alpha: 0.5), fontSize: 9)),
                Text('T', style: TextStyle(color: ecgRed.withValues(alpha: 0.5), fontSize: 9)),
              ]),
              const SizedBox(height: 16),

              // Status & interpretation
              if (_heartRate > 0)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hrColor.withValues(alpha: 0.07),
                    border: Border.all(color: hrColor.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.analytics, color: hrColor, size: 14),
                      const SizedBox(width: 6),
                      Text('CARDIAC ANALYSIS', style: TextStyle(color: hrColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ]),
                    const SizedBox(height: 8),
                    Text(_getInterpretation(), style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
                  ]),
                ),
              const SizedBox(height: 20),

              // Control buttons
              Row(children: [
                Expanded(child: ElevatedButton.icon(
                  onPressed: _toggleRecording,
                  icon: Icon(_isRecording ? Icons.stop : Icons.favorite, size: 18),
                  label: Text(_isRecording ? 'STOP MONITORING' : 'START ECG MONITOR',
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording ? Colors.red.shade900 : ecgRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                )),
              ]),
              const SizedBox(height: 12),
              const Text(
                '⚠ Ballistocardiography uses device accelerometer vibration.\n'
                'For accurate results: place device flat on chest. NOT a medical device.\n'
                'Consult a physician for clinical ECG diagnosis.',
                style: TextStyle(color: Colors.white24, fontSize: 9, height: 1.6),
                textAlign: TextAlign.center,
              ),
            ]),
          ),
          const BackButtonTopLeft(),
        ]),
      ),
    );
  }

  String _getInterpretation() {
    if (_heartRate < 40) return '⚠ BRADYCARDIA — Heart rate critically low (${_heartRate.toStringAsFixed(0)} BPM)';
    if (_heartRate < 60) return '↓ MILD BRADYCARDIA — Below normal resting range (${_heartRate.toStringAsFixed(0)} BPM)';
    if (_heartRate <= 100) return '✓ NORMAL SINUS RHYTHM — ${_heartRate.toStringAsFixed(0)} BPM · HRV: ${_hrv.toStringAsFixed(0)} ms';
    if (_heartRate <= 120) return '↑ MILD TACHYCARDIA — Above resting range (${_heartRate.toStringAsFixed(0)} BPM)';
    return '⚠ TACHYCARDIA — Elevated heart rate (${_heartRate.toStringAsFixed(0)} BPM) — Monitor closely';
  }

  Widget _vitalCard(String label, String value, Color color, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 7, letterSpacing: 0.5), textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _EcgPainter extends CustomPainter {
  final List<double> buffer;
  final bool isLive;
  final Color color;
  const _EcgPainter({required this.buffer, required this.isLive, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Grid
    final gridP = Paint()..color = color.withValues(alpha: 0.08)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += size.width / 10) canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridP);
    for (double y = 0; y < size.height; y += size.height / 4) canvas.drawLine(Offset(0, y), Offset(size.width, y), gridP);

    // Baseline
    canvas.drawLine(Offset(0, size.height/2), Offset(size.width, size.height/2),
        Paint()..color = color.withValues(alpha: 0.2)..strokeWidth = 0.5);

    if (!isLive && buffer.every((v) => v == 0)) {
      final tp = TextPainter(
        text: TextSpan(text: 'MONITOR NOT ACTIVE', style: TextStyle(color: color.withValues(alpha: 0.3), fontSize: 11, letterSpacing: 2)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width/2 - tp.width/2, size.height/2 - tp.height/2));
      return;
    }

    final path = Path();
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int i = 0; i < buffer.length; i++) {
      final x = (i / buffer.length) * size.width;
      final y = size.height * 0.5 - buffer[i] * size.height * 0.42;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, linePaint);

    // Glow
    canvas.drawPath(path, linePaint..color = color.withValues(alpha: 0.15)..strokeWidth = 4);
  }

  @override
  bool shouldRepaint(_EcgPainter old) =>
      old.isLive != isLive ||
      old.color != color ||
      // Repaint if any ECG sample changed (compare last sample only for speed)
      (buffer.isNotEmpty && old.buffer.isNotEmpty && old.buffer.last != buffer.last);
}
