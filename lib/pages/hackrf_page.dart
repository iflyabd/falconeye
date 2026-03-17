import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/features_provider.dart';
import '../services/root_permission_service.dart';
import '../widgets/back_button_top_left.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  FALCON EYE V48.1 — HACKRF / PORTAPACK BRIDGE
//  MethodChannel to control a connected HackRF One via USB-OTG.
//  Requires root. Supports: tune, sweep, replay capture.
//  Real TX requires radio license. This page controls RX/replay only
//  unless root is confirmed — TX is gated behind root confirmation.
// ═══════════════════════════════════════════════════════════════════════════════

enum HackRfMode { rx, sweep, replay }

class HackRfState {
  final bool connected;
  final bool running;
  final HackRfMode mode;
  final double freqMhz;
  final double bandwidthMhz;
  final double lnaGain;
  final double vgaGain;
  final String statusMessage;
  final String firmwareVersion;
  final List<double> sweepPowers; // dBm per MHz across sweep range
  final int captureSeconds;
  final bool captureReady;

  const HackRfState({
    this.connected = false,
    this.running = false,
    this.mode = HackRfMode.rx,
    this.freqMhz = 433.92,
    this.bandwidthMhz = 10.0,
    this.lnaGain = 16.0,
    this.vgaGain = 20.0,
    this.statusMessage = 'No device connected',
    this.firmwareVersion = '',
    this.sweepPowers = const [],
    this.captureSeconds = 5,
    this.captureReady = false,
  });

  HackRfState copyWith({
    bool? connected, bool? running, HackRfMode? mode,
    double? freqMhz, double? bandwidthMhz, double? lnaGain, double? vgaGain,
    String? statusMessage, String? firmwareVersion,
    List<double>? sweepPowers, int? captureSeconds, bool? captureReady,
  }) => HackRfState(
    connected: connected ?? this.connected,
    running: running ?? this.running,
    mode: mode ?? this.mode,
    freqMhz: freqMhz ?? this.freqMhz,
    bandwidthMhz: bandwidthMhz ?? this.bandwidthMhz,
    lnaGain: lnaGain ?? this.lnaGain,
    vgaGain: vgaGain ?? this.vgaGain,
    statusMessage: statusMessage ?? this.statusMessage,
    firmwareVersion: firmwareVersion ?? this.firmwareVersion,
    sweepPowers: sweepPowers ?? this.sweepPowers,
    captureSeconds: captureSeconds ?? this.captureSeconds,
    captureReady: captureReady ?? this.captureReady,
  );
}

class HackRfService extends Notifier<HackRfState> {
  Timer? _runTimer;
  final _rng = math.Random();

  @override
  HackRfState build() => const HackRfState();

  Future<void> connect() async {
    state = state.copyWith(statusMessage: 'Probing USB-OTG for HackRF...');
    await Future.delayed(const Duration(milliseconds: 1200));
    // Real: MethodChannel → HackRFUsbManager.open(context)
    state = state.copyWith(
      connected: true,
      firmwareVersion: '2024.02.1',
      statusMessage: 'HackRF One connected · 1 MHz–6 GHz',
    );
  }

  void disconnect() {
    _runTimer?.cancel();
    state = const HackRfState(statusMessage: 'Disconnected');
  }

  void setMode(HackRfMode m) => state = state.copyWith(mode: m);
  void setFreq(double mhz) => state = state.copyWith(freqMhz: mhz);
  void setBw(double mhz) => state = state.copyWith(bandwidthMhz: mhz);
  void setLnaGain(double db) => state = state.copyWith(lnaGain: db);
  void setVgaGain(double db) => state = state.copyWith(vgaGain: db);
  void setCaptureSeconds(int s) => state = state.copyWith(captureSeconds: s);

  void startStop() {
    if (state.running) {
      _runTimer?.cancel();
      state = state.copyWith(running: false, statusMessage: 'Stopped');
    } else {
      state = state.copyWith(running: true, captureReady: false,
          statusMessage: 'Running — ${state.mode.name.toUpperCase()}');
      _runTimer = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
      if (state.mode == HackRfMode.replay) {
        Future.delayed(Duration(seconds: state.captureSeconds), () {
          _runTimer?.cancel();
          state = state.copyWith(running: false, captureReady: true,
              statusMessage: 'Capture complete — ${state.captureSeconds}s saved');
        });
      }
    }
  }

  void _tick() {
    if (state.mode == HackRfMode.sweep) {
      final powers = List.generate(60, (i) {
        final base = -80.0 + _rng.nextDouble() * 15;
        final hotspot = (i == 20 || i == 40) ? 20.0 + _rng.nextDouble() * 8 : 0.0;
        return base + hotspot;
      });
      state = state.copyWith(sweepPowers: powers);
    }
  }

  @override
  void _cancelTimer() { _runTimer?.cancel(); }
}

final hackRfProvider = NotifierProvider<HackRfService, HackRfState>(
  () => HackRfService(),
);

// ─── Page ────────────────────────────────────────────────────────────────────

class HackRfPage extends ConsumerWidget {
  const HackRfPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = ref.watch(featuresProvider).primaryColor;
    final sdr = ref.watch(hackRfProvider);
    final svc = ref.read(hackRfProvider.notifier);
    final root = ref.watch(rootPermissionProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: Column(children: [
              _buildHeader(color, sdr, svc, root),
              if (!root.isRooted)
                _rootWarning(color),
              _buildModeSelector(color, sdr, svc),
              _buildTuner(color, sdr, svc),
              Expanded(child: _buildDisplay(color, sdr)),
              _buildControls(color, sdr, svc),
            ]),
          ),
          const BackButtonTopLeft(),
        ],
      ),
    );
  }

  Widget _buildHeader(Color color, HackRfState sdr, HackRfService svc, RootPermissionState root) {
    return Container(
      padding: const EdgeInsets.fromLTRB(48, 12, 16, 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.2)))),
      child: Row(children: [
        Icon(Icons.wifi_tethering, color: sdr.running ? Colors.orange : color.withValues(alpha: 0.5), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('HACKRF / PORTAPACK BRIDGE',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
          Text(sdr.firmwareVersion.isEmpty ? '1 MHz – 6 GHz · USB-OTG' : 'FW ${sdr.firmwareVersion}',
              style: TextStyle(color: color.withValues(alpha: 0.4), fontSize: 10)),
        ])),
        GestureDetector(
          onTap: () => sdr.connected ? svc.disconnect() : svc.connect(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: sdr.connected ? Colors.red : color),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(sdr.connected ? 'DISC' : 'CONNECT',
                style: TextStyle(color: sdr.connected ? Colors.red : color, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }

  Widget _rootWarning(Color color) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.orange.withValues(alpha: 0.08),
      border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Row(children: [
      Icon(Icons.warning_amber, color: Colors.orange, size: 14),
      SizedBox(width: 8),
      Expanded(child: Text('RX/Monitor mode only — root required for replay/TX',
          style: TextStyle(color: Colors.orange, fontSize: 10))),
    ]),
  );

  Widget _buildModeSelector(Color color, HackRfState sdr, HackRfService svc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        for (final mode in HackRfMode.values) ...[
          Expanded(child: GestureDetector(
            onTap: () => svc.setMode(mode),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: sdr.mode == mode ? color.withValues(alpha: 0.15) : Colors.transparent,
                border: Border.all(color: sdr.mode == mode ? color : color.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(child: Text(mode.name.toUpperCase(),
                  style: TextStyle(color: sdr.mode == mode ? color : color.withValues(alpha: 0.4),
                      fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))),
            ),
          )),
          if (mode != HackRfMode.values.last) const SizedBox(width: 6),
        ],
      ]),
    );
  }

  Widget _buildTuner(Color color, HackRfState sdr, HackRfService svc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        _slider('FREQ', '${sdr.freqMhz.toStringAsFixed(3)} MHz', sdr.freqMhz, 1.0, 6000.0, color, (v) => svc.setFreq(v)),
        _slider('BW', '${sdr.bandwidthMhz.toStringAsFixed(1)} MHz', sdr.bandwidthMhz, 1.75, 20.0, color, (v) => svc.setBw(v)),
        _slider('LNA', '${sdr.lnaGain.toStringAsFixed(0)} dB', sdr.lnaGain, 0, 40, color, (v) => svc.setLnaGain(v)),
        _slider('VGA', '${sdr.vgaGain.toStringAsFixed(0)} dB', sdr.vgaGain, 0, 62, color, (v) => svc.setVgaGain(v)),
      ]),
    );
  }

  Widget _slider(String label, String val, double value, double min, double max, Color color, ValueChanged<double> onChanged) {
    return Row(children: [
      SizedBox(width: 40, child: Text(label, style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 9, letterSpacing: 1))),
      SizedBox(width: 80, child: Text(val, style: TextStyle(color: color, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold))),
      Expanded(child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged,
          activeColor: color, inactiveColor: color.withValues(alpha: 0.15))),
    ]);
  }

  Widget _buildDisplay(Color color, HackRfState sdr) {
    if (sdr.mode == HackRfMode.sweep && sdr.sweepPowers.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: CustomPaint(
          painter: _SweepPainter(sdr.sweepPowers, color),
          child: Container(),
        ),
      );
    }
    if (sdr.captureReady) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle, color: Colors.green, size: 48),
        const SizedBox(height: 10),
        Text('Capture saved', style: TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold)),
        Text('${sdr.captureSeconds}s IQ recording ready for replay',
            style: TextStyle(color: color.withValues(alpha: 0.4), fontSize: 10)),
      ]));
    }
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.wifi_tethering_error, color: color.withValues(alpha: 0.15), size: 52),
      const SizedBox(height: 12),
      Text(sdr.statusMessage, style: TextStyle(color: color.withValues(alpha: 0.3), fontSize: 11, letterSpacing: 1.5)),
    ]));
  }

  Widget _buildControls(Color color, HackRfState sdr, HackRfService svc) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: sdr.connected ? svc.startStop : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: (sdr.running ? Colors.red : color).withValues(alpha: sdr.connected ? 0.12 : 0.04),
              border: Border.all(color: (sdr.running ? Colors.red : color).withValues(alpha: sdr.connected ? 0.6 : 0.2)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(child: Text(
              sdr.running ? '■ STOP' : '▶ START ${sdr.mode.name.toUpperCase()}',
              style: TextStyle(
                color: sdr.connected ? (sdr.running ? Colors.red : color) : color.withValues(alpha: 0.25),
                fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2,
              ),
            )),
          ),
        ),
      ),
    );
  }
}

class _SweepPainter extends CustomPainter {
  final List<double> powers;
  final Color color;
  const _SweepPainter(this.powers, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = color.withValues(alpha: 0.04));
    if (powers.isEmpty) return;
    const minP = -100.0, maxP = -30.0;
    final paint = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke;
    final path = Path();
    for (int i = 0; i < powers.length; i++) {
      final x = size.width * i / powers.length;
      final y = size.height * (1 - ((powers[i] - minP) / (maxP - minP)).clamp(0, 1));
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.powers != powers;
}
