import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/falcon_side_panel.dart';
import '../widgets/back_button_top_left.dart';
import '../services/bio_tomography_service.dart';
import '../services/features_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  FALCON EYE V48.1 — PLANET HEALTH 3.0 BIO-SIGNAL TOMOGRAPHY
//  FFT on Wi-Fi CSI → respiration (0.2-0.5 Hz) + heart rate (1.0-1.5 Hz)
//  3D human mesh with pulsing heart, neural-flow lines, skeletal wireframe
// ═══════════════════════════════════════════════════════════════════════════════

class PlanetHealthPage extends ConsumerStatefulWidget {
  const PlanetHealthPage({super.key});

  @override
  ConsumerState<PlanetHealthPage> createState() => _PlanetHealthPageState();
}

class _PlanetHealthPageState extends ConsumerState<PlanetHealthPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _neuralCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _neuralCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bioTomographyProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _neuralCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bio = ref.watch(bioTomographyProvider);
    final features = ref.watch(featuresProvider);
    final primary = features.primaryColor;

    final entity = bio.entities.isNotEmpty ? bio.entities.first : null;
    final heartRate = entity?.heartRate ?? 0.0;
    final respRate = entity?.respirationRate ?? 0.0;
    final bodyTemp = entity?.bodyTemp ?? 36.5;
    final confidence = entity?.confidence ?? 0.0;

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ─────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(48, 16, 16, 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: primary.withValues(alpha: 0.3), width: 1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PLANET HEALTH 3.0',
                                style: TextStyle(color: primary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
                            Text('BIO-SIGNAL TOMOGRAPHY V50.0  •  FFT ENGINE',
                                style: TextStyle(color: primary.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 1)),
                          ],
                        ),
                        _statusBadge(bio.isActive ? 'SCANNING' : 'IDLE', bio.isActive ? primary : Colors.orange),
                      ],
                    ),
                  ),

                  // ── 3D Human Hologram with Bio Overlays ────────────────
                  SizedBox(
                    height: 420,
                    child: Stack(
                      children: [
                        // Human hologram painter
                        AnimatedBuilder(
                          animation: _neuralCtrl,
                          builder: (ctx, _) {
                            return CustomPaint(
                              size: Size.infinite,
                              painter: _BioTomographyPainter(
                                time: _neuralCtrl.value * 6,
                                heartRate: heartRate,
                                respirationRate: respRate,
                                confidence: confidence,
                                primaryColor: primary,
                                pulseValue: _pulseCtrl.value,
                              ),
                            );
                          },
                        ),
                        // Gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0, 0.15, 0.85, 1],
                              colors: [
                                Colors.black.withValues(alpha: 0.6),
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                        ),
                        // Top-left HUD info
                        Positioned(
                          top: 12, left: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _hudLine('STATUS', bio.status, primary),
                              _hudLine('FFT_WINDOW', '${bio.fftWindowSize} samples', primary),
                              _hudLine('CSI_RATE', '${bio.csiSampleRate.toStringAsFixed(0)} Hz', primary),
                              _hudLine('SENSITIVITY', '${bio.sensitivityGain.toStringAsFixed(1)}x', primary),
                            ],
                          ),
                        ),
                        // Center crosshair
                        Center(
                          child: Opacity(
                            opacity: 0.2,
                            child: Container(
                              width: 180, height: 180,
                              decoration: BoxDecoration(
                                border: Border.all(color: primary),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(width: 2, height: 40, color: primary),
                                  Container(width: 40, height: 2, color: primary),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Real-time Biometric Readings ───────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('REAL-TIME BIOMETRIC PROXIES',
                            style: TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _bioMetric(Icons.favorite, 'HEART RATE',
                                heartRate > 0 ? '${heartRate.toStringAsFixed(0)} BPM' : '-- BPM',
                                const Color(0xFFFF4444), primary),
                            const SizedBox(width: 10),
                            _bioMetric(Icons.air, 'RESPIRATION',
                                respRate > 0 ? '${respRate.toStringAsFixed(0)} BPM' : '-- BPM',
                                const Color(0xFF0088FF), primary),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _bioMetric(Icons.thermostat, 'BODY TEMP',
                                '${bodyTemp.toStringAsFixed(1)} °C',
                                const Color(0xFFFFAA00), primary),
                            const SizedBox(width: 10),
                            _bioMetric(Icons.track_changes, 'CONFIDENCE',
                                '${(confidence * 100).toStringAsFixed(0)}%',
                                primary, primary),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── FFT Frequency Spectrum ─────────────────────────────
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF050808),
                      border: Border.all(color: primary.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.graphic_eq, color: primary, size: 16),
                            const SizedBox(width: 8),
                            Text('FFT FREQUENCY SPECTRUM', style: TextStyle(color: primary, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Respiration band
                        _bandSection('RESPIRATION BAND (0.2-0.5 Hz)', bio.respirationBands, const Color(0xFF0088FF)),
                        const SizedBox(height: 8),
                        // Heart rate band
                        _bandSection('HEART RATE BAND (1.0-1.5 Hz)', bio.heartRateBands, const Color(0xFFFF4444)),
                      ],
                    ),
                  ),

                  // ── CSI Raw Waveform ───────────────────────────────────
                  if (bio.rawCsiBuffer.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF050808),
                        border: Border.all(color: primary.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('RAW CSI WAVEFORM', style: TextStyle(color: primary, fontSize: 10, letterSpacing: 2)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 80,
                            child: CustomPaint(
                              size: const Size(double.infinity, 80),
                              painter: _WaveformBufferPainter(
                                buffer: bio.rawCsiBuffer,
                                color: primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Controls ────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Sensitivity slider
                        Row(
                          children: [
                            Text('FFT SENSITIVITY:', style: TextStyle(color: primary.withValues(alpha: 0.6), fontSize: 10, letterSpacing: 1)),
                            Expanded(
                              child: Slider(
                                value: bio.sensitivityGain,
                                min: 0.1, max: 5.0, divisions: 49,
                                activeColor: primary,
                                inactiveColor: primary.withValues(alpha: 0.15),
                                onChanged: (v) => ref.read(bioTomographyProvider.notifier).setSensitivity(v),
                              ),
                            ),
                            Text('${bio.sensitivityGain.toStringAsFixed(1)}x',
                                style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        // Window size
                        Row(
                          children: [
                            Text('FFT WINDOW:', style: TextStyle(color: primary.withValues(alpha: 0.6), fontSize: 10, letterSpacing: 1)),
                            Expanded(
                              child: Slider(
                                value: bio.fftWindowSize.toDouble(),
                                min: 64, max: 1024, divisions: 15,
                                activeColor: primary,
                                inactiveColor: primary.withValues(alpha: 0.15),
                                onChanged: (v) => ref.read(bioTomographyProvider.notifier).setFFTWindowSize(v.round()),
                              ),
                            ),
                            Text('${bio.fftWindowSize}',
                                style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Start/Stop
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  if (bio.isActive) {
                                    ref.read(bioTomographyProvider.notifier).stop();
                                  } else {
                                    ref.read(bioTomographyProvider.notifier).start();
                                  }
                                },
                                icon: Icon(bio.isActive ? Icons.stop : Icons.radar, size: 18),
                                label: Text(bio.isActive ? 'STOP TOMOGRAPHY' : 'INITIALIZE FULL TOMOGRAPHY',
                                    style: const TextStyle(letterSpacing: 1, fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: bio.isActive ? Colors.red.withValues(alpha: 0.3) : primary,
                                  foregroundColor: bio.isActive ? Colors.red : Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── V48.1: ADVANCED BIO-SCANNER TOOLS ────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          Icon(Icons.biotech, color: primary, size: 14),
                          const SizedBox(width: 6),
                          Text('ADVANCED BIO-SCANNER TOOLS',
                              style: TextStyle(color: primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        ]),
                      ),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.8,
                        children: [
                          _scannerTileBtn(context, Icons.biotech, 'X-RAY\nBONE SCANNER', const Color(0xFF00E5FF), '/xray_scanner'),
                          _scannerTileBtn(context, Icons.monitor_heart, 'ECG\nHEART MONITOR', const Color(0xFFFF3355), '/ecg_monitor'),
                          _scannerTileBtn(context, Icons.accessibility_new, 'FULL BODY\nSCANNER', const Color(0xFF00FFFF), '/full_body_scanner'),
                          _scannerTileBtn(context, Icons.bloodtype, 'RAW SIGINT\nBIO-STREAM', const Color(0xFFFF6600), '/raw_sigint'),
                        ],
                      ),
                    ]),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            const BackButtonTopLeft(),
            const FalconPanelTrigger(top: 90),
          ],
        ),
      ),
    );

  }

  Widget _scannerTileBtn(BuildContext context, IconData icon, String label, Color color, String route) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5, height: 1.4))),
        ]),
      ),
    );
  }

  Widget _statusBadge(String label, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        border: Border.all(color: c.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
    );
  }

  Widget _hudLine(String label, String value, Color c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(color: c.withValues(alpha: 0.4), fontSize: 9, fontFamily: 'monospace')),
          Text(value, style: TextStyle(color: c, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _bioMetric(IconData icon, String label, String value, Color accent, Color primary) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.05),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: accent, size: 18),
                Text(value, style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: primary.withValues(alpha: 0.5), fontSize: 9, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _bandSection(String title, List<FFTBand> bands, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 8, letterSpacing: 1)),
        const SizedBox(height: 4),
        SizedBox(
          height: 50,
          child: bands.isEmpty
              ? Center(child: Text('Collecting data...', style: TextStyle(color: color.withValues(alpha: 0.3), fontSize: 9)))
              : Row(
                  children: bands.take(20).map((b) {
                    final h = (b.magnitude * 5000).clamp(2.0, 48.0);
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  BIO-TOMOGRAPHY 3D PAINTER
//  Renders transparent human mesh, pulsing heart, neural flow, skeletal X-ray
// ═══════════════════════════════════════════════════════════════════════════════
class _BioTomographyPainter extends CustomPainter {
  final double time;
  final double heartRate;
  final double respirationRate;
  final double confidence;
  final Color primaryColor;
  final double pulseValue;

  _BioTomographyPainter({
    required this.time,
    required this.heartRate,
    required this.respirationRate,
    required this.confidence,
    required this.primaryColor,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.height * 0.35;

    // Background grid
    final gridP = Paint()..color = primaryColor.withValues(alpha: 0.03)..strokeWidth = 0.3;
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridP);
    }
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridP);
    }

    // Transparent human mesh (cyan wireframe)
    final meshP = Paint()
      ..color = const Color(0xFF00AAFF).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Head
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - scale * 0.75), width: scale * 0.28, height: scale * 0.32),
      meshP,
    );

    // Neck
    canvas.drawLine(Offset(cx, cy - scale * 0.59), Offset(cx, cy - scale * 0.48), meshP);

    // Shoulders
    canvas.drawLine(Offset(cx - scale * 0.32, cy - scale * 0.45), Offset(cx + scale * 0.32, cy - scale * 0.45), meshP);

    // Torso (rectangle outline)
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy - scale * 0.12), width: scale * 0.52, height: scale * 0.65),
      meshP,
    );

    // Arms
    canvas.drawLine(Offset(cx - scale * 0.32, cy - scale * 0.45), Offset(cx - scale * 0.42, cy + scale * 0.15), meshP);
    canvas.drawLine(Offset(cx + scale * 0.32, cy - scale * 0.45), Offset(cx + scale * 0.42, cy + scale * 0.15), meshP);

    // Legs
    canvas.drawLine(Offset(cx - scale * 0.12, cy + scale * 0.2), Offset(cx - scale * 0.18, cy + scale * 0.85), meshP);
    canvas.drawLine(Offset(cx + scale * 0.12, cy + scale * 0.2), Offset(cx + scale * 0.18, cy + scale * 0.85), meshP);

    // ── Pulsing Red Heart ───────────────────────────────────────────
    if (heartRate > 0) {
      final heartCx = cx - scale * 0.05;
      final heartCy = cy - scale * 0.28;
      final pulse = 0.7 + 0.3 * pulseValue;
      final heartR = scale * 0.06 * pulse;

      // Glow
      canvas.drawCircle(
        Offset(heartCx, heartCy), heartR * 3,
        Paint()..color = const Color(0xFFFF0000).withValues(alpha: 0.08 * pulse)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      // Heart shape
      canvas.drawCircle(
        Offset(heartCx, heartCy), heartR,
        Paint()..color = Color.lerp(const Color(0xFFFF0000), const Color(0xFFFF4444), pulseValue)!.withValues(alpha: 0.7),
      );
      // BPM label
      _drawText(canvas, '${heartRate.toStringAsFixed(0)} BPM', heartCx + scale * 0.12, heartCy - 6, const Color(0xFFFF4444), 9);
    }

    // ── Blue Neural-flow lines ──────────────────────────────────────
    final neuralP = Paint()
      ..color = const Color(0xFF00CCFF).withValues(alpha: 0.12)
      ..strokeWidth = 0.8;

    // Spine neural flow
    for (int i = 0; i < 8; i++) {
      final ny = cy - scale * 0.5 + i * scale * 0.1;
      final offset = math.sin(time * 2 + i * 0.8) * scale * 0.04;
      canvas.drawLine(
        Offset(cx + offset, ny),
        Offset(cx + offset + scale * 0.15, ny + scale * 0.02),
        neuralP,
      );
      canvas.drawLine(
        Offset(cx + offset, ny),
        Offset(cx + offset - scale * 0.15, ny + scale * 0.02),
        neuralP,
      );
    }

    // Flowing particles along neural paths
    final particleP = Paint()..color = const Color(0xFF00FFFF).withValues(alpha: 0.3);
    for (int i = 0; i < 12; i++) {
      final t = (time * 0.5 + i * 0.15) % 1.0;
      final py = cy - scale * 0.7 + t * scale * 1.5;
      final px = cx + math.sin(time * 3 + i) * scale * 0.05;
      canvas.drawCircle(Offset(px, py), 1.5, particleP);
    }

    // ── Skeletal wireframe (X-ray effect) ───────────────────────────
    final skelP = Paint()
      ..color = const Color(0xFF88CCFF).withValues(alpha: 0.06)
      ..strokeWidth = 2;

    // Spine
    canvas.drawLine(Offset(cx, cy - scale * 0.55), Offset(cx, cy + scale * 0.2), skelP);

    // Ribs
    for (int r = 0; r < 5; r++) {
      final ry = cy - scale * (0.4 - r * 0.1);
      canvas.drawLine(
        Offset(cx, ry),
        Offset(cx - scale * 0.22, ry + scale * 0.04),
        skelP,
      );
      canvas.drawLine(
        Offset(cx, ry),
        Offset(cx + scale * 0.22, ry + scale * 0.04),
        skelP,
      );
    }

    // Pelvis
    canvas.drawLine(Offset(cx - scale * 0.15, cy + scale * 0.18), Offset(cx + scale * 0.15, cy + scale * 0.18), skelP);

    // ── Respiration wave ────────────────────────────────────────────
    if (respirationRate > 0) {
      final breathP = Paint()
        ..color = const Color(0xFF0088FF).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      final path = Path();
      final breathCy = cy - scale * 0.1;
      for (double t = -scale * 0.2; t <= scale * 0.2; t += 1) {
        final bx = cx + t;
        final by = breathCy + math.sin(time * 2 + t * 0.08) * scale * 0.04;
        if (t == -scale * 0.2) {
          path.moveTo(bx, by);
        } else {
          path.lineTo(bx, by);
        }
      }
      canvas.drawPath(path, breathP);
      _drawText(canvas, '${respirationRate.toStringAsFixed(0)} br/min', cx + scale * 0.25, breathCy - 6, const Color(0xFF0088FF), 9);
    }

    // ── Scan sweep ──────────────────────────────────────────────────
    final sweepY = (time * 0.3 % 1.0) * size.height;
    canvas.drawLine(
      Offset(0, sweepY), Offset(size.width, sweepY),
      Paint()..color = primaryColor.withValues(alpha: 0.06)..strokeWidth = 2,
    );
  }

  void _drawText(Canvas canvas, String text, double x, double y, Color color, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(_BioTomographyPainter old) =>
      (old.time - time).abs() > 0.008 ||
      old.heartRate != heartRate ||
      old.respirationRate != respirationRate ||
      old.confidence != confidence;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CSI Waveform buffer painter
// ═══════════════════════════════════════════════════════════════════════════════
class _WaveformBufferPainter extends CustomPainter {
  final List<double> buffer;
  final Color color;

  _WaveformBufferPainter({required this.buffer, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (buffer.isEmpty) return;
    final cy = size.height / 2;
    final path = Path();
    final stepX = size.width / buffer.length;

    for (int i = 0; i < buffer.length; i++) {
      final x = i * stepX;
      final y = cy - buffer[i] * size.height * 5;
      if (i == 0) {
        path.moveTo(x, y.clamp(0, size.height));
      } else {
        path.lineTo(x, y.clamp(0, size.height));
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Zero line
    canvas.drawLine(
      Offset(0, cy), Offset(size.width, cy),
      Paint()..color = color.withValues(alpha: 0.1)..strokeWidth = 0.5,
    );
  }

  @override
  bool shouldRepaint(_WaveformBufferPainter old) =>
      old.buffer.length != buffer.length ||
      (old.buffer.isNotEmpty && buffer.isNotEmpty && old.buffer.last != buffer.last) ||
      old.color != color;
}
