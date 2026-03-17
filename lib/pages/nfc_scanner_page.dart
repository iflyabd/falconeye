// ═══════════════════════════════════════════════════════════════════════════
// FALCON EYE V48.1 — NFC TAG SCANNER
// Radar-pulse animation + UID entropy + NDEF decode.
// Uses NfcService (nfcProvider) which wraps nfc_manager.
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/nfc_service.dart';
import '../widgets/back_button_top_left.dart';

// ── Shannon entropy of UID bytes ─────────────────────────────────────────────
double _shannonEntropy(String uidHex) {
  if (uidHex.isEmpty) return 0.0;
  // Parse hex pairs
  final parts = uidHex.split(':');
  if (parts.isEmpty) return 0.0;
  final bytes = <int>[];
  for (final p in parts) {
    try { bytes.add(int.parse(p, radix: 16)); } catch (_) {}
  }
  if (bytes.isEmpty) return 0.0;
  final freq = <int, int>{};
  for (final b in bytes) freq[b] = (freq[b] ?? 0) + 1;
  double h = 0.0;
  final n = bytes.length;
  for (final count in freq.values) {
    final p = count / n;
    h -= p * (math.log(p) / math.log(2));
  }
  return h;
}

// ── Radar pulse painter ───────────────────────────────────────────────────────
class _RadarPainter extends CustomPainter {
  final double phase; // 0..1
  final Color color;
  _RadarPainter(this.phase, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = math.min(cx, cy);

    for (int i = 0; i < 4; i++) {
      final t = ((phase + i * 0.25) % 1.0);
      final r = t * maxR;
      final alpha = (1.0 - t).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = color.withValues(alpha: alpha * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
    // Centre dot
    canvas.drawCircle(Offset(cx, cy), 6,
        Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.phase != phase;
}

// ── Page ──────────────────────────────────────────────────────────────────────
class NfcScannerPage extends ConsumerStatefulWidget {
  const NfcScannerPage({super.key});
  @override
  ConsumerState<NfcScannerPage> createState() => _NfcScannerPageState();
}

class _NfcScannerPageState extends ConsumerState<NfcScannerPage>
    with SingleTickerProviderStateMixin {
  static const _grn = Color(0xFF00FF41);

  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(nfcProvider.notifier).startScanning();
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    ref.read(nfcProvider.notifier).stopScanning();
    super.dispose();
  }

  void _scanAgain() {
    ref.read(nfcProvider.notifier).stopScanning();
    ref.read(nfcProvider.notifier).startScanning();
  }

  @override
  Widget build(BuildContext context) {
    final nfc = ref.watch(nfcProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 40),
            child: Column(children: [
              // Header
              Row(children: [
                const Icon(Icons.nfc, color: _grn, size: 22),
                const SizedBox(width: 8),
                Text('NFC TAG SCANNER',
                    style: const TextStyle(
                        color: _grn,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2)),
              ]),
              const SizedBox(height: 4),
              Text('V48.1 — UID ENTROPY + NDEF DECODE',
                  style: TextStyle(
                      color: _grn.withValues(alpha: 0.4),
                      fontSize: 9,
                      letterSpacing: 1.5)),

              const SizedBox(height: 24),

              // Not supported warning
              if (!nfc.supported) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.08),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber, color: Colors.amber),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('NFC NOT SUPPORTED ON THIS DEVICE',
                          style: TextStyle(
                              color: Colors.amber,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                    ),
                  ]),
                ),
              ] else ...[
                // Radar animation
                SizedBox(
                  height: 180,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => CustomPaint(
                      size: const Size(double.infinity, 180),
                      painter: _RadarPainter(
                          nfc.scanning ? _pulse.value : 0.0, _grn),
                    ),
                  ),
                ),

                // Status
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: nfc.scanning
                            ? _grn.withValues(alpha: 0.6)
                            : Colors.grey.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(nfc.statusMessage,
                      style: TextStyle(
                          color: nfc.scanning ? _grn : Colors.grey,
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontFamily: 'Courier New')),
                ),

                // Tag info
                if (nfc.lastTag != null) _tagCard(nfc.lastTag!),

                const SizedBox(height: 20),

                // Buttons
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: nfc.lastTag == null
                          ? null
                          : () {
                              Clipboard.setData(
                                  ClipboardData(text: nfc.lastTag!.uidHex));
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'COPIED: ${nfc.lastTag!.uidHex}'),
                                    backgroundColor: Colors.green.shade900,
                                    duration: const Duration(seconds: 2)),
                              );
                            },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('COPY UID'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _grn,
                        side: BorderSide(
                            color: nfc.lastTag == null
                                ? _grn.withValues(alpha: 0.2)
                                : _grn),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _scanAgain,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('SCAN AGAIN'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _grn,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ]),
              ],
            ]),
          ),
          const BackButtonTopLeft(),
        ]),
      ),
    );
  }

  Widget _tagCard(NfcTagInfo tag) {
    final entropy = _shannonEntropy(tag.uidHex);
    final entropyLabel = entropy > 3.5
        ? 'RANDOM / GENUINE'
        : entropy > 2.0
            ? 'MODERATE RANDOMNESS'
            : 'LOW ENTROPY / POSSIBLE CLONE';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _grn.withValues(alpha: 0.04),
        border: Border.all(color: _grn.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _row('UID', tag.uidHex.isEmpty ? '(none)' : tag.uidHex),
        const SizedBox(height: 6),
        _row('TECH', tag.tech),
        const SizedBox(height: 6),
        _row('NDEF', tag.ndefAvailable ? 'AVAILABLE' : 'NOT PRESENT'),
        const SizedBox(height: 10),
        // Hex dump
        Text('HEX DUMP',
            style: TextStyle(
                color: _grn.withValues(alpha: 0.5),
                fontSize: 9,
                letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          color: Colors.black,
          child: Text(
            tag.uidHex.isEmpty
                ? '(empty)'
                : tag.uidHex
                    .split(':')
                    .asMap()
                    .entries
                    .map((e) =>
                        '${e.value}${(e.key + 1) % 8 == 0 ? "\n" : " "}')
                    .join(),
            style: const TextStyle(
                color: _grn,
                fontSize: 12,
                fontFamily: 'Courier New',
                height: 1.6),
          ),
        ),
        const SizedBox(height: 10),
        // Entropy
        Text(
            'UID ENTROPY: ${entropy.toStringAsFixed(2)} bits — $entropyLabel',
            style: TextStyle(
                color: entropy > 3.5
                    ? _grn
                    : entropy > 2.0
                        ? Colors.amber
                        : Colors.red,
                fontSize: 11,
                fontFamily: 'Courier New',
                letterSpacing: 0.5)),
        // NDEF records
        if (tag.ndefRecords.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('NDEF RECORDS',
              style: TextStyle(
                  color: _grn.withValues(alpha: 0.5),
                  fontSize: 9,
                  letterSpacing: 1.5)),
          ...tag.ndefRecords.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('[${e.key}] ${e.value}',
                    style: const TextStyle(
                        color: _grn,
                        fontSize: 11,
                        fontFamily: 'Courier New'),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2),
              )),
        ],
      ]),
    );
  }

  Widget _row(String label, String value) {
    return Row(children: [
      SizedBox(
        width: 56,
        child: Text(label,
            style: TextStyle(
                color: _grn.withValues(alpha: 0.5),
                fontSize: 10,
                letterSpacing: 1)),
      ),
      Expanded(
        child: Text(value,
            style: const TextStyle(
                color: _grn,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier New'),
            overflow: TextOverflow.ellipsis,
            maxLines: 1),
      ),
    ]);
  }
}
