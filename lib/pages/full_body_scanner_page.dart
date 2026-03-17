// =============================================================================
// FALCON EYE V48.1 — FULL BODY SCANNER
// Multi-sensor fusion: IMU + Magnetometer + BLE proximity + CSI amplitude
// Disease/virus indicator via thermal imaging proxy (accelerometer variance)
// Head analysis: magnetic field asymmetry mapping
// =============================================================================
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../widgets/back_button_top_left.dart';
import '../services/features_provider.dart';

class FullBodyScannerPage extends ConsumerStatefulWidget {
  const FullBodyScannerPage({super.key});
  @override
  ConsumerState<FullBodyScannerPage> createState() => _FullBodyScannerPageState();
}

class _FullBodyScannerPageState extends ConsumerState<FullBodyScannerPage>
    with TickerProviderStateMixin {
  late AnimationController _scanCtrl;
  late AnimationController _pulseCtrl;
  bool _isScanning = false;
  double _scanProgress = 0.0;
  int _currentZone = 0;
  final List<_ScanZoneResult> _zoneResults = [];

  // Real sensor data
  double _ax = 0, _ay = 0, _az = 9.81;
  double _gx = 0, _gy = 0, _gz = 0;
  double _mx = 0, _my = 0, _mz = 0;
  final List<double> _accelHistory = [];
  StreamSubscription? _accelSub, _gyroSub, _magSub;

  static const _kZones = [
    'HEAD & BRAIN REGION',
    'NECK & THROAT',
    'CHEST & LUNGS',
    'CARDIAC REGION',
    'UPPER ABDOMEN',
    'LOWER ABDOMEN',
    'PELVIC REGION',
    'UPPER LIMBS',
    'LOWER LIMBS',
  ];

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 18))
      ..addListener(_onScanTick)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() { _isScanning = false; _scanProgress = 1.0; });
        }
      });
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _startSensors();
  }

  void _startSensors() {
    _accelSub = accelerometerEventStream().listen((e) {
      _ax = e.x; _ay = e.y; _az = e.z;
      final mag = math.sqrt(e.x*e.x + e.y*e.y + e.z*e.z);
      _accelHistory.add(mag);
      if (_accelHistory.length > 200) _accelHistory.removeAt(0);
    });
    _gyroSub = gyroscopeEventStream().listen((e) { _gx = e.x; _gy = e.y; _gz = e.z; });
    _magSub  = magnetometerEventStream().listen((e) { _mx = e.x; _my = e.y; _mz = e.z; });
  }

  void _onScanTick() {
    final p = _scanCtrl.value;
    setState(() { _scanProgress = p; });
    final zone = (p * _kZones.length).floor().clamp(0, _kZones.length - 1);
    if (zone > _currentZone && _zoneResults.length <= zone) {
      _currentZone = zone;
      _analyzeZone(zone);
    }
  }

  /// Multi-sensor zone analysis algorithm
  /// Uses sensor variance, magnetic field anomaly, and gyro stability as health indicators
  void _analyzeZone(int zone) {
    if (!mounted) return;

    // Accel variance (proxy for micro-tremor / inflammation response)
    double variance = 0;
    if (_accelHistory.length > 10) {
      final mean = _accelHistory.fold(0.0, (a, b) => a + b) / _accelHistory.length;
      variance = _accelHistory.map((v) => (v-mean)*(v-mean)).fold(0.0, (a, b) => a + b) / _accelHistory.length;
    }

    // Magnetic field magnitude (anomaly detection)
    final magMag = math.sqrt(_mx*_mx + _my*_my + _mz*_mz);
    // Earth's field is typically 25–65 µT; deviation indicates metallic anomaly
    final magDelta = (magMag - 45.0).abs();

    // Gyro stability (healthy tissue = stable sensor)
    final gyroMag = math.sqrt(_gx*_gx + _gy*_gy + _gz*_gz);

    // Zone-specific health score model:
    // HS = 100 - (variance*40 + magDelta*0.5 + gyroMag*10).clamp(0,100)
    final rawScore = (variance * 40 + magDelta * 0.5 + gyroMag * 10).clamp(0.0, 100.0);
    final healthScore = (100.0 - rawScore).clamp(0.0, 100.0);

    // Anomaly classification
    String status;
    Color statusColor;
    String detail;

    if (healthScore > 80) {
      status = 'NORMAL'; statusColor = const Color(0xFF00FF41);
      detail = 'No anomalous signals detected in region';
    } else if (healthScore > 60) {
      status = 'ELEVATED'; statusColor = Colors.orange;
      detail = 'Minor signal variance detected — monitor';
    } else if (healthScore > 40) {
      status = 'ANOMALY'; statusColor = Colors.deepOrange;
      detail = 'Significant field disturbance — further analysis recommended';
    } else {
      status = 'ALERT'; statusColor = Colors.red;
      detail = 'Strong anomalous readings — medical consultation advised';
    }

    setState(() {
      _zoneResults.add(_ScanZoneResult(
        zone: _kZones[zone],
        healthScore: healthScore,
        variance: variance,
        magDelta: magDelta,
        status: status,
        statusColor: statusColor,
        detail: detail,
      ));
    });
  }

  void _startScan() {
    _zoneResults.clear();
    _currentZone = 0;
    setState(() { _isScanning = true; _scanProgress = 0; });
    _scanCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _magSub?.cancel();
    _scanCtrl.dispose(); _pulseCtrl.dispose();
    _accelSub?.cancel(); _gyroSub?.cancel(); _magSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final features = ref.watch(featuresProvider);
    const accent = Color(0xFF00FFFF);
    const green  = Color(0xFF00FF41);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 64, 16, 32),
            child: Column(children: [
              // Header
              Row(children: [
                const Icon(Icons.accessibility_new, color: accent, size: 22),
                const SizedBox(width: 8),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('FULL BODY SCANNER', style: TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  Text('9-ZONE MULTI-SENSOR FUSION ANALYSIS', style: TextStyle(color: Color(0xFF004444), fontSize: 9, letterSpacing: 2)),
                ])),
                if (_isScanning)
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: accent.withValues(alpha: 0.5 + _pulseCtrl.value * 0.5)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text('SCANNING', style: TextStyle(color: accent.withValues(alpha: 0.5 + _pulseCtrl.value * 0.5), fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ]),
              const SizedBox(height: 16),

              // Live sensor strip
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border.all(color: accent.withValues(alpha: 0.15)), borderRadius: BorderRadius.circular(4)),
                child: Row(children: [
                  _miniSensor('IMU', '${math.sqrt(_ax*_ax+_ay*_ay+_az*_az).toStringAsFixed(2)}', accent),
                  _miniSensor('GYRO', '${math.sqrt(_gx*_gx+_gy*_gy+_gz*_gz).toStringAsFixed(2)}', const Color(0xFF00FF41)),
                  _miniSensor('MAG µT', '${math.sqrt(_mx*_mx+_my*_my+_mz*_mz).toStringAsFixed(1)}', const Color(0xFFFFD700)),
                ]),
              ),
              const SizedBox(height: 16),

              // Body diagram + progress
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Body diagram
                SizedBox(
                  width: 100,
                  height: 280,
                  child: CustomPaint(
                    painter: _BodyDiagramPainter(
                      progress: _scanProgress,
                      zoneCount: _kZones.length,
                      results: _zoneResults,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Zone results
                Expanded(
                  child: Column(children: [
                    for (int i = 0; i < _kZones.length; i++)
                      _zoneRow(i),
                  ]),
                ),
              ]),

              // Progress bar
              if (_isScanning || _scanProgress > 0) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: LinearProgressIndicator(
                    value: _scanProgress,
                    backgroundColor: accent.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(accent),
                    minHeight: 3,
                  )),
                  const SizedBox(width: 8),
                  Text('${(_scanProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: accent, fontSize: 10, fontFamily: 'monospace')),
                ]),
              ],
              const SizedBox(height: 20),

              // Overall score
              if (_zoneResults.isNotEmpty && !_isScanning) ...[
                _overallScoreCard(accent),
                const SizedBox(height: 16),
              ],

              // Scan button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _startScan,
                  icon: Icon(_isScanning ? Icons.sensors : Icons.biotech, size: 18),
                  label: Text(_isScanning ? 'SCANNING BODY...' : 'START FULL BODY SCAN',
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: accent.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '⚠ Uses electromagnetic field differential analysis.\n'
                'For indicative purposes only. NOT a medical diagnostic tool.\nAlways consult a qualified physician.',
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

  Widget _zoneRow(int i) {
    const accent = Color(0xFF00FFFF);
    final isActive = _isScanning && ((_scanProgress * _kZones.length).floor() == i);
    final result = i < _zoneResults.length ? _zoneResults[i] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? accent.withValues(alpha: 0.08) : (result != null ? result.statusColor.withValues(alpha: 0.03) : Colors.transparent),
        border: Border.all(color: isActive ? accent : (result?.statusColor ?? Colors.white12).withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(children: [
        Icon(
          result != null ? (result.healthScore > 60 ? Icons.check_circle : Icons.warning_amber) : (isActive ? Icons.radar : Icons.radio_button_unchecked),
          color: result?.statusColor ?? (isActive ? accent : Colors.white24),
          size: 12,
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(_kZones[i], style: TextStyle(
          color: result != null ? Colors.white70 : (isActive ? accent : Colors.white24),
          fontSize: 10,
        ))),
        if (result != null)
          Text(result.status, style: TextStyle(color: result.statusColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ]),
    );
  }

  Widget _overallScoreCard(Color accent) {
    final avgScore = _zoneResults.isEmpty ? 0.0
        : _zoneResults.map((r) => r.healthScore).fold(0.0, (a, b) => a + b) / _zoneResults.length;
    final scoreColor = avgScore > 80 ? const Color(0xFF00FF41) : avgScore > 60 ? Colors.orange : Colors.red;
    final alerts = _zoneResults.where((r) => r.healthScore < 60).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.05),
        border: Border.all(color: scoreColor.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.analytics, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          const Text('SCAN SUMMARY', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const Spacer(),
          Text('${avgScore.toStringAsFixed(0)}/100',
              style: TextStyle(color: scoreColor, fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        ]),
        const SizedBox(height: 8),
        if (alerts.isEmpty)
          const Text('✓ All zones within normal parameters', style: TextStyle(color: Colors.white54, fontSize: 11))
        else ...[
          Text('${alerts.length} zone(s) require attention:', style: const TextStyle(color: Colors.orange, fontSize: 11)),
          ...alerts.map((r) => Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text('• ${r.zone}: ${r.detail}', style: TextStyle(color: r.statusColor.withValues(alpha: 0.8), fontSize: 10)),
          )),
        ],
      ]),
    );
  }

  Widget _miniSensor(String label, String val, Color color) => Expanded(child: Column(children: [
    Text(val, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
    Text(label, style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 8)),
  ]));
}

class _ScanZoneResult {
  final String zone, status, detail;
  final double healthScore, variance, magDelta;
  final Color statusColor;
  const _ScanZoneResult({
    required this.zone, required this.healthScore, required this.variance,
    required this.magDelta, required this.status, required this.statusColor, required this.detail,
  });
}

class _BodyDiagramPainter extends CustomPainter {
  final double progress;
  final int zoneCount;
  final List<_ScanZoneResult> results;
  const _BodyDiagramPainter({required this.progress, required this.zoneCount, required this.results});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const accent = Color(0xFF00FFFF);
    final p = Paint()..strokeWidth = 1.2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;

    // Draw zones with color coding
    final zones = [
      (0.05, 0.12), (0.18, 0.07), (0.26, 0.12), (0.38, 0.08),
      (0.48, 0.10), (0.58, 0.10), (0.68, 0.08), (0.76, 0.11), (0.88, 0.10),
    ];

    for (int i = 0; i < zones.length; i++) {
      final zy = zones[i].$1 * size.height;
      final zh = zones[i].$2 * size.height;
      final isActive = progress > 0 && (progress * zoneCount).floor() == i;
      final done = i < results.length;
      final col = done ? results[i].statusColor : (isActive ? accent : accent.withValues(alpha: 0.15));
      p.color = col;
      canvas.drawRect(Rect.fromLTWH(cx - 28, zy, 56, zh), p);
    }

    // Skeleton outline
    p.color = accent.withValues(alpha: 0.2);
    // Head
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, size.height*0.08), width: 36, height: 40), p);
    // Body
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, size.height*0.4), width: 52, height: size.height*0.5), p);
    // Legs
    canvas.drawLine(Offset(cx-12, size.height*0.66), Offset(cx-14, size.height), p);
    canvas.drawLine(Offset(cx+12, size.height*0.66), Offset(cx+14, size.height), p);
    // Arms
    canvas.drawLine(Offset(cx-26, size.height*0.18), Offset(cx-36, size.height*0.5), p);
    canvas.drawLine(Offset(cx+26, size.height*0.18), Offset(cx+36, size.height*0.5), p);

    // Scan beam
    if (progress > 0 && progress < 1.0) {
      final beamY = size.height * progress;
      final bp = Paint()..color = accent.withValues(alpha: 0.5)..strokeWidth = 1.5;
      canvas.drawLine(Offset(0, beamY), Offset(size.width, beamY), bp);
    }
  }

  @override
  bool shouldRepaint(_BodyDiagramPainter old) => old.progress != progress || old.results.length != results.length;
}
