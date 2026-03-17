// =============================================================================
// FALCON EYE V48.1 -- RAW SIGINT PAGE
// Live scrolling display of real Wi-Fi / BLE / Cell / Mag / CSI raw packets.
// Zero mock data -- all values sourced from SignalEngine + WiFiCSIService.
// =============================================================================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/signal_engine.dart';
import '../services/wifi_csi_service.dart';
import '../services/features_provider.dart';
import '../widgets/back_button_top_left.dart';
import '../theme.dart';

class RawSigintPage extends ConsumerWidget {
  const RawSigintPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(signalEngineProvider);
    final csi = ref.watch(wifiCSIProvider);
    final features = ref.watch(featuresProvider);
    final color = features.primaryColor;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(color),
                _buildStatusRow(env, csi, color),
                Expanded(child: _buildLogStream(env, csi, color)),
              ],
            ),
            const BackButtonTopLeft(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 40),
          Icon(Icons.terminal, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            'RAW SIGINT STREAM',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              border: Border.all(color: color.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              'V47.7',
              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(EnvironmentState env, WiFiCSIState csi, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: color.withValues(alpha: 0.03),
      child: Row(
        children: [
          _badge('BLE', env.bleScanning, color),
          _badge('WiFi', env.wifiScanning, color),
          _badge('Cell', env.cellActive, color),
          _badge('CSI', csi.isCapturing, color),
          _badge('Root', env.hasRoot, color),
          const Spacer(),
          Text(
            '${env.sources.length} SRC',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, bool active, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
        border: Border.all(
          color: active ? color : color.withValues(alpha: 0.2),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? color : color.withValues(alpha: 0.3),
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLogStream(EnvironmentState env, WiFiCSIState csi, Color color) {
    final lines = <_LogLine>[];

    // Real signal sources
    for (final src in env.sources) {
      lines.add(_LogLine(
        type: src.type,
        text:
            '[${src.type}] ${src.label}  RSSI:${src.rssi.toStringAsFixed(0)}dBm  '
            'Dist:${src.distance.toStringAsFixed(1)}m  '
            'Az:${(src.azimuth * 180 / math.pi).toStringAsFixed(0)}\u00B0  '
            'Conf:${(src.confidence * 100).toStringAsFixed(0)}%'
            '${src.isMoving ? "  MOVING" : ""}',
        color: _typeColor(src.type),
      ));
    }

    // CSI data points
    for (final pt in csi.rawData.take(5)) {
      lines.add(_LogLine(
        type: 'CSI',
        text:
            '[CSI] Sub:${pt.subcarrierIndex}  Amp:${pt.amplitude.toStringAsFixed(1)}dBm  '
            'Phase:${pt.phase.toStringAsFixed(2)}rad  '
            'SNR:${pt.snr.toStringAsFixed(1)}  '
            'Freq:${(pt.frequency / 1e9).toStringAsFixed(2)}GHz',
        color: const Color(0xFF00FF88),
      ));
    }

    // Engine log
    for (final log in env.log.reversed.take(30)) {
      lines.add(_LogLine(type: 'LOG', text: log, color: color.withValues(alpha: 0.5)));
    }

    if (lines.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.signal_cellular_off, color: color.withValues(alpha: 0.2), size: 48),
            const SizedBox(height: 12),
            Text(
              'AWAITING SIGNAL DATA',
              style: TextStyle(
                color: color.withValues(alpha: 0.3),
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enable BLE + Location permissions',
              style: TextStyle(color: color.withValues(alpha: 0.2), fontSize: 10),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Text(
            line.text,
            style: TextStyle(
              color: line.color,
              fontSize: 9,
              fontFamily: 'monospace',
              height: 1.4,
            ),
          ),
        );
      },
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'BLE':
        return const Color(0xFF00DCFF);
      case 'WiFi':
        return const Color(0xFF00FF78);
      case 'Cell':
        return const Color(0xFFFFA000);
      default:
        return const Color(0xFFCCCCCC);
    }
  }
}

class _LogLine {
  final String type;
  final String text;
  final Color color;
  const _LogLine({required this.type, required this.text, required this.color});
}
