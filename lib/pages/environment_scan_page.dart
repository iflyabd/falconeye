// FALCON EYE — Environment Scan Page
// Shows ALL signal sources grouped by type with real statistics
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/signal_engine.dart';

class EnvironmentScanPage extends ConsumerWidget {
  const EnvironmentScanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(signalEngineProvider);
    final ble  = env.sources.where((s) => s.type == 'BLE').toList();
    final wifi = env.sources.where((s) => s.type == 'WiFi').toList();
    final cell = env.sources.where((s) => s.type == 'Cell').toList();
    final moving = env.sources.where((s) => s.isMoving).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF050A0F),
      appBar: AppBar(
        title: const Text('ENVIRONMENT SCAN',
            style: TextStyle(fontFamily: 'monospace', fontSize: 13, letterSpacing: 2)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                env.hasRoot ? '● ROOT' : '○ NO ROOT',
                style: TextStyle(
                  color: env.hasRoot ? const Color(0xFF00FF80) : Colors.orange,
                  fontFamily: 'monospace', fontSize: 10),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Summary cards
          Row(children: [
            _SummaryCard('BLE', ble.length, 'devices', const Color(0xFF00DCFF)),
            const SizedBox(width: 8),
            _SummaryCard('WiFi', wifi.length, 'APs', const Color(0xFF00FF78)),
            const SizedBox(width: 8),
            _SummaryCard('Cell', cell.length, 'towers', const Color(0xFFFFA000)),
            const SizedBox(width: 8),
            _SummaryCard('MOVE', moving.length, 'detected', const Color(0xFFFFFF50)),
          ]),
          const SizedBox(height: 16),

          // IMU readings
          _SectionHeader('DEVICE ORIENTATION'),
          _ImuCard(env.orientation),
          const SizedBox(height: 12),

          // Moving sources (highest priority)
          if (moving.isNotEmpty) ...[
            _SectionHeader('MOTION DETECTED (Δσ² > 4 dBm²)'),
            ...moving.map((s) => _FullSourceRow(s)),
            const SizedBox(height: 12),
          ],

          // WiFi
          if (wifi.isNotEmpty) ...[
            _SectionHeader('WiFi ACCESS POINTS  (${wifi.length})'),
            ...wifi.map((s) => _FullSourceRow(s)),
            const SizedBox(height: 12),
          ],

          // BLE
          if (ble.isNotEmpty) ...[
            _SectionHeader('BLUETOOTH DEVICES  (${ble.length})'),
            ...ble.map((s) => _FullSourceRow(s)),
            const SizedBox(height: 12),
          ],

          // Cell
          if (cell.isNotEmpty) ...[
            _SectionHeader('CELLULAR TOWERS  (${cell.length})'),
            ...cell.map((s) => _FullSourceRow(s)),
            const SizedBox(height: 12),
          ],

          if (env.sources.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text(
                'No signals detected.\nEnable BLE + Location permissions.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF2A5A2A), fontFamily: 'monospace', height: 1.6),
              )),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final String unit;
  final Color color;
  const _SummaryCard(this.label, this.count, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(children: [
          Text(label, style: TextStyle(color: color, fontSize: 8, fontFamily: 'monospace', letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text('$count', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(unit, style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 7.5, fontFamily: 'monospace')),
        ]),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Text(title, style: const TextStyle(
            color: Color(0xFF3A7A3A), fontSize: 9.5,
            fontFamily: 'monospace', letterSpacing: 1.5)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: const Color(0xFF0D2A0D))),
      ]),
    );
  }
}

class _ImuCard extends StatelessWidget {
  final DeviceOrientation o;
  const _ImuCard(this.o);
  @override
  Widget build(BuildContext context) {
    double deg(double r) => r * 180 / math.pi;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF080E08),
        border: Border.all(color: const Color(0xFF1A3A1A)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(children: [
        _ImuVal('ROLL',  '${deg(o.roll).toStringAsFixed(1)}°', const Color(0xFF8A9A8A)),
        _ImuVal('PITCH', '${deg(o.pitch).toStringAsFixed(1)}°', const Color(0xFF8A9A8A)),
        _ImuVal('YAW',   '${deg(o.yaw).toStringAsFixed(1)}°', const Color(0xFF00FF80)),
      ]),
    );
  }
}

class _ImuVal extends StatelessWidget {
  final String label, value;
  final Color col;
  const _ImuVal(this.label, this.value, this.col);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(label, style: const TextStyle(color: Color(0xFF3A6A3A), fontSize: 8, fontFamily: 'monospace')),
    const SizedBox(height: 2),
    Text(value, style: TextStyle(color: col, fontSize: 14, fontFamily: 'monospace')),
  ]));
}

class _FullSourceRow extends StatelessWidget {
  final SignalSource src;
  const _FullSourceRow(this.src);

  Color get _col {
    if (src.isMoving) return const Color(0xFFFFFF50);
    switch (src.type) {
      case 'BLE':  return const Color(0xFF00DCFF);
      case 'WiFi': return const Color(0xFF00FF78);
      case 'Cell': return const Color(0xFFFFA000);
      default:     return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rssiPct = ((src.rssi + 100) / 70.0).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _col.withValues(alpha: 0.04),
        border: Border.all(color: _col.withValues(alpha: src.isMoving ? 0.7 : 0.2)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(src.label, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _col, fontSize: 11, fontFamily: 'monospace')),
          const SizedBox(height: 3),
          Row(children: [
            Text('${src.rssi.toStringAsFixed(0)} dBm',
                style: const TextStyle(color: Color(0xFF7A9A7A), fontSize: 9, fontFamily: 'monospace')),
            const SizedBox(width: 10),
            Text('${src.distance.toStringAsFixed(1)} m',
                style: TextStyle(color: _col.withValues(alpha: 0.7), fontSize: 9, fontFamily: 'monospace')),
            const SizedBox(width: 10),
            if (src.isMoving)
              const Text('● MOVING',
                  style: TextStyle(color: Color(0xFFFFFF50), fontSize: 8, fontFamily: 'monospace')),
          ]),
        ])),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: rssiPct,
              minHeight: 5,
              backgroundColor: _col.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(_col),
            ),
          ),
        ),
      ]),
    );
  }
}
