import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/rf_fingerprint_service.dart';
import '../services/features_provider.dart';
import '../widgets/back_button_top_left.dart';

class RfFingerprintPage extends ConsumerStatefulWidget {
  const RfFingerprintPage({super.key});
  @override
  ConsumerState<RfFingerprintPage> createState() => _RfFingerprintPageState();
}

class _RfFingerprintPageState extends ConsumerState<RfFingerprintPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rfFingerprintProvider.notifier).startFingerprinting();
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = ref.watch(featuresProvider).primaryColor;
    final state = ref.watch(rfFingerprintProvider);
    final fps = state.fingerprints.values.toList()
      ..sort((a, b) => b.sampleCount.compareTo(a.sampleCount));

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
              Text('RF FINGERPRINTING', style: TextStyle(color: color, fontSize: 13,
                  fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              Text('HARDWARE IMPERFECTION IDENTIFIER • RE-IDs MAC-RANDOMISED DEVICES',
                  style: const TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'monospace')),
            ])),
            _badge(state.isActive ? '◉ ACTIVE' : '○ IDLE',
                state.isActive ? Colors.greenAccent : Colors.white38),
          ]),
        ),
        // ── Stats row ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _statTile('DEVICES', '${fps.length}', color),
            const SizedBox(width: 6),
            _statTile('RE-IDs', '${state.totalMatches}', const Color(0xFFFFD700)),
            const SizedBox(width: 6),
            _statTile('KNOWN', '${fps.where((f) => f.isKnown).length}', Colors.greenAccent),
          ]),
        ),
        const SizedBox(height: 8),
        // ── How it works info box ────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.2)),
            color: color.withValues(alpha: 0.04),
          ),
          child: Text(
            'FINGERPRINT = RSSI variance σ² + signal range + histogram pattern\n'
            'Devices matched across sessions even after MAC address randomisation.',
            style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9, fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(height: 8),
        // ── Fingerprint list ────────────────────────────────────────
        Expanded(
          child: fps.isEmpty
              ? Center(child: Text('AWAITING BLE DEVICES...',
                  style: TextStyle(color: color.withValues(alpha: 0.4),
                      fontFamily: 'monospace', letterSpacing: 2)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: fps.length,
                  itemBuilder: (_, i) => _FpRow(fp: fps[i], color: color),
                ),
        ),
        // ── Controls ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: _btn(
              state.isActive ? 'STOP' : 'START',
              color,
              () => state.isActive
                  ? ref.read(rfFingerprintProvider.notifier).stopFingerprinting()
                  : ref.read(rfFingerprintProvider.notifier).startFingerprinting(),
            )),
            const SizedBox(width: 8),
            Expanded(child: _btn('CLEAR', Colors.red,
                () => ref.read(rfFingerprintProvider.notifier).clearAll())),
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

  Widget _statTile(String label, String value, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: 0.25)),
        color: c.withValues(alpha: 0.04),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(color: c, fontSize: 18, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white30, fontSize: 9, fontFamily: 'monospace')),
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

class _FpRow extends ConsumerWidget {
  final RfFingerprint fp;
  final Color color;
  const _FpRow({required this.fp, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isReid = fp.matchedTo != null;
    final c = isReid ? const Color(0xFFFFD700) : (fp.isKnown ? Colors.greenAccent : color);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: 0.25)),
        color: c.withValues(alpha: 0.04),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(fp.type, style: TextStyle(color: color, fontSize: 8, fontFamily: 'monospace')),
          const SizedBox(width: 6),
          Expanded(child: Text(fp.label, style: const TextStyle(color: Colors.white,
              fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold))),
          if (isReid) ...[
            const Icon(Icons.fingerprint, color: Color(0xFFFFD700), size: 14),
            const SizedBox(width: 4),
            Text('${(fp.matchConfidence * 100).toStringAsFixed(0)}% match',
                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 9, fontFamily: 'monospace')),
          ],
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => ref.read(rfFingerprintProvider.notifier).markKnown(fp.deviceId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(border: Border.all(
                  color: fp.isKnown ? Colors.greenAccent : Colors.white24)),
              child: Text(fp.isKnown ? 'KNOWN' : 'MARK',
                  style: TextStyle(color: fp.isKnown ? Colors.greenAccent : Colors.white38,
                      fontSize: 8, fontFamily: 'monospace')),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        // Fingerprint feature bars
        _FpBar('MEAN', fp.rssiMean, -100, -20, c),
        _FpBar('VARIANCE', fp.rssiVariance, 0, 30, c),
        _FpBar('RANGE', fp.rssiMax - fp.rssiMin, 0, 40, c),
        const SizedBox(height: 2),
        Text('${fp.sampleCount} samples  ·  ID: ${fp.deviceId.length > 17 ? fp.deviceId.substring(0, 17) : fp.deviceId}',
            style: const TextStyle(color: Colors.white30, fontSize: 8, fontFamily: 'monospace')),
      ]),
    );
  }
}

class _FpBar extends StatelessWidget {
  final String label;
  final double value;
  final double min, max;
  final Color color;
  const _FpBar(this.label, this.value, this.min, this.max, this.color);

  @override
  Widget build(BuildContext context) {
    final frac = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(children: [
        SizedBox(width: 70, child: Text(label,
            style: const TextStyle(color: Colors.white30, fontSize: 8, fontFamily: 'monospace'))),
        Expanded(
          child: Stack(children: [
            Container(height: 4, color: Colors.white10),
            FractionallySizedBox(
              widthFactor: frac,
              child: Container(height: 4, color: color.withValues(alpha: 0.7)),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(value.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: TextStyle(color: color, fontSize: 8, fontFamily: 'monospace')),
        ),
      ]),
    );
  }
}
