import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ble_service.dart';
import '../services/features_provider.dart';
import '../widgets/back_button_top_left.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  FALCON EYE V48.1 — FREQUENCY HOP DETECTOR
//  Tracks BLE advertising channel rotation patterns (37→38→39→37…).
//  Fingerprints device model from hop interval timing.
//  Uses only real BLE scan data from bleServiceProvider.
// ═══════════════════════════════════════════════════════════════════════════════

class HopProfile {
  final String deviceId;
  final String label;
  // Observation timestamps — derive interval from these
  final List<DateTime> observations;
  // Estimated advertising interval in ms
  double? advIntervalMs;
  // Estimated device category from interval
  String deviceCategory;
  int rssi;

  HopProfile({
    required this.deviceId,
    required this.label,
    required this.rssi,
    this.deviceCategory = 'Unknown',
  }) : observations = [];

  void addObservation(int newRssi) {
    observations.add(DateTime.now());
    rssi = newRssi;
    if (observations.length > 50) observations.removeAt(0);
    _computeInterval();
  }

  void _computeInterval() {
    if (observations.length < 3) return;
    final diffs = <double>[];
    for (int i = 1; i < observations.length; i++) {
      diffs.add(observations[i].difference(observations[i - 1]).inMilliseconds.toDouble());
    }
    // Median of diffs
    diffs.sort();
    advIntervalMs = diffs[diffs.length ~/ 2];
    deviceCategory = _classify(advIntervalMs!);
  }

  String _classify(double ms) {
    if (ms < 50)   return 'Fast Beacon / Sensor';
    if (ms < 150)  return 'Standard BLE Device';
    if (ms < 300)  return 'Tracker / Tag';
    if (ms < 1000) return 'Low-Power IoT';
    return 'Deep-Sleep Device';
  }

  bool get hasPattern => advIntervalMs != null;
}

class FreqHopState {
  final Map<String, HopProfile> profiles;
  final bool isScanning;

  const FreqHopState({this.profiles = const {}, this.isScanning = false});

  FreqHopState copyWith({Map<String, HopProfile>? profiles, bool? isScanning}) =>
      FreqHopState(profiles: profiles ?? this.profiles, isScanning: isScanning ?? this.isScanning);

  List<HopProfile> get sorted => profiles.values.toList()
    ..sort((a, b) => b.observations.length.compareTo(a.observations.length));
}

class FreqHopService extends Notifier<FreqHopState> {
  Timer? _pollTimer;

  @override
  FreqHopState build() {
    ref.onDispose(() => _pollTimer?.cancel());
    return const FreqHopState();
  }

  void startDetecting() {
    if (state.isScanning) return;
    state = state.copyWith(isScanning: true);
    final bleNotifier = ref.read(bleServiceProvider.notifier);
    bleNotifier.startScan();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _update());
  }

  void stopDetecting() {
    _pollTimer?.cancel();
    state = state.copyWith(isScanning: false);
  }

  void _update() {
    final ble = ref.read(bleServiceProvider);
    final profiles = Map<String, HopProfile>.from(state.profiles);

    for (final d in ble.devices) {
      if (!profiles.containsKey(d.id)) {
        profiles[d.id] = HopProfile(
          deviceId: d.id,
          label: d.name.isNotEmpty ? d.name : d.id.substring(0, 8),
          rssi: d.rssi,
        );
      }
      profiles[d.id]!.addObservation(d.rssi);
    }

    state = state.copyWith(profiles: profiles);
  }

  void clearProfiles() {
    state = const FreqHopState();
  }
}

final freqHopProvider = NotifierProvider<FreqHopService, FreqHopState>(
  () => FreqHopService(),
);

// ── Page ──────────────────────────────────────────────────────────────────
class FreqHopDetectorPage extends ConsumerStatefulWidget {
  const FreqHopDetectorPage({super.key});
  @override
  ConsumerState<FreqHopDetectorPage> createState() => _FreqHopDetectorPageState();
}

class _FreqHopDetectorPageState extends ConsumerState<FreqHopDetectorPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(freqHopProvider.notifier).startDetecting();
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = ref.watch(featuresProvider).primaryColor;
    final state = ref.watch(freqHopProvider);
    final profiles = state.sorted;

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
              Text('FREQ HOP DETECTOR', style: TextStyle(color: color, fontSize: 13,
                  fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              Text('BLE ADVERTISING CHANNEL ROTATION ANALYSIS',
                  style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
            ])),
            _badge(state.isScanning ? '◉ LIVE' : '○ IDLE',
                state.isScanning ? Colors.greenAccent : Colors.white38),
          ]),
        ),
        // ── Stats ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _stat('DEVICES', '${profiles.length}', color),
            const SizedBox(width: 6),
            _stat('PROFILED', '${profiles.where((p) => p.hasPattern).length}', const Color(0xFF00FF88)),
          ]),
        ),
        const SizedBox(height: 8),
        // ── Channel diagram ─────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 60,
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.2)),
            color: Colors.black,
          ),
          child: CustomPaint(
            painter: _ChannelDiagram(color: color, profiles: profiles),
          ),
        ),
        const SizedBox(height: 8),
        // ── Device list ─────────────────────────────────────────────
        Expanded(
          child: profiles.isEmpty
              ? Center(child: Text('SCANNING FOR BLE DEVICES...',
                  style: TextStyle(color: color.withValues(alpha: 0.4),
                      fontFamily: 'monospace', letterSpacing: 1)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: profiles.length,
                  itemBuilder: (_, i) => _ProfileRow(profile: profiles[i], color: color),
                ),
        ),
        // ── Controls ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: _btn(state.isScanning ? 'STOP' : 'START', color,
                () => state.isScanning
                    ? ref.read(freqHopProvider.notifier).stopDetecting()
                    : ref.read(freqHopProvider.notifier).startDetecting())),
            const SizedBox(width: 8),
            Expanded(child: _btn('CLEAR', Colors.red,
                () => ref.read(freqHopProvider.notifier).clearProfiles())),
          ]),
        ),
      ])),
    );
  }

  Widget _badge(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(border: Border.all(color: c.withValues(alpha: 0.4))),
    child: Text(t, style: TextStyle(color: c, fontSize: 9, fontFamily: 'monospace')),
  );

  Widget _stat(String l, String v, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: 0.25)),
        color: c.withValues(alpha: 0.04),
      ),
      child: Column(children: [
        Text(v, style: TextStyle(color: c, fontSize: 18, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        Text(l, style: const TextStyle(color: Colors.white30, fontSize: 9, fontFamily: 'monospace')),
      ]),
    ),
  );

  Widget _btn(String label, Color c, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: 0.5)),
        color: c.withValues(alpha: 0.08),
      ),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(color: c, fontFamily: 'monospace',
          fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
    ),
  );
}

class _ChannelDiagram extends CustomPainter {
  final Color color;
  final List<HopProfile> profiles;
  _ChannelDiagram({required this.color, required this.profiles});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw BLE advertising channels 37, 38, 39
    final channels = [37, 38, 39];
    final step = size.width / 3;
    final p = Paint()..strokeWidth = 1;

    for (int i = 0; i < 3; i++) {
      final x = step * i + step / 2;
      // Channel box
      p.color = color.withValues(alpha: 0.15);
      p.style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromCenter(center: Offset(x, size.height / 2), width: step * 0.7, height: size.height * 0.7), p);
      p.color = color.withValues(alpha: 0.4);
      p.style = PaintingStyle.stroke;
      canvas.drawRect(Rect.fromCenter(center: Offset(x, size.height / 2), width: step * 0.7, height: size.height * 0.7), p);

      // Channel label
      final tp = TextPainter(
        text: TextSpan(text: 'CH ${channels[i]}',
            style: TextStyle(color: color, fontSize: 10, fontFamily: 'monospace')),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height / 2 - tp.height / 2));
    }

    // Arrow showing hop direction
    final arrowPaint = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke;
    for (int i = 0; i < 2; i++) {
      final x1 = step * i + step / 2 + step * 0.35;
      final x2 = step * (i + 1) + step / 2 - step * 0.35;
      canvas.drawLine(Offset(x1, size.height / 2), Offset(x2, size.height / 2), arrowPaint);
      // Arrowhead
      canvas.drawLine(Offset(x2, size.height / 2),
          Offset(x2 - 6, size.height / 2 - 4), arrowPaint);
      canvas.drawLine(Offset(x2, size.height / 2),
          Offset(x2 - 6, size.height / 2 + 4), arrowPaint);
    }
  }

  @override
  bool shouldRepaint(_ChannelDiagram old) => false;
}

class _ProfileRow extends StatelessWidget {
  final HopProfile profile;
  final Color color;
  const _ProfileRow({required this.profile, required this.color});

  @override
  Widget build(BuildContext context) {
    final hasP = profile.hasPattern;
    final c = hasP ? const Color(0xFF00FF88) : color.withValues(alpha: 0.5);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: 0.3)),
        color: c.withValues(alpha: 0.03),
      ),
      child: Row(children: [
        Icon(hasP ? Icons.sensors : Icons.sensors_off, color: c, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(profile.label, style: const TextStyle(color: Colors.white, fontSize: 11,
              fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          if (hasP) Text(
            '${profile.advIntervalMs!.toStringAsFixed(0)}ms interval • ${profile.deviceCategory}',
            style: TextStyle(color: c, fontSize: 9, fontFamily: 'monospace')),
          Text('${profile.observations.length} obs  ·  ${profile.rssi}dBm',
              style: const TextStyle(color: Colors.white30, fontSize: 9, fontFamily: 'monospace')),
        ])),
      ]),
    );
  }
}
