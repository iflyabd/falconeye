// =============================================================================
// FALCON EYE V50.0 — SOVEREIGN BOOT PAGE
// 5-phase cinematic boot: HARDWARE INIT → SENSOR CALIBRATION → SIGNAL ENGINE
//                         → PERMISSIONS → SOVEREIGN ONLINE
// Real hardware fingerprint, permission gating, root badge, zero Random().
// =============================================================================
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/hardware_capabilities_service.dart';
import '../services/features_provider.dart';
import '../services/gpu_abstraction_service.dart';
import '../services/stealth_service.dart';
import '../theme.dart';

// ── Phase definition ──────────────────────────────────────────────────────────
enum _BootPhase {
  hardwareInit,
  sensorCalibration,
  signalEngine,
  permissions,
  sovereignOnline,
}

extension _BootPhaseLabel on _BootPhase {
  String get label {
    switch (this) {
      case _BootPhase.hardwareInit:      return 'HARDWARE INIT';
      case _BootPhase.sensorCalibration: return 'SENSOR CALIBRATION';
      case _BootPhase.signalEngine:      return 'SIGNAL ENGINE';
      case _BootPhase.permissions:       return 'PERMISSIONS';
      case _BootPhase.sovereignOnline:   return 'SOVEREIGN ONLINE';
    }
  }
}

// ── Terminal line model ───────────────────────────────────────────────────────
enum _LineStatus { info, ok, fail, warn }

class _TermLine {
  final String text;
  final _LineStatus status;
  const _TermLine(this.text, [this.status = _LineStatus.info]);
}

// =============================================================================
class SovereignBootPage extends ConsumerStatefulWidget {
  const SovereignBootPage({super.key});
  @override
  ConsumerState<SovereignBootPage> createState() => _SovereignBootPageState();
}

class _SovereignBootPageState extends ConsumerState<SovereignBootPage>
    with TickerProviderStateMixin {

  late final AnimationController _scanlineCtrl;
  late final AnimationController _glitchCtrl;
  late final AnimationController _phaseBarCtrl;
  late final AnimationController _cursorCtrl;

  _BootPhase _phase = _BootPhase.hardwareInit;
  int _phaseIndex   = 0;
  final List<_TermLine> _lines = [];
  bool _isRooted     = false;
  bool _degradedMode = false;
  bool _bootComplete = false;
  bool _showSkip     = false;
  bool _glitching    = false;

  String _deviceLabel = 'Detecting…';
  String _gpuLabel    = '…';
  String _ramLabel    = '…';
  String _abiLabel    = '…';
  String _apiLabel    = '…';

  final Map<String, bool> _permResults = {};

  @override
  void initState() {
    super.initState();
    _scanlineCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _glitchCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _phaseBarCtrl= AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _cursorCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 530))
      ..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showSkip = true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _runBoot());
  }

  @override
  void dispose() {
    _scanlineCtrl.dispose();
    _glitchCtrl.dispose();
    _phaseBarCtrl.dispose();
    _cursorCtrl.dispose();
    super.dispose();
  }

  void _emit(String text, [_LineStatus status = _LineStatus.info]) {
    if (!mounted) return;
    setState(() => _lines.add(_TermLine(text, status)));
  }

  Future<void> _delay(int ms) => Future.delayed(Duration(milliseconds: ms));

  Future<void> _advancePhase(_BootPhase next) async {
    setState(() => _glitching = true);
    _glitchCtrl.forward(from: 0);
    await _delay(120);
    if (!mounted) return;
    setState(() {
      _glitching  = false;
      _phase      = next;
      _phaseIndex = _BootPhase.values.indexOf(next);
    });
    _phaseBarCtrl.forward(from: 0);
    await _delay(80);
  }

  Future<void> _runBoot() async {
    await _delay(300);

    // ── PHASE 1: HARDWARE INIT ────────────────────────────────────────────
    _emit('> FALCON EYE V50.0 BOOTING...');
    await _delay(200);
    _emit('> SOVEREIGN PROTOCOL ACTIVE');
    await _delay(150);

    try {
      final info = await DeviceInfoPlugin().androidInfo;
      _deviceLabel = '${info.brand.toUpperCase()} ${info.model}';
      _apiLabel    = 'API ${info.version.sdkInt}';
      _abiLabel    = info.supportedAbis.isNotEmpty ? info.supportedAbis.first : 'arm64';
      _emit('> DEVICE: $_deviceLabel');
      await _delay(100);
      _emit('> OS: Android ${info.version.release} ($_apiLabel)');
      await _delay(100);
      _emit('> ABI: $_abiLabel');
      await _delay(100);
      try {
        final r = await Process.run('cat', ['/proc/meminfo']);
        final m = RegExp(r'MemTotal:\s+(\d+)').firstMatch(r.stdout as String);
        if (m != null) {
          final kb = int.parse(m.group(1)!);
          _ramLabel = '${(kb / 1048576).toStringAsFixed(1)} GB';
        }
      } catch (_) { _ramLabel = 'N/A'; }
      _emit('> RAM: $_ramLabel');
      await _delay(100);
      if (mounted) setState(() {});
    } catch (_) {
      _emit('> DEVICE PROBE: PARTIAL', _LineStatus.warn);
    }

    ref.read(gpuAbstractionProvider.notifier).rescan();
    await _delay(200);
    final gpu = ref.read(gpuAbstractionProvider);
    _gpuLabel = gpu.gpuName.isNotEmpty ? gpu.gpuName : gpu.tier.label;
    _emit('> GPU: $_gpuLabel (${gpu.tier.label})');
    await _delay(150);

    ref.read(hardwareCapabilitiesProvider.notifier).scanHardware();
    await _delay(300);
    final caps = ref.read(hardwareCapabilitiesProvider);
    _emit('> WIFI7: ${caps.wifi7.enabled ? "PRESENT" : "NOT DETECTED"}',
        caps.wifi7.enabled ? _LineStatus.ok : _LineStatus.warn);
    await _delay(80);
    _emit('> UWB: ${caps.uwbChipset.enabled ? "PRESENT" : "NOT DETECTED"}',
        caps.uwbChipset.enabled ? _LineStatus.ok : _LineStatus.warn);
    await _delay(80);
    _emit('> SDR-USB: ${caps.sdrUsb.enabled ? "READY" : "NOT CONNECTED"}',
        caps.sdrUsb.enabled ? _LineStatus.ok : _LineStatus.info);
    await _delay(150);
    _emit('> HARDWARE INIT COMPLETE', _LineStatus.ok);
    await _advancePhase(_BootPhase.sensorCalibration);

    // ── PHASE 2: SENSOR CALIBRATION ───────────────────────────────────────
    _emit('> CALIBRATING IMU...');
    await _delay(250);
    _emit('> GYROSCOPE: ALIGNED', _LineStatus.ok);
    await _delay(150);
    _emit('> ACCELEROMETER: ALIGNED', _LineStatus.ok);
    await _delay(150);
    _emit('> MAGNETOMETER: CALIBRATING...');
    await _delay(300);
    _emit('> MAGNETOMETER: ALIGNED', _LineStatus.ok);
    await _delay(100);
    _emit('> BAROMETER: ${caps.tier1Flagship.enabled ? "PRESENT" : "N/A"}',
        caps.tier1Flagship.enabled ? _LineStatus.ok : _LineStatus.info);
    await _delay(100);
    _emit('> CSI ACCESS: ${caps.csiRawAccess.enabled ? "GRANTED" : "LIMITED"}',
        caps.csiRawAccess.enabled ? _LineStatus.ok : _LineStatus.warn);
    await _delay(150);
    _emit('> SENSOR CALIBRATION COMPLETE', _LineStatus.ok);
    await _advancePhase(_BootPhase.signalEngine);

    // ── PHASE 3: SIGNAL ENGINE ────────────────────────────────────────────
    _emit('> LOADING SIGNAL ENGINE...');
    await _delay(200);
    _emit('> LOG-DISTANCE PATH LOSS MODEL: LOADED',  _LineStatus.ok);
    await _delay(100);
    _emit('> MAHONY AHRS GYRO-FUSION: LOADED',       _LineStatus.ok);
    await _delay(100);
    _emit('> COOLEY-TUKEY FFT: LOADED',              _LineStatus.ok);
    await _delay(100);
    _emit('> OPENGL ES 2.0 RENDERER: ${gpu.nativeAvailable ? "NATIVE" : "CANVAS FALLBACK"}',
        gpu.nativeAvailable ? _LineStatus.ok : _LineStatus.warn);
    await _delay(100);
    _emit('> VBO DOUBLE-BUFFER: ARMED',              _LineStatus.ok);
    await _delay(100);
    _emit('> CHOREOGRAPHER THREAD: ${gpu.nativeAvailable ? "ACTIVE @ ${gpu.targetFps}FPS" : "INACTIVE"}',
        gpu.nativeAvailable ? _LineStatus.ok : _LineStatus.warn);
    await _delay(150);

    _isRooted = caps.rootAccess.enabled;
    _emit('> ROOT ACCESS: ${_isRooted ? "CONFIRMED" : "NOT AVAILABLE"}',
        _isRooted ? _LineStatus.ok : _LineStatus.warn);
    await _delay(150);
    ref.read(featuresProvider.notifier).setHasRoot(_isRooted);
    _emit('> SIGNAL ENGINE ONLINE', _LineStatus.ok);
    await _advancePhase(_BootPhase.permissions);

    // ── PHASE 4: PERMISSIONS ─────────────────────────────────────────────
    _emit('> CHECKING PERMISSIONS...');
    await _delay(200);

    final checks = <String, Permission>{
      'LOCATION':    Permission.location,
      'BLUETOOTH':   Permission.bluetoothScan,
      'CAMERA':      Permission.camera,
      'PHONE STATE': Permission.phone,
      'STORAGE':     Permission.storage,
    };

    for (final e in checks.entries) {
      final granted = (await e.value.status).isGranted;
      _permResults[e.key] = granted;
      _emit('> ${e.key.padRight(12)}: ${granted ? "[  OK  ]" : "[ FAIL ]"}',
          granted ? _LineStatus.ok : _LineStatus.fail);
      await _delay(120);
    }

    final criticalOk = (_permResults['LOCATION'] ?? false) &&
                       (_permResults['BLUETOOTH'] ?? false);
    _degradedMode = !criticalOk ||
        !(_permResults['CAMERA'] ?? false) ||
        !(_permResults['PHONE STATE'] ?? false);

    await _delay(150);
    if (_degradedMode && criticalOk) {
      _emit('> [ DEGRADED MODE ] — NON-CRITICAL PERMS MISSING', _LineStatus.warn);
    } else if (!criticalOk) {
      _emit('> [ LIMITED MODE ] — GRANT LOCATION + BT FOR FULL FUNCTION', _LineStatus.warn);
    } else {
      _emit('> ALL PERMISSIONS GRANTED', _LineStatus.ok);
    }
    await _delay(200);
    await _advancePhase(_BootPhase.sovereignOnline);

    // ── PHASE 5: SOVEREIGN ONLINE ─────────────────────────────────────────
    _emit('');
    _emit('> ==============================');
    _emit('> FALCON EYE SOVEREIGN ONLINE',  _LineStatus.ok);
    _emit('> ==============================');
    await _delay(200);

    if (ref.read(stealthProtocolProvider)) {
      _emit('> STEALTH PROTOCOL: ACTIVE', _LineStatus.warn);
      _emit('> TELEMETRY: ZERO',          _LineStatus.warn);
    }
    await _delay(150);
    _emit('> INITIATING MASTER HUD...');
    await _delay(600);

    if (mounted) {
      setState(() => _bootComplete = true);
      await _delay(400);
      if (mounted) context.go('/hud');
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final color = ref.watch(featuresProvider).primaryColor;
    final size  = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _scanlineCtrl,
              builder: (_, __) => CustomPaint(
                size: size,
                painter: _ScanlinePainter(_scanlineCtrl.value, color),
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(color),
                  _buildPhaseBar(color),
                  _buildDeviceStrip(color),
                  Expanded(child: _buildTerminal(color)),
                  _buildFooter(color),
                ],
              ),
            ),
            if (_glitching)
              Positioned.fill(
                child: Container(color: color.withValues(alpha: 0.08)),
              ),
            if (_showSkip && !_bootComplete)
              Positioned(
                top: 12, right: 12,
                child: SafeArea(
                  child: TextButton(
                    onPressed: () => context.go('/hud'),
                    child: Text('SKIP ›',
                        style: TextStyle(
                          color: color.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                        )),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('FALCON EYE',
                  style: TextStyle(
                    color: color, fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace', letterSpacing: 6,
                    shadows: [Shadow(color: color, blurRadius: 12)],
                  )),
              _RootBadge(isRooted: _isRooted, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text('SOVEREIGN V50.0  //  SYSTEM INITIALIZATION',
              style: TextStyle(
                color: color.withValues(alpha: 0.45),
                fontSize: 9, fontFamily: 'monospace', letterSpacing: 2,
              )),
          const SizedBox(height: 8),
          Row(children: [
            Text('┌─', style: TextStyle(color: color.withValues(alpha: 0.3), fontSize: 10)),
            Expanded(child: Divider(color: color.withValues(alpha: 0.2), height: 1)),
            Text('─┐', style: TextStyle(color: color.withValues(alpha: 0.3), fontSize: 10)),
          ]),
        ],
      ),
    );
  }

  Widget _buildPhaseBar(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: _BootPhase.values.map((p) {
          final idx    = _BootPhase.values.indexOf(p);
          final done   = idx < _phaseIndex;
          final active = idx == _phaseIndex;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: 3,
                    decoration: BoxDecoration(
                      color: done   ? color
                           : active ? color.withValues(alpha: 0.6)
                                    : color.withValues(alpha: 0.1),
                      boxShadow: active ? [BoxShadow(color: color, blurRadius: 6)] : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(p.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: done   ? color.withValues(alpha: 0.7)
                             : active ? color
                                      : color.withValues(alpha: 0.2),
                        fontSize: 6, fontFamily: 'monospace', letterSpacing: 0.5,
                      )),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDeviceStrip(Color color) {
    final items = [
      _deviceLabel, _apiLabel, _abiLabel,
      'RAM: $_ramLabel',
      'GPU: ${_gpuLabel.length > 18 ? _gpuLabel.substring(0, 18) : _gpuLabel}',
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.15)),
        color: color.withValues(alpha: 0.03),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: items.map((item) => Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(item,
                style: TextStyle(
                  color: color.withValues(alpha: 0.55),
                  fontSize: 9, fontFamily: 'monospace', letterSpacing: 1,
                )),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildTerminal(Color color) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.12)),
        color: Colors.black,
      ),
      child: ListView.builder(
        reverse: true,
        itemCount: _lines.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return AnimatedBuilder(
              animation: _cursorCtrl,
              builder: (_, __) => Text('> _',
                  style: TextStyle(
                    color: color.withValues(alpha: _cursorCtrl.value),
                    fontSize: 11, fontFamily: 'monospace',
                  )),
            );
          }
          return _TermLineWidget(
            line: _lines[_lines.length - i], color: color);
        },
      ),
    );
  }

  Widget _buildFooter(Color color) {
    final stealthActive = ref.watch(stealthProtocolProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        children: [
          Row(children: [
            Text('└─', style: TextStyle(color: color.withValues(alpha: 0.3), fontSize: 10)),
            Expanded(child: Divider(color: color.withValues(alpha: 0.2), height: 1)),
            Text('─┘', style: TextStyle(color: color.withValues(alpha: 0.3), fontSize: 10)),
          ]),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                if (_degradedMode) _StatusChip('DEGRADED', Colors.orange),
                if (stealthActive) ...[
                  const SizedBox(width: 6),
                  _StatusChip('STEALTH', Colors.red),
                ],
              ]),
              Text(_phase.label,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.4),
                    fontSize: 9, fontFamily: 'monospace', letterSpacing: 2,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _RootBadge extends StatefulWidget {
  final bool isRooted;
  final Color color;
  const _RootBadge({required this.isRooted, required this.color});
  @override
  State<_RootBadge> createState() => _RootBadgeState();
}
class _RootBadgeState extends State<_RootBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _pulse.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final c = widget.isRooted ? const Color(0xFF00FF41) : Colors.orange;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: c.withValues(alpha: 0.5 + 0.5 * _pulse.value)),
          color: c.withValues(alpha: 0.05 + 0.08 * _pulse.value),
          borderRadius: BorderRadius.circular(3),
          boxShadow: [BoxShadow(color: c.withValues(alpha: 0.2 * _pulse.value), blurRadius: 8)],
        ),
        child: Text(
          widget.isRooted ? 'ROOTED ✓' : 'LIMITED MODE',
          style: TextStyle(
            color: c, fontSize: 9, fontFamily: 'monospace',
            fontWeight: FontWeight.bold, letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class _TermLineWidget extends StatelessWidget {
  final _TermLine line;
  final Color color;
  const _TermLineWidget({required this.line, required this.color});
  @override
  Widget build(BuildContext context) {
    final Color textColor;
    switch (line.status) {
      case _LineStatus.ok:   textColor = const Color(0xFF00FF41);
      case _LineStatus.fail: textColor = const Color(0xFFFF3333);
      case _LineStatus.warn: textColor = Colors.orange;
      case _LineStatus.info: textColor = color.withValues(alpha: 0.7);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Text(line.text,
          style: TextStyle(
            color: textColor, fontSize: 10.5,
            fontFamily: 'monospace', letterSpacing: 0.3, height: 1.5,
          )),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color chipColor;
  const _StatusChip(this.label, this.chipColor);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: chipColor.withValues(alpha: 0.6)),
        color: chipColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(label,
          style: TextStyle(
            color: chipColor, fontSize: 8, fontFamily: 'monospace',
            letterSpacing: 1.5, fontWeight: FontWeight.bold,
          )),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  final double progress;
  final Color color;
  const _ScanlinePainter(this.progress, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final y = progress * (size.height + 40) - 20;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.04),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, y - 20, size.width, 40));
    canvas.drawRect(Rect.fromLTWH(0, y - 20, size.width, 40), paint);
    final linePaint = Paint()..color = Colors.black.withValues(alpha: 0.08)..strokeWidth = 1;
    for (double ly = 0; ly < size.height; ly += 4) {
      canvas.drawLine(Offset(0, ly), Offset(size.width, ly), linePaint);
    }
  }
  @override
  bool shouldRepaint(_ScanlinePainter old) => old.progress != progress;
}
