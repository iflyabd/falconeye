// FALCON EYE — Live Signal Detail & RSSI History Page
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/signal_engine.dart';

class SignalDetailPage extends ConsumerWidget {
  const SignalDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(signalEngineProvider);
    final sources = env.sources;

    return Scaffold(
      backgroundColor: const Color(0xFF050A0F),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: const Color(0xFF00FF80),
        title: const Text('LIVE SIGNAL MAP',
            style: TextStyle(fontFamily: 'monospace', fontSize: 14, letterSpacing: 2)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: Text('${sources.length} src',
                style: const TextStyle(color: Color(0xFF3A9A3A), fontSize: 11, fontFamily: 'monospace'))),
          ),
        ],
      ),
      body: sources.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: sources.length,
              itemBuilder: (ctx, i) {
                final src = sources[i];
                final history = env.rssiHistory[src.id] ?? [];
                return _SignalCard(src: src, history: history);
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.wifi_off, color: Color(0xFF1A4A1A), size: 56),
      SizedBox(height: 12),
      Text('No signals detected', style: TextStyle(color: Color(0xFF3A6A3A),
          fontFamily: 'monospace', fontSize: 13)),
      SizedBox(height: 6),
      Text('Enable BLE and Location permissions', style: TextStyle(
          color: Color(0xFF2A4A2A), fontSize: 10, fontFamily: 'monospace')),
    ]),
  );
}

class _SignalCard extends StatelessWidget {
  final SignalSource src;
  final List<double> history;
  const _SignalCard({required this.src, required this.history});

  Color get _color {
    switch (src.type) {
      case 'BLE':  return const Color(0xFF00DCFF);
      case 'WiFi': return const Color(0xFF00FF78);
      case 'Cell': return const Color(0xFFFFA000);
      default:     return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rssiNorm = ((src.rssi + 100) / 70.0).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF080E08),
        border: Border.all(color: _color.withValues(alpha: src.isMoving ? 0.9 : 0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: _color), borderRadius: BorderRadius.circular(3)),
            child: Text(src.type, style: TextStyle(
                color: _color, fontSize: 9, fontFamily: 'monospace')),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(src.label, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _color, fontSize: 12,
                  fontFamily: 'monospace', fontWeight: FontWeight.bold))),
          if (src.isMoving) ...[
            const Icon(Icons.directions_run, color: Color(0xFFFFFF50), size: 14),
            const SizedBox(width: 2),
            const Text('MOVING', style: TextStyle(
                color: Color(0xFFFFFF50), fontSize: 8, fontFamily: 'monospace')),
          ],
        ]),
        const SizedBox(height: 8),
        // Signal metrics
        Row(children: [
          _Metric('RSSI', '${src.rssi.toStringAsFixed(1)} dBm', _color),
          _Metric('DIST', '${src.distance.toStringAsFixed(2)} m', _color),
          _Metric('AZ', '${(src.azimuth * 180 / math.pi).toStringAsFixed(1)}°', const Color(0xFF8A9A8A)),
          _Metric('EL', '${(src.elevation * 180 / math.pi).toStringAsFixed(1)}°', const Color(0xFF8A9A8A)),
          _Metric('CONF', '${(src.confidence * 100).toStringAsFixed(0)}%', _color),
        ]),
        const SizedBox(height: 6),
        // RSSI bar
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: rssiNorm,
            minHeight: 4,
            backgroundColor: _color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(_color),
          ),
        ),
        // RSSI history mini chart
        if (history.length >= 3) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: LineChart(
              LineChartData(
                minY: -110, maxY: -30,
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: history.asMap().entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value))
                        .toList(),
                    isCurved: true,
                    color: _color,
                    barWidth: 1.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _color.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(children: [
            Text('σ²=${src.rssiVariance.toStringAsFixed(1)}',
                style: const TextStyle(color: Color(0xFF5A7A5A), fontSize: 8, fontFamily: 'monospace')),
            const SizedBox(width: 8),
            Text('last ${history.length} samples',
                style: const TextStyle(color: Color(0xFF3A5A3A), fontSize: 8, fontFamily: 'monospace')),
          ]),
        ],
        // Position
        const SizedBox(height: 4),
        Text('pos: (${src.x.toStringAsFixed(2)}, ${src.y.toStringAsFixed(2)}, ${src.z.toStringAsFixed(2)}) m',
            style: const TextStyle(color: Color(0xFF3A5A3A), fontSize: 8, fontFamily: 'monospace')),
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label, value;
  final Color col;
  const _Metric(this.label, this.value, this.col);
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Color(0xFF3A6A3A), fontSize: 7.5, fontFamily: 'monospace')),
      Text(value, style: TextStyle(color: col, fontSize: 9.5, fontFamily: 'monospace'),
          overflow: TextOverflow.ellipsis),
    ]));
  }
}
