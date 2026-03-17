import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'main.dart';
import 'pages/tactical_hud_page.dart';
import 'pages/geophysical_scan_page.dart';
import 'pages/planet_health_page.dart';
import 'pages/settings_hardware_page.dart';
import 'pages/signal_intelligence_page.dart';
import 'pages/spectral_analysis_page.dart';
import 'pages/vision_configurator_page.dart';
import 'pages/data_vault_page.dart';
import 'pages/falcon_command_center_page.dart';
import 'pages/key_fob_analyzer_page.dart';
import 'pages/rf_lockpick_page.dart';
import 'pages/cellular_interceptor_menu_page.dart';
import 'pages/cellular_interception_list_page.dart';
import 'pages/master_control_page.dart';
import 'pages/bluetooth_intercept_page.dart';
import 'pages/sovereign_boot_page.dart';
import 'pages/neo_matrix_vision_page.dart';
import 'pages/raw_sigint_page.dart';
import 'pages/subscription_page.dart';
import 'pages/admin_settings_page.dart';
import 'pages/xray_scanner_page.dart';
import 'pages/ecg_monitor_page.dart';
import 'pages/full_body_scanner_page.dart';
import 'pages/environment_scan_page.dart';
import 'pages/live_log_page.dart';
import 'pages/real_radar_page.dart';
import 'pages/signal_detail_page.dart';
import 'pages/uwb_ranging_page.dart';
import 'pages/ai_signal_brain_page.dart';
import 'pages/packet_sniffer_page.dart';
import 'pages/drone_camera_page.dart';
import 'pages/nfc_scanner_page.dart';
import 'pages/uplink_monitor_page.dart';
import 'pages/spectrogram_waterfall_page.dart';
import 'pages/cell_spoof_detector_page.dart';
import 'pages/signal_memory_page.dart';
import 'pages/rssi_triangulation_page.dart';
import 'pages/freq_hop_detector_page.dart';
import 'pages/wifi_probe_sniffer_page.dart';
import 'pages/signal_topology_page.dart';
import 'pages/rf_fingerprint_page.dart';
import 'pages/zero_knowledge_vault_page.dart';
import 'pages/covert_scheduler_page.dart';
import 'pages/session_replay_3d_page.dart';
import 'pages/heatmap_export_page.dart';
import 'pages/signal_baseline_page.dart';
import 'pages/rtl_sdr_page.dart';
import 'pages/hackrf_page.dart';
import 'models/vision_mode.dart';
import 'theme.dart';
import 'services/features_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const CinematicSplashScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/neo_matrix',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          // Parse mode name from extra
          VisionMode initialMode = VisionMode.neoMatrix;
          if (extra?['mode'] != null) {
            final modeName = extra!['mode'] as String;
            initialMode = VisionMode.values.firstWhere(
              (m) => m.name == modeName,
              orElse: () => VisionMode.neoMatrix,
            );
          }
          return NeoMatrixVisionPage(
            hasRootAccess: extra?['hasRoot'] as bool? ?? false,
            initialMode: initialMode,
          );
        },
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return ScaffoldWithNavBar(child: child);
        },
        routes: [
          GoRoute(
            path: '/hud',
            builder: (context, state) => const TacticalHUDPage(),
          ),
          GoRoute(
            path: '/geophysical',
            builder: (context, state) => const GeophysicalScanPage(),
          ),
          GoRoute(
            path: '/health',
            builder: (context, state) => const PlanetHealthPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsHardwarePage(),
          ),
          GoRoute(
            path: '/master_control',
            builder: (context, state) => const MasterControlIndexPage(),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/sigint',
        builder: (context, state) => const SignalIntelligencePage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/spectral',
        builder: (context, state) => const SpectralAnalysisPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/vision_config',
        builder: (context, state) => const VisionConfiguratorPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/data_vault',
        builder: (context, state) => const DataVaultPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/command_center',
        builder: (context, state) => const FalconCommandCenterPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/key_fob',
        builder: (context, state) => const KeyFobAnalyzerPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/rf_lockpick',
        builder: (context, state) => const RFLockpickPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/interceptor_menu',
        builder: (context, state) => const CellularInterceptorMenuPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/interceptor_list',
        builder: (context, state) => const CellularInterceptionListPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/bluetooth',
        builder: (context, state) => const BluetoothInterceptPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/boot',
        builder: (context, state) => const SovereignBootPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/raw_sigint',
        builder: (context, state) => const RawSigintPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/subscription',
        builder: (context, state) => const SubscriptionPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/admin_settings',
        builder: (context, state) => const AdminSettingsPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/xray_scanner',
        builder: (context, state) => const XRayScannerPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/ecg_monitor',
        builder: (context, state) => const EcgMonitorPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/full_body_scanner',
        builder: (context, state) => const FullBodyScannerPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/environment_scan',
        builder: (context, state) => const EnvironmentScanPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/live_log',
        builder: (context, state) => const LiveLogPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/real_radar',
        builder: (context, state) => const RealRadarPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/signal_detail',
        builder: (context, state) => const SignalDetailPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/uwb_ranging',
        builder: (context, state) => const UwbRangingPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/ai_signal_brain',
        builder: (context, state) => const AiSignalBrainPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/packet_sniffer',
        builder: (context, state) => const PacketSnifferPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/drone_camera',
        builder: (context, state) => const DroneCameraPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/nfc_scanner',
        builder: (context, state) => const NfcScannerPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/uplink_monitor',
        builder: (context, state) => const UplinkMonitorPage(),
      ),
      // ── V48.1 ROUTES ──────────────────────────────────────────────────
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/spectrogram_waterfall',
        builder: (context, state) => const SpectrogramWaterfallPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/cell_spoof_detector',
        builder: (context, state) => const CellSpoofDetectorPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/signal_memory',
        builder: (context, state) => const SignalMemoryPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/rssi_triangulation',
        builder: (context, state) => const RssiTriangulationPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/freq_hop_detector',
        builder: (context, state) => const FreqHopDetectorPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/wifi_probe_sniffer',
        builder: (context, state) => const WifiProbeSnifferPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/signal_topology',
        builder: (context, state) => const SignalTopologyPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/rf_fingerprint',
        builder: (context, state) => const RfFingerprintPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/zero_knowledge_vault',
        builder: (context, state) => const ZeroKnowledgeVaultPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/covert_scheduler',
        builder: (context, state) => const CovertSchedulerPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/session_replay_3d',
        builder: (context, state) => const SessionReplay3DPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/heatmap_export',
        builder: (context, state) => const HeatmapExportPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/signal_baseline',
        builder: (context, state) => const SignalBaselinePage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/rtl_sdr',
        builder: (context, state) => const RtlSdrPage(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/hackrf',
        builder: (context, state) => const HackRfPage(),
      ),
    ],
  );
}

/// V47 Sovereign: Glassmorphic navigation shell with frosted bottom bar
class ScaffoldWithNavBar extends ConsumerWidget {
  final Widget child;
  const ScaffoldWithNavBar({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String location = GoRouterState.of(context).uri.path;
    int currentIndex = 0;
    if (location.startsWith('/hud')) currentIndex = 0;
    else if (location.startsWith('/geophysical')) currentIndex = 1;
    else if (location.startsWith('/health')) currentIndex = 2;
    else if (location.startsWith('/settings')) currentIndex = 3;
    else if (location.startsWith('/master_control')) currentIndex = 4;

    final features = ref.watch(featuresProvider);
    final color = features.primaryColor;

    return Scaffold(
      body: child,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.black.withValues(alpha: 0.2),
                ],
              ),
              border: Border(
                top: BorderSide(color: color.withValues(alpha: 0.2), width: 0.5),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (index) {
                switch (index) {
                  case 0: context.go('/hud'); break;
                  case 1: context.go('/geophysical'); break;
                  case 2: context.go('/health'); break;
                  case 3: context.go('/settings'); break;
                  case 4: context.go('/master_control'); break;
                }
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.gps_fixed), label: 'HUD'),
                BottomNavigationBarItem(icon: Icon(Icons.layers), label: 'METALS'),
                BottomNavigationBarItem(icon: Icon(Icons.monitor_heart), label: 'HEALTH'),
                BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'CONFIG'),
                BottomNavigationBarItem(icon: Icon(Icons.apps), label: 'ALL'),
              ],
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: color,
              unselectedItemColor: color.withValues(alpha: 0.25),
              type: BottomNavigationBarType.fixed,
              showUnselectedLabels: true,
              selectedLabelStyle: const TextStyle(fontSize: 9, letterSpacing: 0.5, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 9),
            ),
          ),
        ),
      ),
    );
  }
}
