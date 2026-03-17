// =============================================================================
// FALCON EYE V50.0 — REAL-TIME 3D RADIO RADAR
// Upgrades vs V48.1:
//   • Type filter toggle strip: ALL / BLE / WiFi / Cell
//   • IMU heading-lock button — rotY tracks device yaw in real time
//   • Tap on 3D point → selected source detail panel + RSSI history sparkline
//   • Reset orbit button (double-tap anywhere resets camera)
//   • Sovereign Glass HUD bar using featuresProvider.primaryColor
//   • Threat badge in HUD (source count + movement flag)
//   • Log toggle remembers state correctly (was always showing _showLogColor static)
//   • Zero Random()
// =============================================================================
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/signal_engine.dart';
import '../services/features_provider.dart';
import '../services/imu_fusion_service.dart';
import '../widgets/radar_3d_painter.dart';

// ── Filter options ────────────────────────────────────────────────────────────
enum _Filter { all, ble, wifi, cell }
extension _FilterX on _Filter {
  String get label => switch (this) {
    _Filter.all  => 'ALL',
    _Filter.ble  => 'BLE',
    _Filter.wifi => 'WiFi',
    _Filter.cell => 'Cell',
  };
  bool matches(String type) => switch (this) {
    _Filter.all  => true,
    _Filter.ble  => type == 'BLE',
    _Filter.wifi => type == 'WiFi',
    _Filter.cell => type == 'Cell',
  };
}

// =============================================================================
class RealRadarPage extends ConsumerStatefulWidget {
  const RealRadarPage({super.key});
  @override
  ConsumerState<RealRadarPage> createState() => _RealRadarPageState();
}

class _RealRadarPageState extends ConsumerState<RealRadarPage>
    with SingleTickerProviderStateMixin {
  // Camera orbit
  double _rotX = -0.30, _rotY = 0.0, _scale = 1.0;
  double _lastRotX = 0, _lastRotY = 0, _lastScale = 1;

  // UI state
  bool _showLog       = false;
  bool _headingLock   = false;
  _Filter _filter     = _Filter.all;
  String? _selectedId;         // tapped source

  Timer? _ticker;
  DateTime _tick = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (_headingLock) {
        final ori = ref.read(imuFusionProvider);
        setState(() {
          _rotY = -ori.yaw;           // mirror device yaw → camera yaw
          _tick = DateTime.now();
        });
      } else {
        setState(() => _tick = DateTime.now());
      }
    });
  }

  @override
  void dispose() { _ticker?.cancel(); super.dispose(); }

  void _resetCamera() {
    setState(() { _rotX = -0.30; _rotY = 0.0; _scale = 1.0; });
  }

  List<SignalSource> _filteredSources(List<SignalSource> all) =>
      _filter == _Filter.all ? all : all.where((s) => _filter.matches(s.type)).toList();

  @override
  Widget build(BuildContext context) {
    final env    = ref.watch(signalEngineProvider);
    final engine = ref.read(signalEngineProvider.notifier);
    final color  = ref.watch(featuresProvider).primaryColor;
    final filtered = _filteredSources(env.sources);
    final needsPerms = !env.permLocationGranted || !env.permBleGranted;
    final selected = _selectedId != null
        ? env.sources.where((s) => s.id == _selectedId).firstOrNull
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF040810),
      body: Stack(children: [

        // ── 3D radar canvas ────────────────────────────────────────────────
        RepaintBoundary(
          child: GestureDetector(
          onDoubleTap: _resetCamera,
          onScaleStart: (d) {
            _lastRotX = _rotX; _lastRotY = _rotY; _lastScale = _scale;
          },
          onScaleUpdate: (d) {
            if (_headingLock) return;           // locked — don't override yaw
            setState(() {
              _rotY  = _lastRotY + d.focalPointDelta.dx * 0.007;
              _rotX  = (_lastRotX - d.focalPointDelta.dy * 0.005).clamp(-1.3, 0.1);
              _scale = (_lastScale * d.scale).clamp(0.25, 6.0);
            });
          },
          onTapUp: (d) => _handleTap(d.localPosition, filtered, context),
          child: CustomPaint(
            painter: RadarPainter3D(
              sources: filtered,
              orientation: env.orientation,
              rotX: _rotX, rotY: _rotY, scale: _scale, tick: _tick,
            ),
            size: Size.infinite,
          ),
        ),
        ), // RepaintBoundary

        SafeArea(
          child: Column(children: [
            _buildHudBar(env, engine, color, filtered),
            _buildFilterStrip(color),
            const Spacer(),
          ]),
        ),

        // ── Permission banner ──────────────────────────────────────────────
        if (needsPerms)
          Positioned(
            top: 108, left: 8, right: 8,
            child: _PermBanner(engine: engine),
          ),

        // ── Debug log overlay ──────────────────────────────────────────────
        if (_showLog)
          Positioned(
            top: needsPerms ? 180 : 108, left: 8, right: 8, height: 200,
            child: _LogPanel(log: env.log, color: color),
          ),

        // ── Selected source detail panel ───────────────────────────────────
        if (selected != null)
          Positioned(
            right: 8, top: needsPerms ? 180 : 108,
            width: 180,
            child: _SourceDetailPanel(
              source: selected,
              history: env.rssiHistory[selected.id] ?? [],
              color: color,
              onClose: () => setState(() => _selectedId = null),
            ),
          ),

        // ── IMU heading lock + reset FABs ──────────────────────────────────
        Positioned(
          right: 12, bottom: 230,
          child: Column(children: [
            _RadarFab(
              icon: _headingLock ? Icons.explore : Icons.explore_off,
              label: _headingLock ? 'LOCK' : 'FREE',
              color: _headingLock ? color : color.withValues(alpha: 0.4),
              onTap: () => setState(() {
                _headingLock = !_headingLock;
                if (!_headingLock) _rotY = 0;
              }),
            ),
            const SizedBox(height: 10),
            _RadarFab(
              icon: Icons.crop_free,
              label: 'RESET',
              color: color.withValues(alpha: 0.4),
              onTap: _resetCamera,
            ),
          ]),
        ),

        // ── Bottom signal list ─────────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: SafeArea(
            top: false,
            child: _SignalList(
              env: env,
              filtered: filtered,
              color: color,
              selectedId: _selectedId,
              onSelect: (id) => setState(() =>
                  _selectedId = _selectedId == id ? null : id),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Tap detection: find nearest projected source ─────────────────────────
  void _handleTap(Offset tapPos, List<SignalSource> sources, BuildContext ctx) {
    if (sources.isEmpty) return;
    const hitRadius = 28.0;
    final size = ctx.size ?? MediaQuery.of(ctx).size;
    SignalSource? best;
    double bestDist = hitRadius;
    for (final s in sources) {
      final p = _project3D(s, size);
      final d = (p - tapPos).distance;
      if (d < bestDist) { bestDist = d; best = s; }
    }
    setState(() => _selectedId = best?.id);
  }

  // Mirror the painter's projection to find 2D tap position
  Offset _project3D(SignalSource s, Size sz) {
    final ax = s.azimuth, el = s.elevation;
    final dist = s.distance.clamp(0.3, 80.0);
    final x = dist * math.sin(ax) * math.cos(el);
    final y = dist * math.sin(el);
    final z = dist * math.cos(ax) * math.cos(el);
    final cy = math.cos(_rotY), sy = math.sin(_rotY);
    final x1 = x * cy - z * sy;
    final z1 = x * sy + z * cy;
    final cx = math.cos(_rotX), sx = math.sin(_rotX);
    final y2 = y * cx - z1 * sx;
    final z2 = y * sx + z1 * cx;
    final fov   = sz.height * 0.50 * _scale;
    final depth = z2 + 9.0;
    if (depth < 0.1) return Offset(sz.width / 2, sz.height * 0.38);
    return Offset(
      (x1 / depth) * fov + sz.width / 2,
      -(y2 / depth) * fov + sz.height * 0.38,
    );
  }

  // ── HUD Bar ──────────────────────────────────────────────────────────────
  Widget _buildHudBar(EnvironmentState env, SignalEngine engine,
      Color color, List<SignalSource> filtered) {
    final ble  = env.sources.where((s) => s.type == 'BLE').length;
    final wifi = env.sources.where((s) => s.type == 'WiFi').length;
    final cell = env.sources.where((s) => s.type == 'Cell').length;
    final moving = env.sources.where((s) => s.isMoving).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.88),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Icon(Icons.arrow_back_ios_new, color: color, size: 18),
        ),
        const SizedBox(width: 8),
        Text('RADAR', style: TextStyle(color: color, fontSize: 13,
            fontWeight: FontWeight.bold, letterSpacing: 2,
            fontFamily: 'monospace')),
        const SizedBox(width: 6),
        _LiveBadge(color: color),
        const Spacer(),
        // Type counters
        _TypeBadge('BLE',  ble,  const Color(0xFF00DCFF)),
        const SizedBox(width: 4),
        _TypeBadge('WiFi', wifi, const Color(0xFF00FF78)),
        const SizedBox(width: 4),
        _TypeBadge('Cell', cell, const Color(0xFFFFA000)),
        const SizedBox(width: 6),
        // Moving threat badge
        if (moving > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.yellow.withValues(alpha: 0.7)),
              color: Colors.yellow.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.moving, color: Colors.yellow, size: 10),
              const SizedBox(width: 3),
              Text('$moving', style: const TextStyle(
                  color: Colors.yellow, fontSize: 8, fontFamily: 'monospace')),
            ]),
          ),
          const SizedBox(width: 6),
        ],
        // Root
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: env.hasRoot ? color : Colors.orange),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(env.hasRoot ? 'ROOT' : 'USER',
              style: TextStyle(fontSize: 8, fontFamily: 'monospace',
                  color: env.hasRoot ? color : Colors.orange)),
        ),
        const SizedBox(width: 6),
        // Log toggle
        GestureDetector(
          onTap: () => setState(() => _showLog = !_showLog),
          child: Icon(Icons.terminal,
              color: _showLog ? color : color.withValues(alpha: 0.35), size: 18),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: engine.restartScan,
          child: Icon(Icons.refresh, color: color, size: 18),
        ),
      ]),
    );
  }

  // ── Filter strip ─────────────────────────────────────────────────────────
  Widget _buildFilterStrip(Color color) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 5, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(children: [
        ..._Filter.values.map((f) {
          final active = _filter == f;
          final c = switch (f) {
            _Filter.all  => color,
            _Filter.ble  => const Color(0xFF00DCFF),
            _Filter.wifi => const Color(0xFF00FF78),
            _Filter.cell => const Color(0xFFFFA000),
          };
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: active ? c.withValues(alpha: 0.18) : Colors.transparent,
                border: Border.all(color: active ? c : c.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(f.label,
                  style: TextStyle(
                    color: active ? c : c.withValues(alpha: 0.4),
                    fontSize: 9, fontFamily: 'monospace',
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    letterSpacing: 1,
                  )),
            ),
          );
        }),
        const Spacer(),
        Text('DBL-TAP RESET', style: TextStyle(
            color: color.withValues(alpha: 0.2),
            fontSize: 7, fontFamily: 'monospace')),
      ]),
    );
  }
}

// =============================================================================
// SUBWIDGETS
// =============================================================================

class _LiveBadge extends StatefulWidget {
  final Color color;
  const _LiveBadge({required this.color});
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}
class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.04 + 0.06 * _c.value),
        border: Border.all(color: widget.color.withValues(alpha: 0.4 + 0.4 * _c.value)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text('LIVE', style: TextStyle(color: widget.color,
          fontSize: 8, fontFamily: 'monospace', letterSpacing: 1,
          fontWeight: FontWeight.bold)),
    ),
  );
}

class _TypeBadge extends StatelessWidget {
  final String label; final int count; final Color color;
  const _TypeBadge(this.label, this.count, this.color);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 6, height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 3),
    Text('$label:$count', style: TextStyle(color: color, fontSize: 9,
        fontFamily: 'monospace')),
  ]);
}

class _RadarFab extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _RadarFab({required this.icon, required this.label,
      required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 18),
        Text(label, style: TextStyle(color: color, fontSize: 6,
            fontFamily: 'monospace', letterSpacing: 0.5)),
      ]),
    ),
  );
}

// ── Source detail panel ───────────────────────────────────────────────────────
class _SourceDetailPanel extends StatelessWidget {
  final SignalSource source;
  final List<double> history;
  final Color color;
  final VoidCallback onClose;
  const _SourceDetailPanel({required this.source, required this.history,
      required this.color, required this.onClose});

  Color get _typeColor => switch (source.type) {
    'BLE'  => const Color(0xFF00DCFF),
    'WiFi' => const Color(0xFF00FF78),
    'Cell' => const Color(0xFFFFA000),
    _      => Colors.white54,
  };

  @override
  Widget build(BuildContext context) {
    final spots = history.isEmpty
        ? [const FlSpot(0, 0)]
        : history.asMap().entries
            .map((e) => FlSpot(e.key.toDouble(), e.value.clamp(-120.0, 0.0) + 120))
            .toList();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.92),
        border: Border.all(color: _typeColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: _typeColor.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(source.type, style: TextStyle(color: _typeColor,
                fontSize: 8, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(source.label,
              style: TextStyle(color: _typeColor, fontSize: 9,
                  fontFamily: 'monospace', fontWeight: FontWeight.bold),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          GestureDetector(onTap: onClose,
              child: Icon(Icons.close, color: color.withValues(alpha: 0.4), size: 14)),
        ]),
        const SizedBox(height: 8),
        _row('RSSI',  '${source.rssi.toStringAsFixed(1)} dBm'),
        _row('DIST',  '${source.distance.toStringAsFixed(1)} m'),
        _row('AZ',    '${(source.azimuth * 180 / math.pi).toStringAsFixed(1)}°'),
        _row('EL',    '${(source.elevation * 180 / math.pi).toStringAsFixed(1)}°'),
        if (source.isMoving)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              Icon(Icons.moving, color: Colors.yellow, size: 10),
              const SizedBox(width: 4),
              const Text('MOVING', style: TextStyle(color: Colors.yellow,
                  fontSize: 8, fontFamily: 'monospace')),
            ]),
          ),
        if (source.extraInfo != null) ...[
          const SizedBox(height: 4),
          Text(source.extraInfo!,
              style: TextStyle(color: _typeColor.withValues(alpha: 0.5),
                  fontSize: 8, fontFamily: 'monospace'),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
        if (history.length >= 2) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: LineChart(LineChartData(
              gridData:   const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              minY: 0, maxY: 120,
              lineBarsData: [LineChartBarData(
                spots: spots,
                isCurved: true,
                color: _typeColor,
                barWidth: 1.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: _typeColor.withValues(alpha: 0.12),
                ),
              )],
            )),
          ),
          Text('RSSI HISTORY  ·  ${history.length} samples',
              style: TextStyle(color: _typeColor.withValues(alpha: 0.35),
                  fontSize: 7, fontFamily: 'monospace')),
        ],
      ]),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: _typeColor.withValues(alpha: 0.45),
          fontSize: 8, fontFamily: 'monospace')),
      Text(value, style: TextStyle(color: _typeColor, fontSize: 8,
          fontFamily: 'monospace', fontWeight: FontWeight.bold)),
    ]),
  );
}

// ── Permission Banner ─────────────────────────────────────────────────────────
class _PermBanner extends ConsumerWidget {
  final SignalEngine engine;
  const _PermBanner({required this.engine});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env   = ref.watch(signalEngineProvider);
    final color = ref.watch(featuresProvider).primaryColor;
    final lines = <String>[];
    if (!env.permLocationGranted) lines.add('• Location (required for BLE scan)');
    if (!env.permBleGranted)      lines.add('• Bluetooth Scan');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0800),
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('PERMISSIONS NEEDED', style: TextStyle(
            color: Colors.orange, fontSize: 10,
            fontFamily: 'monospace', letterSpacing: 1.5)),
        const SizedBox(height: 4),
        ...lines.map((l) => Text(l, style: const TextStyle(
            color: Color(0xFFCCCCCC), fontSize: 10, fontFamily: 'monospace'))),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => engine.requestPermissionsAndRetry(),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              border: Border.all(color: Colors.orange),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(child: Text('GRANT PERMISSIONS',
                style: TextStyle(color: Colors.orange, fontSize: 11,
                    fontFamily: 'monospace', fontWeight: FontWeight.bold))),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Cell signals available without permissions.\n'
          'BLE requires Location + Bluetooth Scan.',
          style: TextStyle(color: Color(0xFF8A6A2A),
              fontSize: 8.5, fontFamily: 'monospace'),
        ),
      ]),
    );
  }
}

// ── Log Panel ─────────────────────────────────────────────────────────────────
class _LogPanel extends StatelessWidget {
  final List<String> log;
  final Color color;
  const _LogPanel({required this.log, required this.color});
  @override
  Widget build(BuildContext context) {
    final lines = log.reversed.take(35).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.92),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(6),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines.map((l) => Text(l,
            style: TextStyle(color: color.withValues(alpha: 0.75),
                fontSize: 8.5, fontFamily: 'monospace', height: 1.4),
          )).toList(),
        ),
      ),
    );
  }
}

// ── Signal list ───────────────────────────────────────────────────────────────
class _SignalList extends StatelessWidget {
  final EnvironmentState env;
  final List<SignalSource> filtered;
  final Color color;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  const _SignalList({required this.env, required this.filtered,
      required this.color, this.selectedId, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    final visible = filtered.take(6).toList();
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('NEAREST SIGNALS',
              style: TextStyle(color: color, fontSize: 9,
                  fontFamily: 'monospace', letterSpacing: 1.5,
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('${filtered.length} / ${env.sources.length} TOTAL',
              style: TextStyle(color: color.withValues(alpha: 0.35),
                  fontSize: 8, fontFamily: 'monospace')),
        ]),
        const SizedBox(height: 4),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              env.permLocationGranted && env.permBleGranted
                  ? 'Scanning... no signals detected yet'
                  : 'Grant Location + Bluetooth to detect BLE signals',
              style: TextStyle(color: color.withValues(alpha: 0.3),
                  fontSize: 10, fontFamily: 'monospace'),
            ),
          )
        else
          ...visible.map((s) => _SourceRow(
            src: s,
            selected: s.id == selectedId,
            onTap: () => onSelect(s.id),
          )),
      ]),
    );
  }
}

class _SourceRow extends StatelessWidget {
  final SignalSource src;
  final bool selected;
  final VoidCallback onTap;
  const _SourceRow({required this.src, required this.selected, required this.onTap});

  Color get _col => switch (src.type) {
    'BLE'  => const Color(0xFF00DCFF),
    'WiFi' => const Color(0xFF00FF78),
    'Cell' => const Color(0xFFFFA000),
    _      => Colors.white54,
  };

  @override
  Widget build(BuildContext context) {
    final bars = ((src.rssi + 100) / 70.0 * 5).round().clamp(0, 5);
    final dist = src.distance < 100
        ? '${src.distance.toStringAsFixed(1)}m' : '>100m';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? _col.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(color: selected
              ? _col.withValues(alpha: 0.5) : Colors.transparent),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(children: [
          Container(
            width: 40, padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            decoration: BoxDecoration(
              border: Border.all(color: _col.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(src.type, textAlign: TextAlign.center,
                style: TextStyle(color: _col, fontSize: 7.5, fontFamily: 'monospace')),
          ),
          const SizedBox(width: 5),
          Expanded(child: Text(src.label, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _col.withValues(alpha: 0.9),
                  fontSize: 9.5, fontFamily: 'monospace'))),
          Text('${src.rssi.toStringAsFixed(0)}dBm',
              style: const TextStyle(color: Color(0xFF8A9A8A),
                  fontSize: 9, fontFamily: 'monospace')),
          const SizedBox(width: 5),
          Text(dist, style: TextStyle(color: _col, fontSize: 9,
              fontFamily: 'monospace')),
          const SizedBox(width: 5),
          Row(mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) => Container(
              width: 3, height: 4.0 + i * 1.5,
              margin: const EdgeInsets.only(right: 1),
              color: i < bars ? _col : _col.withValues(alpha: 0.12),
            ))),
          const SizedBox(width: 3),
          if (src.isMoving)
            Icon(Icons.radio_button_unchecked,
                color: Colors.yellow.shade600, size: 10),
          if (src.extraInfo != null) ...[
            const SizedBox(width: 4),
            Text(src.extraInfo!, style: TextStyle(
                color: _col.withValues(alpha: 0.45),
                fontSize: 7.5, fontFamily: 'monospace')),
          ],
        ]),
      ),
    );
  }
}
