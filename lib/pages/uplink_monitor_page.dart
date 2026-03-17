// ═══════════════════════════════════════════════════════════════════════════
// FALCON EYE V48.1 — SOVEREIGN UPLINK MONITOR
// Live uplink/downlink bandwidth display using UplinkService.
// Animated beacon + bandwidth LineChart + rolling samples history.
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/uplink_service.dart';
import '../widgets/back_button_top_left.dart';

// ── Beacon painter ─────────────────────────────────────────────────────────
class _BeaconPainter extends CustomPainter {
  final double phase;
  final Color color;
  _BeaconPainter(this.phase, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = math.min(cx, cy);
    for (int i = 0; i < 3; i++) {
      final t = ((phase + i / 3.0) % 1.0);
      final r = t * maxR * 0.85;
      final alpha = (1.0 - t).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = color.withValues(alpha: alpha * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    canvas.drawCircle(
      Offset(cx, cy),
      7,
      Paint()..color = color..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_BeaconPainter old) => old.phase != phase;
}

// ── Network type name ───────────────────────────────────────────────────────
String _netTypeName(int t) {
  switch (t) {
    case 13: return 'LTE';
    case 20: return '5G NR';
    case 3:  return 'UMTS';
    case 8:  return 'HSDPA';
    case 15: return 'HSPA+';
    default: return t < 0 ? 'UNKNOWN' : 'TYPE-$t';
  }
}

String _dataActivityLabel(int a) {
  switch (a) {
    case 1: return 'RX';
    case 2: return 'TX';
    case 3: return 'RX+TX';
    default: return 'IDLE';
  }
}

// ── Page ───────────────────────────────────────────────────────────────────
class UplinkMonitorPage extends ConsumerStatefulWidget {
  const UplinkMonitorPage({super.key});
  @override
  ConsumerState<UplinkMonitorPage> createState() => _UplinkMonitorPageState();
}

class _UplinkMonitorPageState extends ConsumerState<UplinkMonitorPage>
    with SingleTickerProviderStateMixin {
  static const _purp = Color(0xFFCE93D8);
  static const _maxHistory = 60;

  late AnimationController _beacon;
  final List<UplinkSample> _history = [];
  StreamSubscription<UplinkSample>? _sub;

  @override
  void initState() {
    super.initState();
    _beacon = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _beacon.dispose();
    _sub?.cancel();
    super.dispose();
  }

  // Subscribe once providers are ready
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub?.cancel();
    final svc = ref.read(uplinkServiceProvider);
    svc.start();
    _sub = svc.stream.listen((sample) {
      if (mounted) {
        setState(() {
          _history.add(sample);
          if (_history.length > _maxHistory) _history.removeAt(0);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final uplinkAsync = ref.watch(uplinkStreamProvider);
    final latest = _history.isNotEmpty ? _history.last : null;

    // Connection status color
    Color statusColor;
    String statusLabel;
    if (latest == null) {
      statusColor = Colors.amber;
      statusLabel = 'INITIALISING';
    } else if (!latest.isDataEnabled) {
      statusColor = Colors.red;
      statusLabel = 'DATA DISABLED';
    } else if (latest.dataState == 2) {
      statusColor = _purp;
      statusLabel = 'CONNECTED';
    } else {
      statusColor = Colors.amber;
      statusLabel = 'QUEUED / ROAMING';
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Row(children: [
                const Icon(Icons.cloud_upload, color: _purp, size: 22),
                const SizedBox(width: 8),
                const Text('SOVEREIGN UPLINK MONITOR',
                    style: TextStyle(
                        color: _purp,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2)),
              ]),
              const SizedBox(height: 4),
              Text('V48.1 — ENCRYPTED DATA UPLINK',
                  style: TextStyle(
                      color: _purp.withValues(alpha: 0.4),
                      fontSize: 9,
                      letterSpacing: 1.5)),

              const SizedBox(height: 24),

              // Beacon + status
              Row(children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: AnimatedBuilder(
                    animation: _beacon,
                    builder: (_, __) => CustomPaint(
                      painter: _BeaconPainter(_beacon.value, statusColor),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(statusLabel,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5)),
                    if (latest != null)
                      Text(
                          '${_netTypeName(latest.networkType)} · ${_dataActivityLabel(latest.dataActivity)}',
                          style: TextStyle(
                              color: _purp.withValues(alpha: 0.5),
                              fontSize: 10,
                              letterSpacing: 1)),
                  ]),
                ),
              ]),

              const SizedBox(height: 20),

              // Stats row
              if (latest != null)
                Row(children: [
                  _statBox('UP', '${latest.uplinkKbps.toStringAsFixed(1)} kbps',
                      _purp),
                  const SizedBox(width: 8),
                  _statBox(
                      'DOWN',
                      '${latest.downlinkKbps.toStringAsFixed(1)} kbps',
                      const Color(0xFF00DDFF)),
                  const SizedBox(width: 8),
                  _statBox(
                      'TX PKT',
                      '${latest.mobileTxPackets}',
                      Colors.greenAccent),
                ]),

              const SizedBox(height: 20),

              // Bandwidth chart
              if (_history.length > 2) ...[
                Text('BANDWIDTH HISTORY (60s)',
                    style: TextStyle(
                        color: _purp.withValues(alpha: 0.5),
                        fontSize: 9,
                        letterSpacing: 1.5)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 160,
                  child: LineChart(_buildChart()),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  _legendDot(_purp, 'UPLINK'),
                  const SizedBox(width: 16),
                  _legendDot(const Color(0xFF00DDFF), 'DOWNLINK'),
                ]),
              ],

              const SizedBox(height: 20),

              // Sample table
              Text('RECENT SAMPLES',
                  style: TextStyle(
                      color: _purp.withValues(alpha: 0.5),
                      fontSize: 9,
                      letterSpacing: 1.5)),
              const SizedBox(height: 6),
              ..._history.reversed.take(10).map((s) => _sampleRow(s)),

              uplinkAsync.when(
                data: (_) => const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('Uplink error: $e',
                      style: const TextStyle(color: Colors.red, fontSize: 10)),
                ),
              ),
            ]),
          ),
          const BackButtonTopLeft(),
        ]),
      ),
    );
  }

  LineChartData _buildChart() {
    final upSpots = <FlSpot>[];
    final downSpots = <FlSpot>[];
    for (int i = 0; i < _history.length; i++) {
      upSpots.add(FlSpot(i.toDouble(), _history[i].uplinkKbps.clamp(0, 9999)));
      downSpots
          .add(FlSpot(i.toDouble(), _history[i].downlinkKbps.clamp(0, 9999)));
    }
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: _purp.withValues(alpha: 0.08), strokeWidth: 1),
      ),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: upSpots,
          isCurved: true,
          color: _purp,
          barWidth: 1.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
              show: true, color: _purp.withValues(alpha: 0.07)),
        ),
        LineChartBarData(
          spots: downSpots,
          isCurved: true,
          color: const Color(0xFF00DDFF),
          barWidth: 1.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF00DDFF).withValues(alpha: 0.07)),
        ),
      ],
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(children: [
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.6),
                  fontSize: 9,
                  letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Courier New'),
              overflow: TextOverflow.ellipsis,
              maxLines: 1),
        ]),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(children: [
      Container(
          width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9, letterSpacing: 0.5)),
    ]);
  }

  Widget _sampleRow(UplinkSample s) {
    final ts = DateTime.fromMillisecondsSinceEpoch(s.timestampMs);
    final time =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _purp.withValues(alpha: 0.03),
        border: Border.all(color: _purp.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(children: [
        Text(time,
            style: TextStyle(
                color: _purp.withValues(alpha: 0.5),
                fontSize: 9,
                fontFamily: 'Courier New')),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
              '↑${s.uplinkKbps.toStringAsFixed(1)} ↓${s.downlinkKbps.toStringAsFixed(1)} kbps · ${_netTypeName(s.networkType)}',
              style: TextStyle(
                  color: _purp, fontSize: 10, fontFamily: 'Courier New'),
              overflow: TextOverflow.ellipsis,
              maxLines: 1),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: s.isDataEnabled
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(s.isDataEnabled ? 'ON' : 'OFF',
              style: TextStyle(
                  color: s.isDataEnabled ? Colors.green : Colors.red,
                  fontSize: 8,
                  letterSpacing: 0.5)),
        ),
      ]),
    );
  }
}
