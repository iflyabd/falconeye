// =============================================================================
// FALCON EYE V50.0 — TACTICAL HUD PAGE
// Upgrades vs V49.8:
//   • Animated threat-level meter (BLE count + fusion pts → 0–100 threat index)
//   • Live cell tower strip (cellStreamProvider) with RSRP + type badges
//   • Compass ring painter (full 360° needle, cardinal labels)
//   • Stealth + subscription badges in header
//   • Quick-nav bottom strip: SIGINT / BLE / AI Brain / Radar / SDR
//   • No Random() anywhere
// =============================================================================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';
import '../services/hardware_capabilities_service.dart';
import '../services/imu_fusion_service.dart';
import '../services/ble_service.dart';
import '../services/wifi_csi_service.dart';
import '../services/multi_signal_fusion_service.dart';
import '../services/cell_service.dart';
import '../services/stealth_service.dart';
import '../services/subscription_service.dart';
import '../services/features_provider.dart';
import '../widgets/orientation_3d_view.dart';
import '../widgets/back_button_top_left.dart';
import '../models/vision_mode.dart';

// ── Quick nav entries ─────────────────────────────────────────────────────────
const _kQuickNav = [
  (Icons.wifi_tethering, 'SIGINT',     '/sigint'),
  (Icons.bluetooth,      'BLUETOOTH',  '/bluetooth'),
  (Icons.psychology,     'AI BRAIN',   '/ai_signal_brain'),
  (Icons.radar,          'RADAR',      '/real_radar'),
  (Icons.graphic_eq,     'SPECTRUM',   '/spectral'),
  (Icons.cell_tower,     'CELL',       '/interceptor_list'),
];

// =============================================================================
class TacticalHUDPage extends ConsumerStatefulWidget {
  const TacticalHUDPage({super.key});
  @override
  ConsumerState<TacticalHUDPage> createState() => _TacticalHUDPageState();
}

class _TacticalHUDPageState extends ConsumerState<TacticalHUDPage>
    with TickerProviderStateMixin {

  late final AnimationController _scanCtrl;
  late final AnimationController _threatCtrl;  // animates threat bar

  static const _kHistLen = 30;
  final List<double> _bleHistory  = [];
  final List<double> _wifiHistory = [];
  double _threatTarget = 0;

  @override
  void initState() {
    super.initState();
    _scanCtrl  = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
    _threatCtrl= AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(multiSignalFusionProvider.notifier).start();
      ref.read(cellServiceProvider).start();
    });
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _threatCtrl.dispose();
    super.dispose();
  }

  void _pushHistory(List<double> buf, double val) {
    buf.add(val);
    if (buf.length > _kHistLen) buf.removeAt(0);
  }

  // Threat index: 0–100, based on BLE device density + fusion point count
  double _computeThreat(int bleCount, int fusionPts, int cellCount) {
    final bleFactor    = (bleCount / 20.0).clamp(0.0, 1.0) * 40;
    final fusionFactor = (fusionPts / 500.0).clamp(0.0, 1.0) * 40;
    final cellFactor   = (cellCount / 5.0).clamp(0.0, 1.0) * 20;
    return bleFactor + fusionFactor + cellFactor;
  }

  @override
  Widget build(BuildContext context) {
    final color   = ref.watch(featuresProvider).primaryColor;
    final caps    = ref.watch(hardwareCapabilitiesProvider);
    final ori     = ref.watch(imuFusionProvider);
    final ble     = ref.watch(bleServiceProvider);
    final wifi    = ref.watch(wifiCSIProvider);
    final fusion  = ref.watch(multiSignalFusionProvider);
    final cells   = ref.watch(cellStreamProvider).value ?? const [];
    final stealth = ref.watch(stealthProtocolProvider);
    final sub     = ref.watch(subscriptionProvider);
    final size    = MediaQuery.of(context).size;

    // Feed sparklines
    if (ble.devices.isNotEmpty) {
      final avgRssi = ble.devices.map((d) => d.rssi.toDouble())
          .reduce((a, b) => a + b) / ble.devices.length;
      _pushHistory(_bleHistory, avgRssi.clamp(-100.0, 0.0) + 100);
    }
    if (wifi.rawData.isNotEmpty) {
      _pushHistory(_wifiHistory, (wifi.rawData.last.amplitude + 100).clamp(0.0, 100.0));
    }

    // Animate threat meter
    final newThreat = _computeThreat(
        ble.devices.length, fusion.fused3DEnvironment.length, cells.length);
    if ((newThreat - _threatTarget).abs() > 1) {
      _threatTarget = newThreat;
      _threatCtrl.animateTo(_threatTarget / 100,
          duration: const Duration(milliseconds: 800), curve: Curves.easeOut);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Scanline sweep
          AnimatedBuilder(
            animation: _scanCtrl,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _ScanlinePainter(_scanCtrl.value, color),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(color, caps, ori, stealth, sub),
                _buildFusionBanner(color, fusion),
                _buildThreatMeter(color),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildImuCompassRow(color, ori),
                        const SizedBox(height: 10),
                        _buildSparklines(color, ble, wifi),
                        const SizedBox(height: 10),
                        _buildCellStrip(color, cells),
                        const SizedBox(height: 10),
                        _buildLaunchButton(color, fusion),
                        const SizedBox(height: 10),
                        _buildModulesGrid(color, caps),
                        const SizedBox(height: 10),
                        _buildSignalSummary(color, ble, wifi, fusion, cells),
                      ],
                    ),
                  ),
                ),
                _buildQuickNav(color),
              ],
            ),
          ),
          const BackButtonTopLeft(),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────
  Widget _buildHeader(Color color, HardwareCapabilities caps,
      OrientationState ori, bool stealth, SubscriptionState sub) {
    final headingDeg = (_deg(ori.yaw) % 360 + 360) % 360;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.15))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('┌', style: TextStyle(color: color.withValues(alpha: 0.4), fontSize: 14)),
          const SizedBox(width: 6),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('FALCON EYE',
                style: TextStyle(color: color, fontSize: 20,
                    fontWeight: FontWeight.bold, letterSpacing: 5,
                    shadows: [Shadow(color: color, blurRadius: 10)])),
            Text('TACTICAL HUD  //  SOVEREIGN SIGINT V50.0',
                style: TextStyle(color: color.withValues(alpha: 0.5),
                    fontSize: 9, fontFamily: 'monospace', letterSpacing: 2)),
          ])),
          // Stealth badge
          if (stealth) ...[
            _MiniChip('STEALTH', Colors.red),
            const SizedBox(width: 6),
          ],
          // Subscription badge
          if (sub.isPremium)
            _MiniChip(sub.currentTier.name.toUpperCase(), const Color(0xFFFFD700)),
          const SizedBox(width: 6),
          // Compass ring (replaces flat badge)
          _CompassRing(heading: headingDeg, color: color, size: 52),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _HudChip('SPECTRUM',
              caps.wifi7.enabled ? '2.4–7.1 GHz' : '2.4–5.8 GHz', color),
          const SizedBox(width: 6),
          _HudChip('TIER',
              caps.tier1Flagship.enabled ? 'T1 ULTRA' : 'STANDARD', color),
          const SizedBox(width: 6),
          _HudChip('SDR',  caps.sdrUsb.enabled   ? 'READY' : 'N/A', color),
          const SizedBox(width: 6),
          _HudChip('UWB',  caps.uwbChipset.enabled ? 'PRESENT' : 'N/A', color),
        ]),
      ]),
    );
  }

  // ── Fusion banner ──────────────────────────────────────────────────────
  Widget _buildFusionBanner(Color color, MultiSignalFusionState fusion) {
    final active = fusion.isActive;
    final pts    = fusion.fused3DEnvironment.length;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      color: active
          ? color.withValues(alpha: 0.06)
          : Colors.orange.withValues(alpha: 0.04),
      child: Row(children: [
        _PulseDot(color: active ? color : Colors.orange),
        const SizedBox(width: 10),
        Expanded(child: Text(
          active
              ? 'MULTI-SIGNAL FUSION ACTIVE  ·  ${fusion.fusionRate}Hz  ·  $pts 3D PTS  ·  ${fusion.status}'
              : 'FUSION ENGINE IDLE  ·  ${fusion.status}',
          style: TextStyle(
            color: active ? color : Colors.orange,
            fontSize: 10, fontFamily: 'monospace', letterSpacing: 1,
          ),
        )),
        if (!active)
          GestureDetector(
            onTap: () => ref.read(multiSignalFusionProvider.notifier).start(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text('START',
                  style: TextStyle(color: Colors.orange, fontSize: 9,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
      ]),
    );
  }

  // ── Threat meter ────────────────────────────────────────────────────────
  Widget _buildThreatMeter(Color color) {
    return AnimatedBuilder(
      animation: _threatCtrl,
      builder: (_, __) {
        final val = _threatCtrl.value;          // 0.0 – 1.0
        final threatColor = Color.lerp(
          const Color(0xFF00FF41), Colors.red, val)!;
        final label = val < 0.25 ? 'LOW'
            : val < 0.55 ? 'MODERATE'
            : val < 0.80 ? 'ELEVATED'
            : 'CRITICAL';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          color: threatColor.withValues(alpha: 0.04),
          child: Row(children: [
            Text('THREAT', style: TextStyle(
                color: threatColor.withValues(alpha: 0.7),
                fontSize: 8, fontFamily: 'monospace', letterSpacing: 2)),
            const SizedBox(width: 8),
            Expanded(
              child: Stack(children: [
                Container(height: 4,
                    decoration: BoxDecoration(
                      color: threatColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    )),
                FractionallySizedBox(
                  widthFactor: val.clamp(0.0, 1.0),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: threatColor,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [BoxShadow(
                          color: threatColor.withValues(alpha: 0.6), blurRadius: 6)],
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(
                color: threatColor,
                fontSize: 8, fontFamily: 'monospace',
                fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(width: 6),
            Text('${(val * 100).toStringAsFixed(0)}',
                style: TextStyle(color: threatColor.withValues(alpha: 0.6),
                    fontSize: 8, fontFamily: 'monospace')),
          ]),
        );
      },
    );
  }

  // ── IMU + compass ring row ───────────────────────────────────────────────
  Widget _buildImuCompassRow(Color color, OrientationState ori) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.15)),
        color: color.withValues(alpha: 0.02),
      ),
      child: Row(children: [
        Expanded(
          child: Orientation3DView(
            roll:  ori.roll,
            pitch: ori.pitch,
            yaw:   ori.yaw,
            wireColor: color,
            fillColor: color.withValues(alpha: 0.12),
          ),
        ),
        const SizedBox(width: 12),
        Column(mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('IMU FUSION', style: TextStyle(
              color: color, fontSize: 9,
              fontFamily: 'monospace', letterSpacing: 2)),
          const SizedBox(height: 8),
          _imuLine('ROLL ',  _deg(ori.roll),  color),
          _imuLine('PITCH', _deg(ori.pitch), color),
          _imuLine('YAW  ',  _deg(ori.yaw),  color),
          const SizedBox(height: 8),
          Row(children: [
            Icon(ori.hasMag ? Icons.explore : Icons.explore_off,
                size: 13,
                color: ori.hasMag ? color : Colors.orange),
            const SizedBox(width: 5),
            Text(ori.hasMag ? 'MAG LOCK' : 'NO MAG',
                style: TextStyle(
                  color: ori.hasMag ? color : Colors.orange,
                  fontSize: 9, fontFamily: 'monospace',
                )),
          ]),
        ]),
      ]),
    );
  }

  Widget _imuLine(String label, double deg, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(children: [
      Text('$label  ', style: TextStyle(color: color.withValues(alpha: 0.5),
          fontSize: 10, fontFamily: 'monospace')),
      Text('${deg.toStringAsFixed(1)}°',
          style: TextStyle(color: color, fontSize: 10,
              fontFamily: 'monospace', fontWeight: FontWeight.bold)),
    ]),
  );

  // ── RSSI sparklines ──────────────────────────────────────────────────────
  Widget _buildSparklines(Color color, BleScanState ble, WiFiCSIState wifi) {
    return Row(children: [
      Expanded(child: _Sparkline(
        label: 'BLE AVG RSSI',
        history: _bleHistory,
        color: const Color(0xFF7986CB),
        value: ble.devices.isEmpty ? '--'
            : '${(ble.devices.map((d) => d.rssi).reduce((a, b) => a + b)
                / ble.devices.length).toStringAsFixed(0)} dBm',
        subLabel: '${ble.devices.length} devices',
      )),
      const SizedBox(width: 8),
      Expanded(child: _Sparkline(
        label: 'WIFI CSI AMP',
        history: _wifiHistory,
        color: const Color(0xFF00CCFF),
        value: wifi.rawData.isEmpty ? '--'
            : '${wifi.rawData.last.amplitude.toStringAsFixed(1)} dBm',
        subLabel: '${wifi.sampleRate}Hz  ·  ${wifi.rawData.length} pts',
      )),
    ]);
  }

  // ── Cell tower strip ─────────────────────────────────────────────────────
  Widget _buildCellStrip(Color color, List<CellularCell> cells) {
    const cellColor = Color(0xFF4FC3F7);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: cellColor.withValues(alpha: 0.2)),
        color: cellColor.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 3, height: 12,
              decoration: BoxDecoration(color: cellColor,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 6),
          Text('CELL TOWERS',
              style: TextStyle(color: cellColor, fontSize: 9,
                  fontFamily: 'monospace', letterSpacing: 2,
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('${cells.length} DETECTED',
              style: TextStyle(color: cellColor.withValues(alpha: 0.5),
                  fontSize: 8, fontFamily: 'monospace')),
        ]),
        const SizedBox(height: 6),
        if (cells.isEmpty)
          Text('AWAITING CELL DATA — LOCATION PERMISSION REQUIRED',
              style: TextStyle(color: cellColor.withValues(alpha: 0.3),
                  fontSize: 9, fontFamily: 'monospace'))
        else
          ...cells.take(4).map((c) {
            final rsrp  = c.rsrp ?? -999;
            final label = c.rsrp != null ? '$rsrp dBm' : 'N/A';
            final sigC  = rsrp > -80 ? const Color(0xFF00FF41)
                : rsrp > -100 ? Colors.orange : const Color(0xFFFF3333);
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: cellColor.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(c.type,
                      style: TextStyle(color: cellColor, fontSize: 7,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'MCC:${c.mcc} MNC:${c.mnc}'
                  '${c.earfcn != null ? "  EARFCN:${c.earfcn}" : ""}',
                  style: TextStyle(color: Colors.white70, fontSize: 9,
                      fontFamily: 'monospace'),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                )),
                Text(label,
                    style: TextStyle(color: sigC, fontSize: 9,
                        fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              ]),
            );
          }),
      ]),
    );
  }

  // ── Launch button ────────────────────────────────────────────────────────
  Widget _buildLaunchButton(Color color, MultiSignalFusionState fusion) {
    return GestureDetector(
      onTap: () => context.push('/neo_matrix', extra: {
        'hasRoot': ref.read(hardwareCapabilitiesProvider).rootAccess.enabled,
        'mode': VisionMode.neoMatrix.name,
      }),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 12)],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.code, color: color, size: 22),
          const SizedBox(width: 12),
          Column(mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('LAUNCH 3D NEO-MATRIX VISION',
                style: TextStyle(color: color, fontSize: 13,
                    fontWeight: FontWeight.bold, letterSpacing: 2)),
            Text('OpenGL ES 2.0  ·  6DoF  ·  ${fusion.fused3DEnvironment.length} pts ready',
                style: TextStyle(color: color.withValues(alpha: 0.5),
                    fontSize: 9, fontFamily: 'monospace')),
          ]),
          const SizedBox(width: 12),
          Icon(Icons.arrow_forward_ios, color: color.withValues(alpha: 0.5), size: 14),
        ]),
      ),
    );
  }

  // ── Operational modules grid ─────────────────────────────────────────────
  Widget _buildModulesGrid(Color color, HardwareCapabilities caps) {
    final modules = [
      (Icons.wifi_tethering, 'SIGINT',       'WiFi CSI + IQ analysis',     true,  '/sigint'),
      (Icons.monitor_heart,  'PLANET HEALTH','FFT bio-tomography',          true,  '/health'),
      (Icons.layers,         'GEOPHYSICAL',  '118-element metal detection', true,  '/geophysical'),
      (Icons.code,           'DIGITAL TWIN', '3D radio-wave visualization', true,  '/vision_config'),
      (Icons.satellite_alt,  'SDR-USB',      caps.sdrUsb.reason,
          caps.sdrUsb.enabled, '/rtl_sdr'),
      (Icons.radar,          'UWB RANGE',    caps.uwbChipset.reason,
          caps.uwbChipset.enabled, '/uwb_ranging'),
      (Icons.bluetooth,      'BLUETOOTH',    'BLE intercept + RSSI scan',  true,  '/bluetooth'),
      (Icons.psychology,     'AI BRAIN',     'Claude tactical analysis',   true,  '/ai_signal_brain'),
    ];
    return Column(children: [
      Row(children: [
        Container(width: 3, height: 14,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text('OPERATIONAL MODULES',
            style: TextStyle(color: color, fontSize: 10,
                fontWeight: FontWeight.bold, letterSpacing: 2)),
      ]),
      const SizedBox(height: 8),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 6,
          mainAxisSpacing: 6, childAspectRatio: 2.4,
        ),
        itemCount: modules.length,
        itemBuilder: (ctx, i) {
          final m = modules[i];
          return _ModuleCard(
            icon: m.$1, title: m.$2, subtitle: m.$3,
            enabled: m.$4, color: color,
            onTap: m.$4 ? () => context.push(m.$5) : null,
          );
        },
      ),
    ]);
  }

  // ── Signal summary ────────────────────────────────────────────────────────
  Widget _buildSignalSummary(Color color, BleScanState ble, WiFiCSIState wifi,
      MultiSignalFusionState fusion, List<CellularCell> cells) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.12)),
        color: color.withValues(alpha: 0.02),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SIGNAL ENVIRONMENT',
            style: TextStyle(color: color, fontSize: 9,
                fontFamily: 'monospace', letterSpacing: 2)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _SigStat('BLE',  '${ble.devices.length}',              'devices', const Color(0xFF7986CB)),
          _SigStat('WIFI', '${wifi.rawData.length}',             'pts',     const Color(0xFF00CCFF)),
          _SigStat('CELL', '${cells.length}',                    'towers',  const Color(0xFF4FC3F7)),
          _SigStat('3D',   '${fusion.fused3DEnvironment.length}','fused',   color),
          _SigStat('RATE', fusion.isActive ? '${fusion.fusionRate}' : '--', 'Hz', color),
        ]),
        if (ble.devices.isNotEmpty) ...[
          const SizedBox(height: 8),
          Divider(color: color.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 6),
          Text('TOP BLE DEVICES',
              style: TextStyle(color: color.withValues(alpha: 0.4),
                  fontSize: 8, fontFamily: 'monospace', letterSpacing: 1)),
          const SizedBox(height: 4),
          ...ble.devices.take(3).map((d) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(children: [
              const Icon(Icons.bluetooth, size: 10, color: Color(0xFF7986CB)),
              const SizedBox(width: 6),
              Expanded(child: Text(d.name.isEmpty ? d.id : d.name,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('${d.rssi} dBm',
                  style: TextStyle(color: _rssiColor(d.rssi), fontSize: 10,
                      fontFamily: 'monospace')),
            ]),
          )),
        ],
      ]),
    );
  }

  // ── Quick-nav strip ──────────────────────────────────────────────────────
  Widget _buildQuickNav(Color color) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: color.withValues(alpha: 0.12))),
      ),
      child: Row(
        children: _kQuickNav.map((entry) {
          final (icon, label, route) = entry;
          return Expanded(
            child: GestureDetector(
              onTap: () => context.push(route),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color.withValues(alpha: 0.65), size: 16),
                  const SizedBox(height: 3),
                  Text(label,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.45),
                        fontSize: 7, fontFamily: 'monospace', letterSpacing: 0.5,
                      )),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

Color _rssiColor(int rssi) {
  if (rssi > -60) return const Color(0xFF00FF41);
  if (rssi > -80) return Colors.orange;
  return const Color(0xFFFF3333);
}

double _deg(double r) => r * 180.0 / math.pi;

// =============================================================================
// SUBWIDGETS
// =============================================================================

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}
class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color,
        boxShadow: [BoxShadow(
            color: widget.color.withValues(alpha: 0.3 + 0.4 * _c.value),
            blurRadius: 6 + 6 * _c.value)],
      ),
    ),
  );
}

class _CompassRing extends StatelessWidget {
  final double heading;
  final Color color;
  final double size;
  const _CompassRing({required this.heading, required this.color, required this.size});

  String get _cardinal {
    const dirs = ['N','NE','E','SE','S','SW','W','NW'];
    return dirs[((heading + 22.5) / 45).floor() % 8];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: CustomPaint(
        painter: _CompassPainter(heading: heading, color: color),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_cardinal, style: TextStyle(color: color, fontSize: size * 0.22,
                fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            Text('${heading.toStringAsFixed(0)}°',
                style: TextStyle(color: color.withValues(alpha: 0.55),
                    fontSize: size * 0.13, fontFamily: 'monospace')),
          ]),
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double heading;
  final Color color;
  const _CompassPainter({required this.heading, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 2;

    // Ring
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = color.withValues(alpha: 0.15)
               ..style = PaintingStyle.stroke
               ..strokeWidth = 1.5);

    // Tick marks (8 cardinal)
    final tickPaint = Paint()..color = color.withValues(alpha: 0.35)..strokeWidth = 1;
    for (int i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - math.pi / 2;
      final inner = r - 5;
      canvas.drawLine(
        Offset(cx + inner * math.cos(a), cy + inner * math.sin(a)),
        Offset(cx + r    * math.cos(a), cy + r    * math.sin(a)),
        tickPaint,
      );
    }

    // Heading needle — red north
    final needleAngle = (heading - 0) * math.pi / 180 - math.pi / 2;
    final needlePaint = Paint()..color = const Color(0xFFFF3333)..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + (r - 6) * math.cos(needleAngle), cy + (r - 6) * math.sin(needleAngle)),
      needlePaint,
    );

    // South tail
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + (r * 0.4) * math.cos(needleAngle + math.pi),
             cy + (r * 0.4) * math.sin(needleAngle + math.pi)),
      Paint()..color = color.withValues(alpha: 0.3)..strokeWidth = 1.5
             ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.heading != heading;
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      border: Border.all(color: color.withValues(alpha: 0.6)),
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 8,
        fontWeight: FontWeight.bold, letterSpacing: 1)),
  );
}

class _HudChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _HudChip(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Flexible(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.25)),
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.5),
            fontSize: 7, fontFamily: 'monospace', letterSpacing: 1)),
        Text(value, style: TextStyle(color: color, fontSize: 9,
            fontWeight: FontWeight.bold)),
      ]),
    ),
  );
}

class _Sparkline extends StatelessWidget {
  final String label;
  final List<double> history;
  final Color color;
  final String value;
  final String subLabel;
  const _Sparkline({required this.label, required this.history,
      required this.color, required this.value, required this.subLabel});

  @override
  Widget build(BuildContext context) {
    final spots = history.isEmpty
        ? [const FlSpot(0, 0)]
        : history.asMap().entries
            .map((e) => FlSpot(e.key.toDouble(), e.value))
            .toList();

    return Container(
      height: 90,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.2)),
        color: color.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.6),
              fontSize: 8, fontFamily: 'monospace', letterSpacing: 1)),
          Text(value, style: TextStyle(color: color, fontSize: 11,
              fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ]),
        const SizedBox(height: 2),
        Expanded(
          child: history.length < 2
              ? Center(child: Text('AWAITING DATA',
                  style: TextStyle(color: color.withValues(alpha: 0.2),
                      fontSize: 8, fontFamily: 'monospace')))
              : LineChart(LineChartData(
                  gridData:  const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minY: 0, maxY: 100,
                  minX: 0, maxX: (history.length - 1).toDouble().clamp(1, 29),
                  lineBarsData: [LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 1.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withValues(alpha: 0.15),
                    ),
                  )],
                )),
        ),
        Text(subLabel, style: TextStyle(color: color.withValues(alpha: 0.35),
            fontSize: 8, fontFamily: 'monospace')),
      ]),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final Color color;
  final VoidCallback? onTap;
  const _ModuleCard({required this.icon, required this.title,
      required this.subtitle, required this.enabled,
      required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = enabled ? color : color.withValues(alpha: 0.25);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: c.withValues(alpha: enabled ? 0.05 : 0.02),
          border: Border.all(color: c.withValues(alpha: enabled ? 0.3 : 0.1)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(children: [
          Icon(icon, color: c, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(title, style: TextStyle(color: c, fontSize: 11,
                fontWeight: FontWeight.bold)),
            Text(subtitle, style: TextStyle(color: c.withValues(alpha: 0.5),
                fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(enabled ? 'ON' : 'N/A',
                style: TextStyle(color: c, fontSize: 7,
                    fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ]),
      ),
    );
  }
}

class _SigStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _SigStat(this.label, this.value, this.unit, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(color: color, fontSize: 18,
        fontWeight: FontWeight.bold, fontFamily: 'monospace')),
    Text(unit, style: TextStyle(color: color.withValues(alpha: 0.5),
        fontSize: 8, fontFamily: 'monospace')),
    Text(label, style: TextStyle(color: color.withValues(alpha: 0.4),
        fontSize: 8, letterSpacing: 1)),
  ]);
}

class _ScanlinePainter extends CustomPainter {
  final double progress;
  final Color color;
  const _ScanlinePainter(this.progress, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final y = progress * (size.height + 40) - 20;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.03), color.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(0, y - 20, size.width, 40));
    canvas.drawRect(Rect.fromLTWH(0, y - 20, size.width, 40), paint);
    final lp = Paint()..color = Colors.black.withValues(alpha: 0.06)..strokeWidth = 1;
    for (double ly = 0; ly < size.height; ly += 4) {
      canvas.drawLine(Offset(0, ly), Offset(size.width, ly), lp);
    }
  }
  @override
  bool shouldRepaint(_ScanlinePainter old) => old.progress != progress;
}
