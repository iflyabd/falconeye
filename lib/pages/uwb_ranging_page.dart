// ═══════════════════════════════════════════════════════════════════════════
// FALCON EYE V48.1 — UWB PRECISION RANGING
// Ultra-Wideband sub-10cm ranging with Kalman filter + polar radar display.
// Uses existing uwb_service.dart MethodChannel (falcon_eye/uwb).
// Algorithm: Kalman-filtered distance, polar→cartesian dot placement.
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/uwb_service.dart';
import '../widgets/back_button_top_left.dart';

// ── Data model ──────────────────────────────────────────────────────────────
class UwbPeer {
  final String address;
  double distance;      // Kalman-smoothed metres
  double rawDistance;
  double azimuthDeg;
  int rssi;
  DateTime lastSeen;

  // Kalman state
  double _kEst = 0.0;
  double _kP   = 1.0;
  static const double _kR = 0.05;
  static const double _kQ = 0.001;

  UwbPeer({
    required this.address,
    required double rawDist,
    this.azimuthDeg = 0,
    this.rssi       = -80,
  })  : rawDistance = rawDist,
        distance    = rawDist,
        lastSeen    = DateTime.now() {
    _kEst = rawDist;
  }

  void update(double measurement, double azDeg, int rssiVal) {
    _kP   = _kP + _kQ;
    final k = _kP / (_kP + _kR);
    _kEst = _kEst + k * (measurement - _kEst);
    _kP   = (1.0 - k) * _kP;
    rawDistance = measurement;
    distance    = _kEst;
    azimuthDeg  = azDeg;
    rssi        = rssiVal;
    lastSeen    = DateTime.now();
  }
}

// ── Provider ────────────────────────────────────────────────────────────────
final uwbPeersProvider =
    NotifierProvider<UwbPeersNotifier, List<UwbPeer>>(UwbPeersNotifier.new);

class UwbPeersNotifier extends Notifier<List<UwbPeer>> {
  @override
  List<UwbPeer> build() => [];

  void processResult(Map<String, dynamic> r) {
    final address  = r['address']?.toString() ?? 'Unknown';
    final dist     = (r['distanceMeters'] as num?)?.toDouble() ?? 0.0;
    final azimuth  = (r['azimuthDegrees'] as num?)?.toDouble() ?? 0.0;
    final rssiVal  = (r['rssi'] as num?)?.toInt() ?? -80;

    final peers = List<UwbPeer>.from(state);
    final idx   = peers.indexWhere((p) => p.address == address);
    if (idx >= 0) {
      peers[idx].update(dist, azimuth, rssiVal);
    } else {
      peers.add(UwbPeer(address: address, rawDist: dist,
          azimuthDeg: azimuth, rssi: rssiVal));
    }
    // Prune stale peers (>10 s)
    peers.removeWhere(
        (p) => DateTime.now().difference(p.lastSeen).inSeconds > 10);
    state = List.from(peers);
  }

  void clear() => state = [];
}

// ── Page ─────────────────────────────────────────────────────────────────────
class UwbRangingPage extends ConsumerStatefulWidget {
  const UwbRangingPage({super.key});
  @override
  ConsumerState<UwbRangingPage> createState() => _UwbRangingPageState();
}

class _UwbRangingPageState extends ConsumerState<UwbRangingPage> {
  static const _ch  = MethodChannel('falcon_eye/uwb');
  static const _grn = Color(0xFF00FF41);
  static const _cyn = Color(0xFF00FFFF);

  bool   _supported = false;
  bool   _ranging   = false;
  String _status    = 'INITIALISING UWB...';
  StreamSubscription? _eventSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ok = await _ch.invokeMethod<bool>('isUwbSupported') ?? false;
      if (!mounted) return;
      setState(() {
        _supported = ok;
        _status    = ok ? 'UWB READY — TAP START' : 'UWB NOT SUPPORTED ON THIS DEVICE';
      });
    } on PlatformException {
      if (!mounted) return;
      setState(() { _supported = false; _status = 'UWB CHANNEL UNAVAILABLE'; });
    }
  }

  Future<void> _startRanging() async {
    if (!_supported) return;
    try {
      await _ch.invokeMethod('startRanging');
      setState(() { _ranging = true; _status = 'RANGING ACTIVE'; });
      // Listen to event channel for continuous results
      const events = EventChannel('falcon_eye/uwb_events');
      _eventSub = events.receiveBroadcastStream().listen((dynamic data) {
        if (data is Map) {
          ref.read(uwbPeersProvider.notifier)
              .processResult(Map<String, dynamic>.from(data));
        }
      });
    } on PlatformException catch (e) {
      setState(() { _status = 'RANGING ERROR: ${e.message}'; });
    }
  }

  Future<void> _stopRanging() async {
    _eventSub?.cancel();
    _eventSub = null;
    try { await _ch.invokeMethod('stopRanging'); } catch (_) {}
    ref.read(uwbPeersProvider.notifier).clear();
    if (!mounted) return;
    setState(() { _ranging = false; _status = 'UWB READY — TAP START'; });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _ch.invokeMethod('stopRanging').catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peers = ref.watch(uwbPeersProvider);
    final closest = peers.isEmpty
        ? null
        : peers.reduce((a, b) => a.distance < b.distance ? a : b);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(children: [
            const BackButtonTopLeft(),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('UWB PRECISION RANGING',
                  style: TextStyle(color: _cyn, fontFamily: 'Courier New',
                      fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
              Text(_status,
                  style: TextStyle(
                      color: _ranging ? _grn : Colors.amber,
                      fontFamily: 'Courier New', fontSize: 11)),
            ]),
          ]),
        ),
        const SizedBox(height: 8),

        // ── Radar + distance ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            // Radar
            SizedBox(
              width: 200, height: 200,
              child: CustomPaint(
                painter: _UwbRadarPainter(peers: peers, ranging: _ranging),
              ),
            ),
            const SizedBox(width: 16),
            // Main readout
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (closest != null) ...[
                  Text(closest.distance.toStringAsFixed(2),
                      style: const TextStyle(color: _grn, fontFamily: 'Courier New',
                          fontSize: 48, fontWeight: FontWeight.bold)),
                  const Text('METRES', style: TextStyle(color: Colors.green,
                      fontFamily: 'Courier New', fontSize: 12, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text('± ${(closest.rawDistance - closest.distance).abs().toStringAsFixed(3)} m',
                      style: const TextStyle(color: Colors.grey,
                          fontFamily: 'Courier New', fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('AZ: ${closest.azimuthDeg.toStringAsFixed(1)}°',
                      style: const TextStyle(color: _cyn, fontFamily: 'Courier New', fontSize: 14)),
                  Text('RSSI: ${closest.rssi} dBm',
                      style: const TextStyle(color: Colors.grey,
                          fontFamily: 'Courier New', fontSize: 12)),
                ] else
                  Text(peers.isEmpty ? 'NO PEERS' : '---',
                      style: const TextStyle(color: Colors.grey,
                          fontFamily: 'Courier New', fontSize: 32)),
                const SizedBox(height: 12),
                // Start/Stop button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _ranging ? Colors.red : _cyn),
                        foregroundColor: _ranging ? Colors.red : _cyn),
                    onPressed: _supported
                        ? (_ranging ? _stopRanging : _startRanging)
                        : null,
                    child: Text(_ranging ? 'STOP RANGING' : 'START RANGING',
                        style: const TextStyle(fontFamily: 'Courier New',
                            fontSize: 12, letterSpacing: 1)),
                  ),
                ),
              ],
            )),
          ]),
        ),
        const Divider(color: Color(0xFF003311), height: 24),

        // ── Peer list ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: const [
            Expanded(child: Text('ADDRESS', style: TextStyle(color: Colors.green,
                fontFamily: 'Courier New', fontSize: 10, letterSpacing: 1))),
            SizedBox(width: 60, child: Text('DIST', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green, fontFamily: 'Courier New', fontSize: 10))),
            SizedBox(width: 60, child: Text('RSSI', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green, fontFamily: 'Courier New', fontSize: 10))),
            SizedBox(width: 50, child: Text('AGE', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green, fontFamily: 'Courier New', fontSize: 10))),
          ]),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: peers.isEmpty
              ? Center(child: Text(
                  _ranging ? 'SCANNING FOR UWB PEERS...' : 'TAP START RANGING',
                  style: const TextStyle(color: Colors.green, fontFamily: 'Courier New', fontSize: 13)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: peers.length,
                  itemBuilder: (ctx, i) {
                    final p = peers[i];
                    final age = DateTime.now().difference(p.lastSeen).inSeconds;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF001100),
                        border: Border.all(color: const Color(0xFF003311)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(children: [
                        Expanded(child: Text(p.address,
                            overflow: TextOverflow.ellipsis, maxLines: 1,
                            style: const TextStyle(color: Colors.white,
                                fontFamily: 'Courier New', fontSize: 11))),
                        SizedBox(width: 60, child: Text(
                            '${p.distance.toStringAsFixed(2)}m',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _grn,
                                fontFamily: 'Courier New', fontSize: 11))),
                        SizedBox(width: 60, child: Text('${p.rssi}dBm',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey,
                                fontFamily: 'Courier New', fontSize: 11))),
                        SizedBox(width: 50, child: Text('${age}s',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: age < 3 ? _grn : Colors.orange,
                                fontFamily: 'Courier New', fontSize: 11))),
                      ]),
                    );
                  },
                ),
        ),
      ])),
    );
  }
}

// ── Radar painter ─────────────────────────────────────────────────────────────
class _UwbRadarPainter extends CustomPainter {
  final List<UwbPeer> peers;
  final bool ranging;
  _UwbRadarPainter({required this.peers, required this.ranging});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) - 8;

    final gridPaint = Paint()
      ..color = const Color(0xFF003311)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final axisPaint = Paint()
      ..color = const Color(0xFF005522)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final dotPaint = Paint()
      ..color = const Color(0xFF00FFFF)
      ..style = PaintingStyle.fill;
    final selfPaint = Paint()
      ..color = const Color(0xFF00FF41)
      ..style = PaintingStyle.fill;

    // Concentric range rings
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(Offset(cx, cy), r * i / 4, gridPaint);
    }
    // Cross-hairs
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), axisPaint);
    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), axisPaint);

    // Self dot
    canvas.drawCircle(Offset(cx, cy), 5, selfPaint);

    if (!ranging || peers.isEmpty) return;

    // Max range for scale
    final maxDist = peers.map((p) => p.distance).reduce(math.max);
    final scale   = maxDist > 0 ? r / (maxDist * 1.1) : r / 10.0;

    for (final p in peers) {
      final az = p.azimuthDeg * math.pi / 180.0;
      final px = cx + p.distance * scale * math.sin(az);
      final py = cy - p.distance * scale * math.cos(az);
      canvas.drawCircle(Offset(px, py), 5, dotPaint);
      // Line from centre
      canvas.drawLine(Offset(cx, cy), Offset(px, py),
          Paint()..color = const Color(0xFF004444)..strokeWidth = 0.5);
    }
  }

  @override
  bool shouldRepaint(_UwbRadarPainter old) =>
      old.peers != peers || old.ranging != ranging;
}
