import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/signal_engine.dart';
import '../services/features_provider.dart';
import '../widgets/back_button_top_left.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  FALCON EYE V48.1 — COMPARATIVE BASELINE
//  Snapshot a "clean" environment, then continuously compare.
//  Detects: new devices, missing devices, signal level deviations.
// ═══════════════════════════════════════════════════════════════════════════════

class BaselineEntry {
  final String id;
  final String type;
  final String label;
  final double rssiMean;
  BaselineEntry({required this.id, required this.type, required this.label, required this.rssiMean});

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'label': label, 'rssiMean': rssiMean};
  factory BaselineEntry.fromJson(Map<String, dynamic> j) =>
      BaselineEntry(id: j['id'], type: j['type'], label: j['label'], rssiMean: (j['rssiMean'] as num).toDouble());
}

class BaselineDeviation {
  final BaselineEntry? baseline;   // null = new device (not in baseline)
  final SignalSource? current;     // null = device disappeared
  final String deviationType;     // 'new' | 'missing' | 'stronger' | 'weaker'
  final double delta;

  BaselineDeviation({this.baseline, this.current, required this.deviationType, this.delta = 0});

  String get label => current?.label ?? baseline?.label ?? 'Unknown';
  String get typeStr => current?.type ?? baseline?.type ?? '?';

  Color get color {
    switch (deviationType) {
      case 'new':      return const Color(0xFFFF8800);
      case 'missing':  return const Color(0xFFFF4444);
      case 'stronger': return const Color(0xFFFFD700);
      case 'weaker':   return const Color(0xFF88BBFF);
      default:         return Colors.white38;
    }
  }

  String get description {
    switch (deviationType) {
      case 'new':      return 'NEW DEVICE — not in baseline';
      case 'missing':  return 'MISSING — was in baseline';
      case 'stronger': return 'STRONGER +${delta.toStringAsFixed(0)}dBm — closer / new?';
      case 'weaker':   return 'WEAKER ${delta.toStringAsFixed(0)}dBm — interference?';
      default:         return '';
    }
  }
}

class SignalBaselinePage extends ConsumerStatefulWidget {
  const SignalBaselinePage({super.key});
  @override
  ConsumerState<SignalBaselinePage> createState() => _SignalBaselinePageState();
}

class _SignalBaselinePageState extends ConsumerState<SignalBaselinePage> {
  static const _kPrefsKey = 'falcon_baseline_v481';

  List<BaselineEntry> _baseline = [];
  DateTime? _baselineTime;
  List<BaselineDeviation> _deviations = [];
  bool _comparing = false;
  final _fmt = DateFormat('MM/dd HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _loadBaseline();
  }

  Future<void> _loadBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final entries = (map['entries'] as List).map((e) => BaselineEntry.fromJson(e as Map<String, dynamic>)).toList();
      final time = DateTime.parse(map['time']);
      if (mounted) setState(() { _baseline = entries; _baselineTime = time; });
    } catch (_) {}
  }

  Future<void> _saveBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, jsonEncode({
      'entries': _baseline.map((e) => e.toJson()).toList(),
      'time': _baselineTime!.toIso8601String(),
    }));
  }

  void _snapshot() {
    final sources = ref.read(signalEngineProvider).sources;
    _baseline = sources.map((s) => BaselineEntry(
      id: s.id, type: s.type, label: s.label, rssiMean: s.rssi,
    )).toList();
    _baselineTime = DateTime.now();
    _deviations = [];
    _saveBaseline();
    setState(() { _comparing = true; });
  }

  void _compare() {
    final sources = ref.read(signalEngineProvider).sources;
    final baseMap = {for (final b in _baseline) b.id: b};
    final currMap = {for (final s in sources) s.id: s};
    final deviations = <BaselineDeviation>[];

    // New devices not in baseline
    for (final s in sources) {
      if (!baseMap.containsKey(s.id)) {
        deviations.add(BaselineDeviation(current: s, deviationType: 'new'));
      } else {
        final b = baseMap[s.id]!;
        final delta = s.rssi - b.rssiMean;
        if (delta > 10) deviations.add(BaselineDeviation(baseline: b, current: s, deviationType: 'stronger', delta: delta));
        if (delta < -15) deviations.add(BaselineDeviation(baseline: b, current: s, deviationType: 'weaker', delta: delta));
      }
    }

    // Missing devices
    for (final b in _baseline) {
      if (!currMap.containsKey(b.id)) {
        deviations.add(BaselineDeviation(baseline: b, deviationType: 'missing'));
      }
    }

    setState(() => _deviations = deviations..sort((a, b) =>
        ['missing', 'new', 'stronger', 'weaker'].indexOf(a.deviationType)
            .compareTo(['missing', 'new', 'stronger', 'weaker'].indexOf(b.deviationType))));
  }

  @override
  Widget build(BuildContext context) {
    final color = ref.watch(featuresProvider).primaryColor;
    final sources = ref.watch(signalEngineProvider).sources;

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
              Text('SIGNAL BASELINE', style: TextStyle(color: color, fontSize: 13,
                  fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              Text('ENVIRONMENT DEVIATION DETECTOR',
                  style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
            ])),
          ]),
        ),
        // ── Baseline info ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: color.withValues(alpha: 0.3)),
              color: color.withValues(alpha: 0.04),
            ),
            child: Row(children: [
              Icon(Icons.compare, color: color, size: 14),
              const SizedBox(width: 8),
              Expanded(child: Text(
                _baselineTime == null
                    ? 'NO BASELINE — tap SNAPSHOT to capture current environment'
                    : 'BASELINE: ${_fmt.format(_baselineTime!)}  ·  ${_baseline.length} sources',
                style: TextStyle(color: color, fontSize: 10, fontFamily: 'monospace'),
              )),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        // ── Stats ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _stat('CURRENT', '${sources.length}', color),
            const SizedBox(width: 6),
            _stat('BASELINE', '${_baseline.length}', color.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
            _stat('NEW', '${_deviations.where((d) => d.deviationType == 'new').length}',
                const Color(0xFFFF8800)),
            const SizedBox(width: 6),
            _stat('MISSING', '${_deviations.where((d) => d.deviationType == 'missing').length}',
                const Color(0xFFFF4444)),
          ]),
        ),
        const SizedBox(height: 8),
        // ── Deviation list ───────────────────────────────────────────
        Expanded(
          child: _deviations.isEmpty
              ? Center(child: Text(
                  _baseline.isEmpty ? 'SNAPSHOT FIRST' : 'TAP COMPARE TO CHECK',
                  style: TextStyle(color: color.withValues(alpha: 0.4),
                      fontFamily: 'monospace', letterSpacing: 2)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _deviations.length,
                  itemBuilder: (_, i) => _DevRow(dev: _deviations[i]),
                ),
        ),
        // ── Controls ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: _btn('SNAPSHOT', color, _snapshot)),
            const SizedBox(width: 8),
            Expanded(child: _btn('COMPARE', const Color(0xFFFFD700),
                _baseline.isNotEmpty ? _compare : () {})),
            const SizedBox(width: 8),
            Expanded(child: _btn('CLEAR', Colors.red,
                () => setState(() { _baseline = []; _baselineTime = null; _deviations = []; }))),
          ]),
        ),
      ])),
    );
  }

  Widget _stat(String l, String v, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: 0.25)),
        color: c.withValues(alpha: 0.04),
      ),
      child: Column(children: [
        Text(v, style: TextStyle(color: c, fontSize: 15, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        Text(l, style: const TextStyle(color: Colors.white30, fontSize: 8, fontFamily: 'monospace')),
      ]),
    ),
  );

  Widget _btn(String label, Color c, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: 0.5)),
        color: c.withValues(alpha: 0.08),
      ),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(color: c, fontFamily: 'monospace',
          fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
    ),
  );
}

class _DevRow extends StatelessWidget {
  final BaselineDeviation dev;
  const _DevRow({required this.dev});

  @override
  Widget build(BuildContext context) {
    final c = dev.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: 0.35)),
        color: c.withValues(alpha: 0.05),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          color: c.withValues(alpha: 0.15),
          child: Text(dev.deviationType.toUpperCase(),
              style: TextStyle(color: c, fontSize: 8, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(dev.label, style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
          Text(dev.description, style: TextStyle(color: c.withValues(alpha: 0.8), fontSize: 9, fontFamily: 'monospace')),
        ])),
        Text(dev.typeStr, style: TextStyle(color: c.withValues(alpha: 0.5), fontSize: 9, fontFamily: 'monospace')),
      ]),
    );
  }
}
