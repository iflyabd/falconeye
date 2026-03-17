import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/signal_memory_service.dart';
import '../services/features_provider.dart';
import '../widgets/back_button_top_left.dart';

class SignalMemoryPage extends ConsumerStatefulWidget {
  const SignalMemoryPage({super.key});
  @override
  ConsumerState<SignalMemoryPage> createState() => _SignalMemoryPageState();
}

class _SignalMemoryPageState extends ConsumerState<SignalMemoryPage> {
  ThreatLevel? _filter;
  String _typeFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(signalMemoryProvider.notifier).startTracking();
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = ref.watch(featuresProvider).primaryColor;
    final mem = ref.watch(signalMemoryProvider);
    final fmt = DateFormat('MM/dd HH:mm');

    var entries = mem.allSorted;
    if (_filter != null) entries = entries.where((e) => e.threatLevel == _filter).toList();
    if (_typeFilter != 'ALL') entries = entries.where((e) => e.type == _typeFilter).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: Column(children: [
        // ── Header ──────────────────────────────────────────────────
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            const BackButtonTopLeft(),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AI SIGNAL MEMORY', style: TextStyle(color: color, fontSize: 13,
                  fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              Text('PERSISTENT THREAT PROFILES • ${mem.entries.length} DEVICES',
                  style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
            ])),
            _badge(mem.isTracking ? '◉ TRACKING' : '○ IDLE',
                mem.isTracking ? Colors.greenAccent : Colors.white38),
          ]),
        ),
        // ── Stats ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _statBox('TOTAL', '${mem.entries.length}', color),
            const SizedBox(width: 6),
            _statBox('THREATS', '${mem.threats.length}', const Color(0xFFFF2222)),
            const SizedBox(width: 6),
            _statBox('SUSPECT', '${mem.suspicious.length}', const Color(0xFFFFD700)),
            const SizedBox(width: 6),
            _statBox('SIGHTINGS', '${mem.totalSightings}', color),
          ]),
        ),
        const SizedBox(height: 8),
        // ── Threat banner ───────────────────────────────────────────
        if (mem.threats.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFFF2222).withValues(alpha: 0.5)),
              color: const Color(0xFFFF2222).withValues(alpha: 0.06),
            ),
            child: Row(children: [
              const Icon(Icons.warning, color: Color(0xFFFF2222), size: 14),
              const SizedBox(width: 6),
              Text('${mem.threats.length} THREAT PROFILE(S) — ${mem.threats.first.label} +${mem.threats.length - 1} more',
                  style: const TextStyle(color: Color(0xFFFF2222), fontSize: 10, fontFamily: 'monospace')),
            ]),
          ),
        const SizedBox(height: 8),
        // ── Filters ─────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _filterChip('ALL', _typeFilter == 'ALL' && _filter == null, color, () {
              setState(() { _typeFilter = 'ALL'; _filter = null; });
            }),
            const SizedBox(width: 6),
            _filterChip('BLE', _typeFilter == 'BLE', color, () => setState(() => _typeFilter = 'BLE')),
            const SizedBox(width: 6),
            _filterChip('Cell', _typeFilter == 'Cell', color, () => setState(() => _typeFilter = 'Cell')),
            const SizedBox(width: 6),
            _filterChip('⚠ THREATS', _filter == ThreatLevel.threat, const Color(0xFFFF2222),
                () => setState(() => _filter = _filter == ThreatLevel.threat ? null : ThreatLevel.threat)),
            const SizedBox(width: 6),
            _filterChip('? SUSPECT', _filter == ThreatLevel.suspicious, const Color(0xFFFFD700),
                () => setState(() => _filter = _filter == ThreatLevel.suspicious ? null : ThreatLevel.suspicious)),
          ]),
        ),
        const SizedBox(height: 8),
        // ── Entry list ──────────────────────────────────────────────
        Expanded(
          child: entries.isEmpty
              ? Center(child: Text('NO ENTRIES', style: TextStyle(
                  color: color.withValues(alpha: 0.4), fontFamily: 'monospace', letterSpacing: 2)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: entries.length,
                  itemBuilder: (_, i) => _EntryRow(entry: entries[i], fmt: fmt, color: color),
                ),
        ),
        // ── Controls ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: _actionBtn(
              mem.isTracking ? 'STOP' : 'TRACK',
              mem.isTracking ? Colors.orange : color,
              () => mem.isTracking
                  ? ref.read(signalMemoryProvider.notifier).stopTracking()
                  : ref.read(signalMemoryProvider.notifier).startTracking(),
            )),
            const SizedBox(width: 8),
            Expanded(child: _actionBtn('CLEAR ALL', Colors.red,
                () => ref.read(signalMemoryProvider.notifier).clearAll())),
          ]),
        ),
      ])),
    );
  }

  Widget _badge(String text, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(border: Border.all(color: c.withValues(alpha: 0.4))),
    child: Text(text, style: TextStyle(color: c, fontSize: 9, fontFamily: 'monospace')),
  );

  Widget _statBox(String label, String value, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: 0.25)),
        color: c.withValues(alpha: 0.04),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(color: c, fontSize: 16, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white30, fontSize: 8, fontFamily: 'monospace')),
      ]),
    ),
  );

  Widget _filterChip(String label, bool active, Color c, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: active ? c : Colors.white24),
        color: active ? c.withValues(alpha: 0.12) : Colors.transparent,
      ),
      child: Text(label, style: TextStyle(color: active ? c : Colors.white54,
          fontSize: 10, fontFamily: 'monospace')),
    ),
  );

  Widget _actionBtn(String label, Color c, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: 0.5)),
        color: c.withValues(alpha: 0.08),
      ),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(color: c, fontFamily: 'monospace', fontSize: 12,
          letterSpacing: 1.5, fontWeight: FontWeight.bold)),
    ),
  );
}

class _EntryRow extends ConsumerWidget {
  final SignalMemoryEntry entry;
  final DateFormat fmt;
  final Color color;
  const _EntryRow({required this.entry, required this.fmt, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tc = _threatColor(entry.threatLevel);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: tc.withValues(alpha: 0.25)),
        color: tc.withValues(alpha: 0.04),
      ),
      child: Row(children: [
        // Type badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          color: color.withValues(alpha: 0.12),
          child: Text(entry.type, style: TextStyle(color: color, fontSize: 8, fontFamily: 'monospace')),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry.label, style: const TextStyle(color: Colors.white, fontSize: 11,
              fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          Text('${entry.id.length > 20 ? entry.id.substring(0, 20) + '…' : entry.id}  ·  ${entry.seenCount}× seen',
              style: const TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'monospace')),
          if (entry.note.isNotEmpty)
            Text(entry.note, style: TextStyle(color: tc, fontSize: 9, fontFamily: 'monospace')),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            color: tc.withValues(alpha: 0.15),
            child: Text(entry.threatLabel, style: TextStyle(color: tc, fontSize: 8,
                fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Text(fmt.format(entry.lastSeen),
              style: const TextStyle(color: Colors.white30, fontSize: 8, fontFamily: 'monospace')),
          // Threat level up/down buttons
          Row(mainAxisSize: MainAxisSize.min, children: [
            _lvlBtn('▲', Colors.red, () => ref.read(signalMemoryProvider.notifier)
                .setThreatLevel(entry.id, ThreatLevel.threat)),
            const SizedBox(width: 4),
            _lvlBtn('✓', Colors.green, () => ref.read(signalMemoryProvider.notifier)
                .setThreatLevel(entry.id, ThreatLevel.clean)),
          ]),
        ]),
      ]),
    );
  }

  Widget _lvlBtn(String label, Color c, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(border: Border.all(color: c.withValues(alpha: 0.4))),
      child: Text(label, style: TextStyle(color: c, fontSize: 9)),
    ),
  );

  Color _threatColor(ThreatLevel level) {
    switch (level) {
      case ThreatLevel.unknown:    return Colors.white38;
      case ThreatLevel.clean:      return const Color(0xFF00FF41);
      case ThreatLevel.suspicious: return const Color(0xFFFFD700);
      case ThreatLevel.threat:     return const Color(0xFFFF2222);
    }
  }
}
