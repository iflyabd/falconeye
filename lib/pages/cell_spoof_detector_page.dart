import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/cell_spoof_detector_service.dart';
import '../services/features_provider.dart';
import '../widgets/back_button_top_left.dart';

class CellSpoofDetectorPage extends ConsumerStatefulWidget {
  const CellSpoofDetectorPage({super.key});
  @override
  ConsumerState<CellSpoofDetectorPage> createState() => _CellSpoofDetectorPageState();
}

class _CellSpoofDetectorPageState extends ConsumerState<CellSpoofDetectorPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cellSpoofDetectorProvider.notifier).startScanning();
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = ref.watch(featuresProvider).primaryColor;
    final state = ref.watch(cellSpoofDetectorProvider);
    final alerts = state.alerts..sort((a, b) => b.risk.index.compareTo(a.risk.index));
    final fmt = DateFormat('HH:mm:ss');

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────────
          _Header(color: color, state: state),
          // ── Risk banner ─────────────────────────────────────────────
          _RiskBanner(risk: state.overallRisk, color: color),
          const SizedBox(height: 8),
          // ── Stats row ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _Stat('TOWERS', '${alerts.length}', color),
              const SizedBox(width: 8),
              _Stat('ALERTS', '${state.activeAlerts.length}', state.overallRisk.riskColor(color)),
              const SizedBox(width: 8),
              _Stat('SCANS', '${state.scanCount}', color),
              const SizedBox(width: 8),
              _Stat('MCC/MNC', state.registeredMcc > 0
                  ? '${state.registeredMcc}/${state.registeredMnc}' : '---', color),
            ]),
          ),
          const SizedBox(height: 8),
          // ── Tower list ──────────────────────────────────────────────
          Expanded(
            child: alerts.isEmpty
                ? Center(child: Text('AWAITING CELL DATA...',
                    style: TextStyle(color: color.withValues(alpha: 0.5),
                        fontFamily: 'monospace', letterSpacing: 2)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: alerts.length,
                    itemBuilder: (_, i) => _TowerRow(alert: alerts[i], fmt: fmt),
                  ),
          ),
          // ── Controls ────────────────────────────────────────────────
          _Controls(color: color, state: state),
        ]),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Color color;
  final SpoofDetectorState state;
  const _Header({required this.color, required this.state});

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      const BackButtonTopLeft(),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CELL SPOOF DETECTOR', style: TextStyle(color: color, fontSize: 13,
            fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        Text('IMSI-CATCHER / ROGUE TOWER DETECTION',
            style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: state.isScanning ? Colors.greenAccent : Colors.red),
          color: (state.isScanning ? Colors.greenAccent : Colors.red).withValues(alpha: 0.08),
        ),
        child: Text(state.isScanning ? '◉ LIVE' : '○ IDLE',
            style: TextStyle(color: state.isScanning ? Colors.greenAccent : Colors.red,
                fontSize: 10, fontFamily: 'monospace')),
      ),
    ]),
  );
}

class _RiskBanner extends StatelessWidget {
  final SpoofRisk risk;
  final Color color;
  const _RiskBanner({required this.risk, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = risk.riskColor(color);
    final label = switch (risk) {
      SpoofRisk.none     => '✓ ALL TOWERS VERIFIED CLEAN',
      SpoofRisk.low      => '○ LOW RISK — BUILDING BASELINE',
      SpoofRisk.medium   => '⚠ MEDIUM RISK — VERIFY TOWERS',
      SpoofRisk.high     => '⚠⚠ HIGH RISK — ROGUE TOWER SUSPECTED',
      SpoofRisk.critical => '🚨 CRITICAL — IMSI-CATCHER DETECTED',
    };
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: 0.6)),
        color: c.withValues(alpha: 0.08),
      ),
      child: Row(children: [
        Icon(Icons.cell_tower, color: c, size: 16),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: c, fontSize: 11, fontFamily: 'monospace', letterSpacing: 1)),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.2)),
        color: color.withValues(alpha: 0.04),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 16, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'monospace')),
      ]),
    ),
  );
}

class _TowerRow extends StatelessWidget {
  final CellTowerAlert alert;
  final DateFormat fmt;
  const _TowerRow({required this.alert, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final c = alert.riskColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: 0.3)),
        color: c.withValues(alpha: 0.04),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: c.withValues(alpha: 0.15),
            child: Text(alert.riskLabel, style: TextStyle(color: c, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(alert.towerId,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'))),
          Text('${alert.rsrp} dBm',
              style: TextStyle(color: c, fontSize: 11, fontFamily: 'monospace')),
        ]),
        const SizedBox(height: 4),
        Text(alert.reason, style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace')),
        const SizedBox(height: 4),
        Text('First: ${fmt.format(alert.firstSeen)}  ·  Seen: ${alert.seenCount}×',
            style: const TextStyle(color: Colors.white30, fontSize: 9, fontFamily: 'monospace')),
      ]),
    );
  }
}

class _Controls extends ConsumerWidget {
  final Color color;
  final SpoofDetectorState state;
  const _Controls({required this.color, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.read(cellSpoofDetectorProvider.notifier);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Expanded(child: _Btn(
          label: state.isScanning ? 'STOP SCAN' : 'START SCAN',
          color: color,
          onTap: () => state.isScanning ? svc.stopScanning() : svc.startScanning(),
        )),
        const SizedBox(width: 8),
        Expanded(child: _Btn(label: 'CLEAR', color: Colors.red, onTap: svc.clearAlerts)),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        color: color.withValues(alpha: 0.08),
      ),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(color: color, fontFamily: 'monospace',
          fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
    ),
  );
}

extension on SpoofRisk {
  Color riskColor(Color fallback) {
    switch (this) {
      case SpoofRisk.none:     return Colors.greenAccent;
      case SpoofRisk.low:      return const Color(0xFF88FF00);
      case SpoofRisk.medium:   return const Color(0xFFFFD700);
      case SpoofRisk.high:     return const Color(0xFFFF8800);
      case SpoofRisk.critical: return const Color(0xFFFF2222);
    }
  }
}
