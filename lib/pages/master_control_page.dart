// =============================================================================
// FALCON EYE V50.0 — MASTER CONTROL INDEX PAGE
// Upgrades vs V48.1:
//   • Live signal counters per category (BLE devices, WiFi pts, fusion rate)
//   • Grid / List view toggle with AnimatedSwitcher
//   • Quick-action strip: 3D Vision, Scan, AI Brain, Stealth
//   • Staggered tile entrance animation (no Random)
//   • Version badge updated to V49.9
//   • Hardware footer section collapsible
// =============================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../widgets/falcon_side_panel.dart';
import '../services/hardware_capabilities_service.dart';
import '../services/stealth_service.dart';
import '../services/root_permission_service.dart';
import '../services/ble_service.dart';
import '../services/wifi_csi_service.dart';
import '../services/multi_signal_fusion_service.dart';
import '../services/features_provider.dart';

// ─── Page entry model ────────────────────────────────────────────────────────
class _PageEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final bool usePush;
  final bool requiresRoot;
  final Color accentColor;
  final bool isNew;

  const _PageEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.usePush = false,
    this.requiresRoot = false,
    this.accentColor = const Color(0xFF00FF66),
    this.isNew = false,
  });
}

class _Category {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<_PageEntry> pages;

  const _Category({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.pages,
  });
}

// =============================================================================
final _kCategories = [
  _Category(
    title: 'VISION & 3D',
    subtitle: 'Radio-Wave 3D Visualization Engine',
    icon: Icons.visibility,
    color: const Color(0xFF00FF41),
    pages: [
      _PageEntry(icon: Icons.code, title: 'Neo Matrix Vision',
          subtitle: 'OpenGL ES 2.0 — 6DoF free-move 3D HUD',
          route: '/neo_matrix', usePush: true, accentColor: const Color(0xFF00FF41)),
      _PageEntry(icon: Icons.gps_fixed, title: 'Tactical HUD',
          subtitle: 'Heads-up display + live signal overlay',
          route: '/hud', accentColor: const Color(0xFF00FF66)),
      _PageEntry(icon: Icons.radar, title: 'Real-Time 3D Radar',
          subtitle: 'Live BLE/WiFi/Cell point cloud — drag to orbit',
          route: '/real_radar', usePush: true, accentColor: const Color(0xFF00FF41), isNew: true),
      _PageEntry(icon: Icons.videocam, title: 'Drone / Camera Feed',
          subtitle: 'MJPEG/RTSP live stream with tactical HUD overlay',
          route: '/drone_camera', usePush: true, accentColor: const Color(0xFF00FF99), isNew: true),
      _PageEntry(icon: Icons.blur_on, title: 'Vision Configurator',
          subtitle: 'Switch modes, overlay settings, point size',
          route: '/vision_config', usePush: true, accentColor: const Color(0xFF00CCFF)),
    ],
  ),

  _Category(
    title: 'SIGNAL INTELLIGENCE',
    subtitle: 'SIGINT — Radio Ops — CSI Analysis',
    icon: Icons.wifi_tethering,
    color: const Color(0xFF00CCFF),
    pages: [
      _PageEntry(icon: Icons.wifi_tethering, title: 'Signal Intelligence',
          subtitle: 'WiFi CSI phase/amplitude + IQ analysis',
          route: '/sigint', usePush: true, accentColor: const Color(0xFF00CCFF)),
      _PageEntry(icon: Icons.graphic_eq, title: 'Spectral Analysis',
          subtitle: 'SDR waterfall + real-time spectrum monitor',
          route: '/spectral', usePush: true, accentColor: const Color(0xFF00CCFF)),
      _PageEntry(icon: Icons.hub, title: 'Environment Scan',
          subtitle: 'All signal sources grouped by type with stats',
          route: '/environment_scan', usePush: true, accentColor: const Color(0xFF00DDFF), isNew: true),
      _PageEntry(icon: Icons.show_chart, title: 'Signal Detail & RSSI History',
          subtitle: 'Per-source RSSI timeline + FL chart display',
          route: '/signal_detail', usePush: true, accentColor: const Color(0xFF00FFCC), isNew: true),
      _PageEntry(icon: Icons.terminal, title: 'Raw SIGINT Terminal',
          subtitle: 'Unfiltered hex byte-stream — modem + sensors',
          route: '/raw_sigint', usePush: true, accentColor: const Color(0xFFFF00FF)),
      _PageEntry(icon: Icons.receipt_long, title: 'Live Engine Log',
          subtitle: 'Real-time signal engine debug log stream',
          route: '/live_log', usePush: true, accentColor: const Color(0xFF66FF99), isNew: true),
      _PageEntry(icon: Icons.psychology, title: 'AI Signal Brain',
          subtitle: 'Claude AI tactical environment analysis',
          route: '/ai_signal_brain', usePush: true, accentColor: const Color(0xFFCC88FF), isNew: true),
      _PageEntry(icon: Icons.network_check, title: 'Packet Analyser',
          subtitle: 'UDP/TCP/DNS packet capture + protocol stats',
          route: '/packet_sniffer', usePush: true, accentColor: const Color(0xFF00DDFF), isNew: true),
      _PageEntry(icon: Icons.settings_input_antenna, title: 'UWB Precision Ranging',
          subtitle: 'Kalman-filtered sub-10cm ranging + radar',
          route: '/uwb_ranging', usePush: true, accentColor: const Color(0xFF44AAFF), isNew: true),
      _PageEntry(icon: Icons.waterfall_chart, title: 'Spectrogram Waterfall',
          subtitle: 'GPU-rendered scrolling FFT waterfall — 60fps',
          route: '/spectrogram_waterfall', usePush: true, accentColor: const Color(0xFF00E5FF), isNew: true),
      _PageEntry(icon: Icons.memory, title: 'AI Signal Memory',
          subtitle: 'Threat profile from past sessions — BLE MAC history',
          route: '/signal_memory', usePush: true, accentColor: const Color(0xFFCC88FF), isNew: true),
      _PageEntry(icon: Icons.account_tree, title: '3D Signal Topology',
          subtitle: 'Force-directed graph — signal nodes by strength',
          route: '/signal_topology', usePush: true, accentColor: const Color(0xFF00FFCC), isNew: true),
      _PageEntry(icon: Icons.location_searching, title: 'RSSI Triangulation',
          subtitle: 'Multi-path BLE/WiFi 2D position estimate',
          route: '/rssi_triangulation', usePush: true, accentColor: const Color(0xFF66FF99), isNew: true),
    ],
  ),

  _Category(
    title: 'CELLULAR INTERCEPT',
    subtitle: '5G / LTE / GSM Analysis',
    icon: Icons.cell_tower,
    color: const Color(0xFF4FC3F7),
    pages: [
      _PageEntry(icon: Icons.cell_tower, title: 'Cellular Interceptor Menu',
          subtitle: '5G/LTE mmWave heatmaps + tower analysis',
          route: '/interceptor_menu', usePush: true, accentColor: const Color(0xFF4FC3F7)),
      _PageEntry(icon: Icons.list_alt, title: 'Cell Tower List',
          subtitle: 'All detected base stations + signal strength',
          route: '/interceptor_list', usePush: true, accentColor: const Color(0xFF4FC3F7)),
      _PageEntry(icon: Icons.bluetooth, title: 'Bluetooth Intercept',
          subtitle: 'BLE device discovery + RSSI + manufacturer data',
          route: '/bluetooth', usePush: true, accentColor: const Color(0xFF7986CB)),
      _PageEntry(icon: Icons.cell_wifi, title: 'Cell Tower Spoof Detector',
          subtitle: 'IMSI-catcher detection — carrier database comparison',
          route: '/cell_spoof_detector', usePush: true, accentColor: const Color(0xFFFF6B6B), isNew: true),
      _PageEntry(icon: Icons.track_changes, title: 'Frequency Hop Detector',
          subtitle: 'BLE advertising channel rotation fingerprinting',
          route: '/freq_hop_detector', usePush: true, accentColor: const Color(0xFF4FC3F7), isNew: true),
      _PageEntry(icon: Icons.wifi_find, title: 'Passive WiFi Probe Sniffer',
          subtitle: 'Capture probe request frames — historical SSID map',
          route: '/wifi_probe_sniffer', usePush: true, accentColor: const Color(0xFF00CCFF), isNew: true),
    ],
  ),

  _Category(
    title: 'RF TOOLS',
    subtitle: 'Radio Frequency Operations',
    icon: Icons.settings_input_antenna,
    color: const Color(0xFFFFD700),
    pages: [
      _PageEntry(icon: Icons.vpn_key, title: 'Key Fob Analyzer',
          subtitle: 'RFID / keyless entry signal capture',
          route: '/key_fob', usePush: true, accentColor: const Color(0xFFFFD700)),
      _PageEntry(icon: Icons.lock_open, title: 'RF Lockpick Suite',
          subtitle: 'RF replay + frequency analysis tools',
          route: '/rf_lockpick', usePush: true, accentColor: const Color(0xFFFFB347), requiresRoot: true),
      _PageEntry(icon: Icons.dashboard, title: 'Falcon Command Center',
          subtitle: 'Mission control — all sensors fused',
          route: '/command_center', usePush: true, accentColor: const Color(0xFFFFD700)),
      _PageEntry(icon: Icons.nfc, title: 'NFC Tag Scanner',
          subtitle: 'UID hex + NDEF decode + entropy score',
          route: '/nfc_scanner', usePush: true, accentColor: const Color(0xFF00FF99), isNew: true),
      _PageEntry(icon: Icons.fingerprint, title: 'RF Fingerprinting',
          subtitle: 'Hardware imperfection fingerprint — re-ID after MAC randomisation',
          route: '/rf_fingerprint', usePush: true, accentColor: const Color(0xFFFFD700), isNew: true),
      _PageEntry(icon: Icons.settings_input_antenna, title: 'RTL-SDR Bridge',
          subtitle: 'USB-OTG IQ stream → FFT · FM · ADS-B · AIS',
          route: '/rtl_sdr', usePush: true, accentColor: const Color(0xFF00FF41), isNew: true),
      _PageEntry(icon: Icons.router, title: 'HackRF / PortaPack Bridge',
          subtitle: 'RX sweep + capture replay — 1 MHz–6 GHz',
          route: '/hackrf', usePush: true, accentColor: const Color(0xFFFF6600), requiresRoot: true, isNew: true),
    ],
  ),

  _Category(
    title: 'GEOPHYSICAL',
    subtitle: 'Subsurface and Element Detection',
    icon: Icons.layers,
    color: const Color(0xFFB87333),
    pages: [
      _PageEntry(icon: Icons.layers, title: 'Geophysical / Metals Scan',
          subtitle: '118-element detection — magnetometer + voxel 3D',
          route: '/geophysical', accentColor: const Color(0xFFFFD700)),
    ],
  ),

  _Category(
    title: 'PLANET HEALTH',
    subtitle: 'Bio-Signal Tomography Suite',
    icon: Icons.monitor_heart,
    color: const Color(0xFFFF6B9D),
    pages: [
      _PageEntry(icon: Icons.monitor_heart, title: 'Planet Health 3.0',
          subtitle: 'FFT bio-tomography — CSI respiration + heart rate',
          route: '/health', accentColor: const Color(0xFFFF6B9D)),
      _PageEntry(icon: Icons.biotech, title: 'X-Ray Bone Scanner',
          subtitle: 'IMU + magnetometer bone density model',
          route: '/xray_scanner', usePush: true, accentColor: const Color(0xFF00E5FF), isNew: true),
      _PageEntry(icon: Icons.favorite, title: 'ECG Heart Monitor',
          subtitle: 'Pan-Tompkins ballistocardiography + HRV',
          route: '/ecg_monitor', usePush: true, accentColor: const Color(0xFFFF3355), isNew: true),
      _PageEntry(icon: Icons.accessibility_new, title: 'Full Body Scanner',
          subtitle: '9-zone multi-sensor fusion health analysis',
          route: '/full_body_scanner', usePush: true, accentColor: const Color(0xFF00FFFF), isNew: true),
    ],
  ),

  _Category(
    title: 'DATA & SECURITY',
    subtitle: 'Vault, Recordings and Stealth Ops',
    icon: Icons.security,
    color: const Color(0xFFCE93D8),
    pages: [
      _PageEntry(icon: Icons.storage, title: 'Data Vault',
          subtitle: 'Encrypted recordings + session replay',
          route: '/data_vault', usePush: true, accentColor: const Color(0xFFCE93D8)),
      _PageEntry(icon: Icons.visibility_off, title: 'Stealth Protocol',
          subtitle: 'Zero-trace signal masking toggle',
          route: '__stealth__', accentColor: const Color(0xFFCE93D8)),
      _PageEntry(icon: Icons.cloud_upload, title: 'Sovereign Uplink Monitor',
          subtitle: 'Encrypted uplink queue + bandwidth graph',
          route: '/uplink_monitor', usePush: true, accentColor: const Color(0xFFCE93D8), isNew: true),
      _PageEntry(icon: Icons.lock, title: 'Zero-Knowledge Vault',
          subtitle: 'Biometric + hardware key encryption',
          route: '/zero_knowledge_vault', usePush: true, accentColor: const Color(0xFFFFD700), isNew: true),
      _PageEntry(icon: Icons.schedule, title: 'Covert Mode Scheduler',
          subtitle: 'Auto-stealth on geofence / time-of-day',
          route: '/covert_scheduler', usePush: true, accentColor: const Color(0xFFCE93D8), isNew: true),
      _PageEntry(icon: Icons.replay_circle_filled, title: 'Session Replay 3D',
          subtitle: 'Animated 3D timeline — scrub through signal sessions',
          route: '/session_replay_3d', usePush: true, accentColor: const Color(0xFF66FFFF), isNew: true),
      _PageEntry(icon: Icons.map, title: 'Signal Heatmap Export',
          subtitle: 'Room-scale RSSI heatmap — export PNG',
          route: '/heatmap_export', usePush: true, accentColor: const Color(0xFFFF9800), isNew: true),
      _PageEntry(icon: Icons.compare, title: 'Comparative Baseline',
          subtitle: 'Snapshot clean environment — alert on anomalies',
          route: '/signal_baseline', usePush: true, accentColor: const Color(0xFF00E5FF), isNew: true),
    ],
  ),

  _Category(
    title: 'SYSTEM',
    subtitle: 'Hardware, Boot and Subscription',
    icon: Icons.settings,
    color: const Color(0xFF81C784),
    pages: [
      _PageEntry(icon: Icons.settings, title: 'Settings & Hardware',
          subtitle: 'Device tiers, gyro calibration, background mode',
          route: '/settings', accentColor: const Color(0xFF81C784)),
      _PageEntry(icon: Icons.power_settings_new, title: 'Sovereign Boot',
          subtitle: 'Boot sequence log + system init status',
          route: '/boot', usePush: true, accentColor: const Color(0xFF81C784)),
      _PageEntry(icon: Icons.diamond, title: 'Premium Subscription',
          subtitle: 'Crypto payments + access code redemption',
          route: '/subscription', usePush: true, accentColor: const Color(0xFFFFD700)),
    ],
  ),

  _Category(
    title: 'SOVEREIGN ADMIN',
    subtitle: 'Classified — Secret Code Required',
    icon: Icons.admin_panel_settings,
    color: const Color(0xFFFF4444),
    pages: [
      _PageEntry(icon: Icons.admin_panel_settings, title: 'Admin Control Panel',
          subtitle: 'Wallet config — code generator — lifetime licence',
          route: '/admin_settings', usePush: true, accentColor: const Color(0xFFFF4444)),
    ],
  ),
];

// ── Quick-action entries ──────────────────────────────────────────────────────
class _QuickAction {
  final IconData icon;
  final String label;
  final String route;
  final bool usePush;
  final Color color;
  const _QuickAction(this.icon, this.label, this.route, this.color, {this.usePush = false});
}

const _kQuickActions = [
  _QuickAction(Icons.code,         '3D VISION',  '/neo_matrix',      Color(0xFF00FF41), usePush: true),
  _QuickAction(Icons.wifi_tethering, 'SIGINT',   '/sigint',          Color(0xFF00CCFF), usePush: true),
  _QuickAction(Icons.psychology,   'AI BRAIN',   '/ai_signal_brain', Color(0xFFCC88FF), usePush: true),
  _QuickAction(Icons.radar,        'RADAR',      '/real_radar',      Color(0xFF00FF99), usePush: true),
  _QuickAction(Icons.visibility_off,'STEALTH',   '__stealth__',      Color(0xFFCE93D8)),
  _QuickAction(Icons.settings,     'SETTINGS',   '/settings',        Color(0xFF81C784)),
];

// =============================================================================
class MasterControlIndexPage extends ConsumerStatefulWidget {
  const MasterControlIndexPage({super.key});
  @override
  ConsumerState<MasterControlIndexPage> createState() => _MasterControlIndexPageState();
}

class _MasterControlIndexPageState extends ConsumerState<MasterControlIndexPage>
    with SingleTickerProviderStateMixin {

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  late AnimationController _pulseCtrl;
  Timer? _uptimeTimer;
  int _uptimeSeconds = 0;
  bool _gridMode = false;          // NEW: grid/list toggle
  bool _hwExpanded = false;        // NEW: hardware footer collapsible

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _uptimeSeconds++);
    });
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(hardwareCapabilitiesProvider.notifier).scanHardware();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _uptimeTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _navigate(_PageEntry entry) {
    if (entry.route == '__stealth__') {
      ref.read(stealthProtocolProvider.notifier).toggle();
      final active = ref.read(stealthProtocolProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(active
            ? 'STEALTH PROTOCOL ACTIVE — Zero-trace mode enabled'
            : 'Stealth Protocol deactivated'),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (entry.requiresRoot) {
      final rootState = ref.read(rootPermissionProvider);
      if (!rootState.isRooted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Requires root access — restart and grant root'),
          backgroundColor: Color(0xFF660000),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
    }
    if (entry.usePush) {
      context.push(entry.route);
    } else {
      context.go(entry.route);
    }
  }

  List<({_PageEntry entry, _Category cat})> _allEntries() => [
    for (final cat in _kCategories)
      for (final entry in cat.pages)
        (entry: entry, cat: cat),
  ];

  List<({_PageEntry entry, _Category cat})> _filtered() {
    if (_query.isEmpty) return [];
    return _allEntries().where((e) =>
      e.entry.title.toLowerCase().contains(_query) ||
      e.entry.subtitle.toLowerCase().contains(_query) ||
      e.cat.title.toLowerCase().contains(_query)
    ).toList();
  }

  int get _totalPages => _kCategories.fold(0, (s, c) => s + c.pages.length);

  String _formatUptime() {
    final h = (_uptimeSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((_uptimeSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_uptimeSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final caps     = ref.watch(hardwareCapabilitiesProvider);
    final rootState= ref.watch(rootPermissionProvider);
    final stealth  = ref.watch(stealthProtocolProvider);
    final color    = ref.watch(featuresProvider).primaryColor;
    final filtered = _filtered();

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Column(children: [
          _buildHeader(caps, rootState, stealth, color),
          _buildQuickActions(stealth, color),
          _buildSearchBar(color),
          Expanded(
            child: _query.isNotEmpty
                ? _buildSearchResults(filtered, color)
                : _buildCategoryList(caps, rootState, stealth, color),
          ),
        ]),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader(HardwareCapabilities caps, RootPermissionState root,
      bool stealth, Color color) {
    final ble     = ref.watch(bleServiceProvider);
    final wifi    = ref.watch(wifiCSIProvider);
    final fusion  = ref.watch(multiSignalFusionProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.12), width: 1)),
      ),
      child: Column(children: [
        Row(children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
                border: Border.all(
                  color: color.withValues(alpha: 0.4 + 0.6 * _pulseCtrl.value),
                  width: 1.5,
                ),
                boxShadow: [BoxShadow(
                  color: color.withValues(alpha: 0.3 * _pulseCtrl.value),
                  blurRadius: 12,
                )],
              ),
              child: Icon(Icons.visibility, color: color, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('FALCON EYE V49.9',
                style: TextStyle(color: color, fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.bold)),
            const Text('MASTER CONTROL INDEX',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ])),
          // Grid/List toggle
          IconButton(
            onPressed: () => setState(() => _gridMode = !_gridMode),
            icon: Icon(_gridMode ? Icons.view_list : Icons.grid_view,
                color: color.withValues(alpha: 0.7), size: 20),
            tooltip: _gridMode ? 'List view' : 'Grid view',
          ),
          _StatusBadge(
            label: root.isRooted ? '⚡ ROOT' : '⚠ LIMITED',
            color: root.isRooted ? const Color(0xFF00FF41) : const Color(0xFFFFAA00),
          ),
        ]),
        const SizedBox(height: 10),
        // Stat chips row — top: page count, uptime, stealth, 5G, cats
        Row(children: [
          _StatChip('PAGES',  '$_totalPages',      color),
          const SizedBox(width: 5),
          _StatChip('UPTIME', _formatUptime(),      const Color(0xFF00CCFF)),
          const SizedBox(width: 5),
          _StatChip('STEALTH', stealth ? 'ON' : 'OFF',
              stealth ? const Color(0xFFCE93D8) : const Color(0xFF2E5A42)),
          const SizedBox(width: 5),
          _StatChip('5G', caps.cellular5G.enabled ? 'ON' : 'OFF',
              caps.cellular5G.enabled ? const Color(0xFF4FC3F7) : const Color(0xFF2E5A42)),
          const SizedBox(width: 5),
          _StatChip('CATS', '${_kCategories.length}', const Color(0xFFFFD700)),
        ]),
        const SizedBox(height: 6),
        // Live signal counters row
        Row(children: [
          _StatChip('BLE',    '${ble.devices.length} dev',
              const Color(0xFF7986CB)),
          const SizedBox(width: 5),
          _StatChip('WIFI',   '${wifi.rawData.length} pts',
              const Color(0xFF00CCFF)),
          const SizedBox(width: 5),
          _StatChip('FUSION', fusion.isActive ? '${fusion.fusionRate}Hz' : 'OFF',
              fusion.isActive ? const Color(0xFF00FF41) : const Color(0xFF2E5A42)),
          const SizedBox(width: 5),
          _StatChip('GPU',    caps.tier1Flagship.enabled ? 'T1' : 'T3',
              caps.tier1Flagship.enabled ? const Color(0xFF00FF41) : const Color(0xFF2E5A42)),
          const SizedBox(width: 5),
          Flexible(
            child: _StatChip('SCAN',
                ble.scanning ? 'ACTIVE' : 'IDLE',
                ble.scanning ? const Color(0xFF00FF41) : const Color(0xFF2E5A42)),
          ),
        ]),
        const SizedBox(height: 10),
      ]),
    );
  }

  // ── Quick-action strip ────────────────────────────────────────────────────
  Widget _buildQuickActions(bool stealth, Color themeColor) {
    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _kQuickActions.length,
        itemBuilder: (ctx, i) {
          final qa = _kQuickActions[i];
          final isStealthAction = qa.route == '__stealth__';
          final c = isStealthAction && stealth ? const Color(0xFFCE93D8) : qa.color;
          return GestureDetector(
            onTap: () {
              if (isStealthAction) {
                ref.read(stealthProtocolProvider.notifier).toggle();
                return;
              }
              if (qa.usePush) context.push(qa.route);
              else context.go(qa.route);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: c.withValues(alpha: isStealthAction && stealth ? 0.18 : 0.08),
                border: Border.all(color: c.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(6),
                boxShadow: isStealthAction && stealth
                    ? [BoxShadow(color: c.withValues(alpha: 0.3), blurRadius: 8)]
                    : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(qa.icon, color: c, size: 14),
                const SizedBox(width: 6),
                Text(qa.label,
                    style: TextStyle(
                      color: c, fontSize: 10,
                      fontWeight: FontWeight.bold, letterSpacing: 1,
                    )),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────
  Widget _buildSearchBar(Color color) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A0A),
        border: Border.all(
          color: _query.isNotEmpty ? color : color.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'SEARCH ALL $_totalPages PAGES & SERVICES...',
          hintStyle: TextStyle(color: color.withValues(alpha: 0.25), fontSize: 12, letterSpacing: 1),
          prefixIcon: Icon(Icons.search, color: color, size: 20),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: color.withValues(alpha: 0.5), size: 18),
                  onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // ── Search results ────────────────────────────────────────────────────────
  Widget _buildSearchResults(List<({_PageEntry entry, _Category cat})> results, Color color) {
    if (results.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.search_off, color: color.withValues(alpha: 0.25), size: 48),
        const SizedBox(height: 12),
        Text('No pages match "$_query"',
            style: TextStyle(color: color.withValues(alpha: 0.4), fontSize: 14)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: results.length,
      itemBuilder: (ctx, i) {
        final r = results[i];
        return _PageTile(
          entry: r.entry,
          catColor: r.cat.color,
          onTap: () => _navigate(r.entry),
        );
      },
    );
  }

  // ── Category list ─────────────────────────────────────────────────────────
  Widget _buildCategoryList(HardwareCapabilities caps, RootPermissionState root,
      bool stealth, Color color) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        for (final cat in _kCategories) ...[
          _buildCategoryHeader(cat),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _gridMode
                ? _buildCategoryGrid(cat, stealth)
                : _buildCategoryRows(cat, stealth),
          ),
          const SizedBox(height: 16),
        ],
        _buildHardwareFooter(caps, root, color),
      ],
    );
  }

  Widget _buildCategoryRows(_Category cat, bool stealth) {
    return Column(
      key: ValueKey('rows_${cat.title}'),
      children: cat.pages.asMap().entries.map((e) {
        return _AnimatedTile(
          index: e.key,
          child: _PageTile(
            entry: e.value,
            catColor: cat.color,
            onTap: () => _navigate(e.value),
            extraBadge: e.value.route == '__stealth__' ? (stealth ? 'ACTIVE' : 'OFF') : null,
            extraBadgeColor: stealth ? const Color(0xFFCE93D8) : const Color(0xFF2E5A42),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryGrid(_Category cat, bool stealth) {
    return GridView.builder(
      key: ValueKey('grid_${cat.title}'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1.5,
      ),
      itemCount: cat.pages.length,
      itemBuilder: (ctx, i) {
        final entry = cat.pages[i];
        return _AnimatedTile(
          index: i,
          child: _GridTile(
            entry: entry,
            onTap: () => _navigate(entry),
          ),
        );
      },
    );
  }

  Widget _buildCategoryHeader(_Category cat) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Container(
          width: 3, height: 28,
          decoration: BoxDecoration(
            color: cat.color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(color: cat.color.withValues(alpha: 0.5), blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 10),
        Icon(cat.icon, color: cat.color, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cat.title,
              style: TextStyle(color: cat.color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
          Text(cat.subtitle,
              style: TextStyle(color: cat.color.withValues(alpha: 0.35), fontSize: 9)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: cat.color.withValues(alpha: 0.08),
            border: Border.all(color: cat.color.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text('${cat.pages.length}',
              style: TextStyle(color: cat.color.withValues(alpha: 0.7),
                  fontSize: 9, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  // ── Hardware footer (collapsible) ─────────────────────────────────────────
  Widget _buildHardwareFooter(HardwareCapabilities caps, RootPermissionState root, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF050F05),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(children: [
        // Collapse toggle header
        InkWell(
          onTap: () => setState(() => _hwExpanded = !_hwExpanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(Icons.memory, color: color, size: 14),
              const SizedBox(width: 8),
              Expanded(child: Text('HARDWARE STATUS',
                  style: TextStyle(color: color, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(caps.deviceModel,
                    style: TextStyle(color: color.withValues(alpha: 0.4), fontSize: 9)),
              ),
              const SizedBox(width: 8),
              Icon(_hwExpanded ? Icons.expand_less : Icons.expand_more,
                  color: color.withValues(alpha: 0.5), size: 18),
            ]),
          ),
        ),
        if (_hwExpanded) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: Text(
              'Android ${caps.androidVersion} (SDK ${caps.sdkInt}) · ${caps.chipset} · ${caps.cpuAbi}',
              style: TextStyle(color: color.withValues(alpha: 0.3), fontSize: 9),
            ),
          ),
          for (final section in caps.sections) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
              child: Row(children: [
                Container(width: 2, height: 10,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(1))),
                const SizedBox(width: 6),
                Text(section.section,
                    style: TextStyle(color: const Color(0xFF4CAF50), fontSize: 9, letterSpacing: 2)),
              ]),
            ),
            for (final item in section.items)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
                child: _HwRow(item.$1, item.$2.enabled, item.$2.reason),
              ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => ref.read(hardwareCapabilitiesProvider.notifier).scanHardware(),
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('RE-SCAN ALL HARDWARE',
                    style: TextStyle(letterSpacing: 1, fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// =============================================================================
// SHARED WIDGETS
// =============================================================================

/// Staggered entrance animation — index drives delay, zero Random().
class _AnimatedTile extends StatefulWidget {
  final int index;
  final Widget child;
  const _AnimatedTile({required this.index, required this.child});
  @override
  State<_AnimatedTile> createState() => _AnimatedTileState();
}
class _AnimatedTileState extends State<_AnimatedTile> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    // Stagger by index — deterministic, no Random
    Future.delayed(Duration(milliseconds: 30 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

class _PageTile extends StatelessWidget {
  final _PageEntry entry;
  final Color catColor;
  final VoidCallback onTap;
  final String? extraBadge;
  final Color? extraBadgeColor;

  const _PageTile({
    required this.entry,
    required this.catColor,
    required this.onTap,
    this.extraBadge,
    this.extraBadgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = entry.accentColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          border: Border.all(color: color.withValues(alpha: entry.isNew ? 0.35 : 0.18)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(entry.icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.title,
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(entry.subtitle,
                style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 10),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          if (entry.isNew) _badge('NEW', const Color(0xFF00FF41)),
          if (entry.requiresRoot) ...[const SizedBox(width: 4), _badge('ROOT', const Color(0xFFFFAA00))],
          if (extraBadge != null) ...[const SizedBox(width: 4), _badge(extraBadge!, extraBadgeColor ?? color)],
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, color: color.withValues(alpha: 0.5), size: 16),
        ]),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      border: Border.all(color: color.withValues(alpha: 0.5)),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
  );
}

class _GridTile extends StatelessWidget {
  final _PageEntry entry;
  final VoidCallback onTap;
  const _GridTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = entry.accentColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          border: Border.all(color: color.withValues(alpha: entry.isNew ? 0.4 : 0.2)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(entry.icon, color: color, size: 16),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(entry.title,
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center, maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          if (entry.isNew) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF41).withValues(alpha: 0.15),
                border: Border.all(color: const Color(0xFF00FF41).withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Text('NEW', style: TextStyle(color: Color(0xFF00FF41), fontSize: 7,
                  fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.6),
              fontSize: 7, letterSpacing: 1)),
          Text(value, style: TextStyle(color: color, fontSize: 9,
              fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
    );
  }
}

class _HwRow extends StatelessWidget {
  final String label;
  final bool active;
  final String reason;
  const _HwRow(this.label, this.active, this.reason);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(active ? Icons.check_circle : Icons.cancel,
            size: 12,
            color: active ? const Color(0xFF00FF41) : const Color(0xFF2E5A42)),
        const SizedBox(width: 8),
        Expanded(child: Text(label,
            style: TextStyle(color: active ? Colors.white70 : const Color(0xFF2E5A42), fontSize: 11))),
        Text(reason,
            style: TextStyle(
                color: active ? const Color(0xFF00FF41) : const Color(0xFF2E5A42), fontSize: 10)),
      ]),
    );
  }
}
