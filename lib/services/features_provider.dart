import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  FALCON EYE V42 — UNIFIED FEATURES & THEME PROVIDER
//  One single theme choice controls the entire app's colors across all pages
//  10 new toggleable features added for V42
// ═══════════════════════════════════════════════════════════════════════════════

enum FalconTheme {
  neoGreen(label: 'Neo Green', primary: Color(0xFF00FF41), secondary: Color(0xFF00CC33), background: Color(0xFF000000), surface: Color(0xFF030F05), accent: Color(0xFF00FF80), icon: Icons.terminal, linkedModeName: 'neoMatrix'),
  darkKnightBlue(label: 'Dark Knight Blue', primary: Color(0xFF0099FF), secondary: Color(0xFF0066CC), background: Color(0xFF000814), surface: Color(0xFF020C1A), accent: Color(0xFF33BBFF), icon: Icons.nightlight, linkedModeName: 'darkKnight'),
  lucyPsychedelic(label: 'Lucy Psychedelic', primary: Color(0xFFFF00FF), secondary: Color(0xFF9900FF), background: Color(0xFF0A000F), surface: Color(0xFF12000F), accent: Color(0xFFFF66FF), icon: Icons.auto_awesome, linkedModeName: 'lucy'),
  ironManRed(label: 'Iron Man Red', primary: Color(0xFFFF3333), secondary: Color(0xFFFF9900), background: Color(0xFF0F0000), surface: Color(0xFF150000), accent: Color(0xFFFF6666), icon: Icons.gps_fixed, linkedModeName: 'ironMan'),
  daredevilCyan(label: 'Daredevil Cyan', primary: Color(0xFF00CCFF), secondary: Color(0xFF0099CC), background: Color(0xFF00080F), surface: Color(0xFF000D1A), accent: Color(0xFF66DDFF), icon: Icons.blur_on, linkedModeName: 'daredevil'),
  goldVein(label: 'Gold Vein', primary: Color(0xFFFFD700), secondary: Color(0xFFB8860B), background: Color(0xFF0A0800), surface: Color(0xFF120F00), accent: Color(0xFFFFE44D), icon: Icons.layers, linkedModeName: 'subsurfaceVein'),
  bioRed(label: 'Bio Pulse', primary: Color(0xFFFF0066), secondary: Color(0xFFFF3399), background: Color(0xFF0F0008), surface: Color(0xFF150010), accent: Color(0xFFFF4488), icon: Icons.favorite, linkedModeName: 'bioTransparency'),
  fusionCyan(label: 'Fusion Tactical', primary: Color(0xFF00FFFF), secondary: Color(0xFF00AAAA), background: Color(0xFF000D0D), surface: Color(0xFF001414), accent: Color(0xFF66FFFF), icon: Icons.dashboard, linkedModeName: 'fusionTactical'),
  militaryOlive(label: 'Military Olive', primary: Color(0xFF8FAD15), secondary: Color(0xFF6B8000), background: Color(0xFF080A00), surface: Color(0xFF0F1200), accent: Color(0xFFB0D033), icon: Icons.shield, linkedModeName: 'matrix'),
  eagleVision(label: 'Eagle Vision', primary: Color(0xFFE8F0FF), secondary: Color(0xFF9BB8FF), background: Color(0xFF03030D), surface: Color(0xFF06061A), accent: Color(0xFFFFFFFF), icon: Icons.remove_red_eye, linkedModeName: 'eagleVision');

  const FalconTheme({required this.label, required this.primary, required this.secondary, required this.background, required this.surface, required this.accent, required this.icon, required this.linkedModeName});
  final String label;
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color accent;
  final IconData icon;
  /// Name of the paired VisionMode (string to avoid circular import).
  final String linkedModeName;
}

// ─── Feature Keys ────────────────────────────────────────────────────────────
class FKey {
  // 3D Vision
  static const gyroMotion         = 'gyro_motion';
  static const pinchZoom          = 'pinch_zoom';
  static const signalHeatmap      = 'signal_heatmap';
  static const floorGrid          = 'floor_grid';
  static const wireframeBuildings = 'wireframe_buildings';
  static const backgroundFigures  = 'bg_figures';
  static const bioHologram        = 'bio_hologram';
  static const scanlines          = 'scanlines';
  static const glitchEffects      = 'glitch_effects';
  static const codeRain           = 'code_rain';
  static const codeRainChars      = 'code_rain_chars';
  static const particleHuman      = 'particle_human';
  static const neuralTendrils     = 'neural_tendrils';
  static const droneTopDown       = 'drone_top_down';

  // Signals & Analysis
  static const wifiCSI            = 'wifi_csi';
  static const bluetoothScan      = 'bt_scan';
  static const cellularMonitor    = 'cellular_monitor';
  static const magnetometer       = 'magnetometer';
  static const directionFinding   = 'direction_finding';
  static const jammerDetection    = 'jammer_detection';
  static const waterVoidDetection = 'water_void';
  static const aiSignalSummary    = 'ai_summary';

  // Recording & Security
  static const recording          = 'recording';
  static const backgroundRecord   = 'bg_record';
  static const invisibleCamera    = 'invisible_camera';
  static const replaySystem       = 'replay_system';

  // Communication & Privacy
  static const stealthMode        = 'stealth_mode';
  static const voiceCommands      = 'voice_commands';
  static const multiDeviceMesh    = 'multi_device_mesh';
  static const communityMap       = 'community_map';

  // UI & UX
  static const hudOverlay         = 'hud_overlay';
  static const customizableHUD    = 'customizable_hud';
  static const statsPanel         = 'stats_panel';
  static const waveformOverlay    = 'waveform_overlay';
  static const homeWidget         = 'home_widget';
  static const export3D           = 'export_3d';

  // ── V42: 10 NEW FEATURES ──────────────────────────────────────────────
  static const rssiHeatmapOverlay   = 'rssi_heatmap_overlay';
  static const anomalyAlert         = 'anomaly_alert';
  static const signalPlaybackSim    = 'signal_playback_sim';
  static const batteryOptScan       = 'battery_opt_scan';
  static const multiSignalCalib     = 'multi_signal_calib';
  static const objectLabeling       = 'object_labeling';
  static const exportExternal       = 'export_external';
  static const voiceActivatedScan   = 'voice_activated_scan';
  static const jammerCountermeasure = 'jammer_countermeasure';
  static const customPointRendering = 'custom_point_rendering';

  // ── V47.7: NEW ENGINE FEATURES ──────────────────────────────────────
  static const quantumEngine       = 'quantum_engine';
  static const bioTomography       = 'bio_tomography';
  static const metallurgicRadar    = 'metallurgic_radar';
  static const freeMoveMode        = 'free_move_6dof';
  static const bioHeartOverlay     = 'bio_heart_overlay';
  static const bioNeuralFlow       = 'bio_neural_flow';
  static const metalHoming         = 'metal_homing';
  static const rawSigintStream     = 'raw_sigint_stream';
  static const fftSensitivity      = 'fft_sensitivity';
  static const encryptedVault      = 'encrypted_vault';

  // ── V47: UNIVERSAL SOVEREIGN EDITION ────────────────────────────────
  static const nativeGlRenderer    = 'native_gl_renderer';
  static const glassmorphismHud    = 'glassmorphism_hud';
  static const zeroMockData        = 'zero_mock_data';
  static const gpuTierDetection    = 'gpu_tier_detection';
  static const frustumCulling      = 'frustum_culling';

  // ── V48.1 ────────────────────────────────────────────────────────────
  static const cameraBackground    = 'camera_background';

  static const List<FeatureSection> sections = [
    // ── 1: ACTIVE SIGNALS — most used, always first ─────────────────────────
    FeatureSection(title: '📡 ACTIVE SIGNALS', icon: Icons.radar, color: Color(0xFF00CCFF), keys: [
      wifiCSI, bluetoothScan, cellularMonitor, magnetometer,
      directionFinding, jammerDetection, waterVoidDetection, aiSignalSummary,
    ]),
    // ── 2: 3D VISION ENGINE ──────────────────────────────────────────────────
    FeatureSection(title: '👁 3D VISION ENGINE', icon: Icons.view_in_ar, color: Color(0xFF00FF41), keys: [
      gyroMotion, freeMoveMode, droneTopDown, floorGrid, cameraBackground,
      invisibleCamera, codeRain, particleHuman, signalHeatmap,
      wireframeBuildings, backgroundFigures, bioHologram,
      scanlines, glitchEffects, codeRainChars, neuralTendrils,
    ]),
    // ── 3: QUANTUM BIO ENGINE ────────────────────────────────────────────────
    FeatureSection(title: '🔬 QUANTUM BIO ENGINE', icon: Icons.bolt, color: Color(0xFF00FFFF), keys: [
      quantumEngine, bioTomography, metallurgicRadar,
      bioHeartOverlay, bioNeuralFlow, metalHoming, fftSensitivity,
    ]),
    // ── 4: RECORDING & REPLAY ────────────────────────────────────────────────
    FeatureSection(title: '⏺ RECORDING & REPLAY', icon: Icons.fiber_manual_record, color: Color(0xFFFF3333), keys: [
      recording, backgroundRecord, replaySystem, signalPlaybackSim,
    ]),
    // ── 5: MULTI-DEVICE & MESH ───────────────────────────────────────────────
    FeatureSection(title: '🔗 MESH & COMMUNITY', icon: Icons.hub, color: Color(0xFFFF8C00), keys: [
      communityMap, multiDeviceMesh,
    ]),
    // ── 6: PRIVACY & STEALTH ─────────────────────────────────────────────────
    FeatureSection(title: '🔒 PRIVACY & STEALTH', icon: Icons.security, color: Color(0xFFFFD700), keys: [
      stealthMode, encryptedVault, rawSigintStream,
    ]),
    // ── 7: COUNTERMEASURES ───────────────────────────────────────────────────
    FeatureSection(title: '🎖 COUNTERMEASURES', icon: Icons.military_tech, color: Color(0xFFFF6600), keys: [
      jammerCountermeasure, rssiHeatmapOverlay, anomalyAlert, objectLabeling,
      customPointRendering, multiSignalCalib, voiceActivatedScan, voiceCommands,
    ]),
    // ── 8: INTERFACE & EXPORT ────────────────────────────────────────────────
    FeatureSection(title: '🖥 INTERFACE & EXPORT', icon: Icons.dashboard_customize, color: Color(0xFFFF00FF), keys: [
      hudOverlay, customizableHUD, statsPanel, waveformOverlay, export3D,
      exportExternal, homeWidget,
    ]),
    // ── 9: POWER & ENGINE ────────────────────────────────────────────────────
    FeatureSection(title: '⚡ POWER & ENGINE', icon: Icons.shield, color: Color(0xFF00E5FF), keys: [
      batteryOptScan, nativeGlRenderer, glassmorphismHud, frustumCulling,
      gpuTierDetection, zeroMockData,
    ]),
  ];
}

class FeatureSection {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> keys;
  const FeatureSection({required this.title, required this.icon, required this.color, required this.keys});
}

class FeatureMeta {
  final String label;
  final String description;
  final IconData icon;
  final bool defaultOn;
  final bool requiresRoot;
  const FeatureMeta({required this.label, required this.description, required this.icon, this.defaultOn = true, this.requiresRoot = false});
}

const _kFeatureMeta = <String, FeatureMeta>{
  FKey.gyroMotion:         FeatureMeta(label: 'Gyro Motion Control', description: 'Tilt phone to look around 3D scene (yaw/pitch/roll)', icon: Icons.screen_rotation, defaultOn: false),
  FKey.pinchZoom:          FeatureMeta(label: 'Pinch-to-Zoom', description: 'Two-finger scale gesture in all 3D modes', icon: Icons.pinch),
  FKey.droneTopDown:       FeatureMeta(label: 'Drone Top-Down View', description: 'Strategic cinematic military view from above', icon: Icons.flight, defaultOn: false),
  FKey.signalHeatmap:      FeatureMeta(label: 'Live Signal Heatmap', description: 'RF heat map overlay on 3D scene', icon: Icons.thermostat, defaultOn: false),
  FKey.floorGrid:          FeatureMeta(label: 'Floor Grid', description: 'Perspective grid on ground plane', icon: Icons.grid_on),
  FKey.wireframeBuildings: FeatureMeta(label: 'Wireframe Buildings', description: '3D building corridor in background', icon: Icons.architecture, defaultOn: false),
  FKey.backgroundFigures:  FeatureMeta(label: 'Background Figures', description: 'Stick figures at depth', icon: Icons.people_outline, defaultOn: false),
  FKey.bioHologram:        FeatureMeta(label: 'Bio Hologram', description: 'Blue anatomical figure', icon: Icons.accessibility_new, defaultOn: false),
  FKey.scanlines:          FeatureMeta(label: 'Scanline Overlay', description: 'CRT-style horizontal scan lines', icon: Icons.horizontal_rule, defaultOn: false),
  FKey.glitchEffects:      FeatureMeta(label: 'Glitch Effects', description: 'Random glitch streaks', icon: Icons.broken_image, defaultOn: false),
  FKey.codeRain:           FeatureMeta(label: 'Code Rain', description: 'Vertical katakana/binary rain overlay', icon: Icons.code),
  FKey.codeRainChars:      FeatureMeta(label: 'Code Rain Characters', description: 'Replace dots with random chars (Japanese/Arabic/English)', icon: Icons.text_fields, defaultOn: false),
  FKey.particleHuman:      FeatureMeta(label: 'Particle Human', description: 'Centre glowing particle figure', icon: Icons.person),
  FKey.neuralTendrils:     FeatureMeta(label: 'Neural Tendrils', description: '3D floating signal tendrils', icon: Icons.timeline, defaultOn: false),

  FKey.wifiCSI:            FeatureMeta(label: 'Wi-Fi CSI', description: 'Channel state information processing', icon: Icons.wifi),
  FKey.bluetoothScan:      FeatureMeta(label: 'Bluetooth Scan', description: 'BLE device detection', icon: Icons.bluetooth),
  FKey.cellularMonitor:    FeatureMeta(label: 'Cellular Monitor', description: 'Cell tower RSSI tracking + 3D fusion', icon: Icons.cell_tower),
  FKey.magnetometer:       FeatureMeta(label: 'Magnetometer', description: 'Magnetic anomaly detection (MAD)', icon: Icons.explore),
  FKey.directionFinding:   FeatureMeta(label: 'Direction Finding', description: 'Signal source triangulation arrows', icon: Icons.navigation, defaultOn: false),
  FKey.jammerDetection:    FeatureMeta(label: 'Jammer Detection', description: 'RF jamming alert system', icon: Icons.warning_amber, defaultOn: false),
  FKey.waterVoidDetection: FeatureMeta(label: 'Water & Void Mode', description: 'Detect voids and water pockets', icon: Icons.water_drop, defaultOn: false),
  FKey.aiSignalSummary:    FeatureMeta(label: 'AI Signal Summary', description: 'Text summary of all detections', icon: Icons.smart_toy, defaultOn: false),

  FKey.recording:          FeatureMeta(label: 'Recording System', description: 'Record raw signal data to file', icon: Icons.fiber_manual_record),
  FKey.backgroundRecord:   FeatureMeta(label: 'Background Recording', description: 'Continuous recording in background', icon: Icons.record_voice_over, defaultOn: false),
  FKey.invisibleCamera:    FeatureMeta(label: 'Invisible Radio Camera', description: 'Real: camera active for AR but preview hidden — covert operation, no visual output', icon: Icons.videocam_off, requiresRoot: false, defaultOn: false),
  FKey.replaySystem:       FeatureMeta(label: 'Replay System', description: 'Load and replay recorded sessions', icon: Icons.replay),

  FKey.stealthMode:        FeatureMeta(label: 'Stealth Mode', description: 'Zero-emission silent operation', icon: Icons.visibility_off, requiresRoot: true, defaultOn: false),
  FKey.voiceCommands:      FeatureMeta(label: 'Voice Commands', description: 'Real: accelerometer gesture control — shake=stealth, triple-tap=cycle mode', icon: Icons.vibration, defaultOn: false),
  FKey.multiDeviceMesh:    FeatureMeta(label: 'Multi-Device Mesh', description: 'Real: BLE peer scan for Falcon Eye instances, shows mesh peers on minimap as orange dots', icon: Icons.device_hub, defaultOn: false),
  FKey.communityMap:       FeatureMeta(label: 'Community Map', description: 'Real: BLE peer discovery — shows nearby Falcon Eye users as orange dots on compass minimap', icon: Icons.map, defaultOn: false),

  FKey.hudOverlay:         FeatureMeta(label: 'HUD Overlay', description: 'Heads-up display overlay', icon: Icons.layers),
  FKey.customizableHUD:    FeatureMeta(label: 'Customizable HUD', description: 'Real: long-press unlocks HUD panels for drag-repositioning, positions auto-saved', icon: Icons.dashboard_customize, defaultOn: false),
  FKey.statsPanel:         FeatureMeta(label: 'Stats Panel', description: 'Live telemetry stats panel', icon: Icons.analytics, defaultOn: false),
  FKey.waveformOverlay:    FeatureMeta(label: 'Waveform Overlay', description: 'Signal waveform at bottom', icon: Icons.waves, defaultOn: false),
  FKey.homeWidget:         FeatureMeta(label: 'Home Screen Widget', description: 'Real: persistent Android notification with live BLE/Cell/WiFi/Matter counts updating every 10s', icon: Icons.notifications_active, defaultOn: false),
  FKey.export3D:           FeatureMeta(label: '3D Scene Export', description: 'Export current 3D scene', icon: Icons.share, defaultOn: false),

  // V42 NEW FEATURES
  FKey.rssiHeatmapOverlay:   FeatureMeta(label: 'RSSI Heatmap Overlay', description: 'Real-time Wi-Fi/BT RSSI spatial heat map in 3D views', icon: Icons.thermostat_auto, defaultOn: false),
  FKey.anomalyAlert:         FeatureMeta(label: 'Anomaly Alert + Haptic', description: 'Detect signal anomalies (CSI variance/mag spikes) with haptic vibration', icon: Icons.vibration, defaultOn: false),
  FKey.signalPlaybackSim:    FeatureMeta(label: 'Signal Playback Simulator', description: 'Real: injects recorded session frames into live 3D view — replays past scans as live signal feed', icon: Icons.model_training, defaultOn: false),
  FKey.batteryOptScan:       FeatureMeta(label: 'Battery-Optimized Scan', description: 'Real: caps FPS to 20, BLE burst every 30s, drops heavy effects — ~52% CPU saving', icon: Icons.battery_saver, defaultOn: false),
  FKey.multiSignalCalib:     FeatureMeta(label: 'Multi-Signal Calibration', description: 'Calibrate sensors (baseline magnetometer/CSI). Root: kernel tweaks', icon: Icons.tune, defaultOn: false, requiresRoot: false),
  FKey.objectLabeling:       FeatureMeta(label: 'Object Labeling & Distance', description: 'Auto-label objects in 3D (e.g. "Human at 2.3m", "Metal at 1.5m")', icon: Icons.label, defaultOn: false),
  FKey.exportExternal:       FeatureMeta(label: 'Export to External Tools', description: 'Real: auto-saves matter detections CSV to Downloads on each scan complete', icon: Icons.download, defaultOn: false),
  FKey.voiceActivatedScan:   FeatureMeta(label: 'Voice-Activated Scan', description: 'Real: accelerometer double body-tap (>18m/s²) triggers 5s burst scan — hands-free', icon: Icons.touch_app, defaultOn: false),
  FKey.jammerCountermeasure:  FeatureMeta(label: 'Jammer Countermeasure', description: 'Real: BLE LOW_LATENCY mode + RSSI variance jammer confidence scoring when activated', icon: Icons.security_update_warning, defaultOn: false),
  FKey.customPointRendering: FeatureMeta(label: 'Custom Point Rendering', description: 'Switch: dots, random chars (JP/AR/EN), or lines for digital twin', icon: Icons.scatter_plot, defaultOn: false),

  // V47.7 NEW FEATURES
  FKey.quantumEngine:      FeatureMeta(label: 'Quantum Graphics Engine', description: '120FPS VBO renderer with atomic-scale point cloud and frustum culling', icon: Icons.bolt),
  FKey.bioTomography:      FeatureMeta(label: 'Bio-Signal Tomography', description: 'FFT on CSI data: respiration (0.2-0.5Hz) + heart rate (1.0-1.5Hz)', icon: Icons.biotech),
  FKey.metallurgicRadar:   FeatureMeta(label: 'Metallurgic Radar', description: 'Magnetometer susceptibility analysis for element identification', icon: Icons.radar),
  FKey.freeMoveMode:       FeatureMeta(label: '6DoF Free-Move Mode', description: 'Real: removes ±18 unit camera bound — fly unlimited distance into signal space', icon: Icons.open_with, defaultOn: false),
  FKey.bioHeartOverlay:    FeatureMeta(label: 'Bio Heart Overlay', description: 'Pulsing red heartbeat visualization on detected bio-mass', icon: Icons.favorite),
  FKey.bioNeuralFlow:      FeatureMeta(label: 'Neural Flow Lines', description: 'Blue neural impulse flow lines on detected humans', icon: Icons.psychology),
  FKey.metalHoming:        FeatureMeta(label: 'Metal Homing System', description: '3D arrow compass-lock to selected metal with distance', icon: Icons.my_location),
  FKey.rawSigintStream:    FeatureMeta(label: 'Raw SIGINT Stream', description: 'Live scrolling Wi-Fi/BT/Cell/Mag/CSI raw packet display', icon: Icons.terminal),
  FKey.fftSensitivity:     FeatureMeta(label: 'FFT Sensitivity', description: 'Adjustable gain for bio-frequency detection', icon: Icons.tune),
  FKey.encryptedVault:     FeatureMeta(label: 'Encrypted Hive Vault', description: 'AES-encrypted local storage for all signal recordings', icon: Icons.enhanced_encryption),

  // V48.1 SOVEREIGN ENGINE
  FKey.nativeGlRenderer:   FeatureMeta(label: 'Native OpenGL Renderer', description: 'C++ OpenGL ES 3.0 VBO pipeline via dart:ffi for 500K+ points at 120FPS', icon: Icons.memory),
  FKey.glassmorphismHud:   FeatureMeta(label: 'Glassmorphism HUD', description: 'Tactical frosted-glass UI with neon Cyan/Green accents', icon: Icons.blur_on),
  FKey.zeroMockData:       FeatureMeta(label: 'Zero Mock Data', description: 'Real: blocks CSI interpolation fallback — void stays empty until actual hardware signal', icon: Icons.verified),
  FKey.gpuTierDetection:   FeatureMeta(label: 'GPU Tier Detection', description: 'Auto-detect Adreno/Mali/Unknown and set point budget accordingly', icon: Icons.developer_board),
  FKey.frustumCulling:     FeatureMeta(label: 'Frustum Culling', description: 'GPU-side view cone rejection: only render visible points', icon: Icons.filter_center_focus),

  // V48.1
  FKey.cameraBackground:   FeatureMeta(label: 'Camera AR Background', description: 'Live camera feed as background behind 3D signal overlay — AR mode', icon: Icons.camera_alt, defaultOn: false),
};

FeatureMeta featureMeta(String key) =>
    _kFeatureMeta[key] ?? const FeatureMeta(label: 'Unknown', description: '', icon: Icons.help);

// ─── Features State ────────────────────────────────────────────────────────────
class FeaturesState {
  final Map<String, bool> toggles;
  final FalconTheme theme;
  final bool hasRoot;
  /// Name of the active VisionMode (string to avoid circular import with vision_mode.dart)
  final String activeModeName;

  const FeaturesState({
    required this.toggles,
    required this.theme,
    required this.hasRoot,
    this.activeModeName = 'neoMatrix',
  });

  bool operator [](String key) => toggles[key] ?? featureMeta(key).defaultOn;

  FeaturesState copyWith({
    Map<String, bool>? toggles,
    FalconTheme? theme,
    bool? hasRoot,
    String? activeModeName,
  }) => FeaturesState(
    toggles: toggles ?? this.toggles,
    theme: theme ?? this.theme,
    hasRoot: hasRoot ?? this.hasRoot,
    activeModeName: activeModeName ?? this.activeModeName,
  );

  Color get primaryColor => theme.primary;
  Color get secondaryColor => theme.secondary;
  Color get backgroundColor => theme.background;
  Color get surfaceColor => theme.surface;
  Color get accentColor => theme.accent;
}

// ─── Features Service ──────────────────────────────────────────────────────────
class FeaturesService extends Notifier<FeaturesState> {
  static const _kPrefsKey = 'falcon_features_v46';
  static const _kThemeKey = 'falcon_theme_v46';

  @override
  FeaturesState build() {
    _load();
    return FeaturesState(toggles: _buildDefaults(), theme: FalconTheme.neoGreen, hasRoot: false);
  }

  Map<String, bool> _buildDefaults() {
    final map = <String, bool>{};
    for (final section in FKey.sections) {
      for (final key in section.keys) {
        map[key] = featureMeta(key).defaultOn;
      }
    }
    return map;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kPrefsKey);
      final themeIdx = prefs.getInt(_kThemeKey) ?? 0;
      final theme = FalconTheme.values[themeIdx.clamp(0, FalconTheme.values.length - 1)];
      final toggles = _buildDefaults();
      if (json != null) {
        final saved = jsonDecode(json) as Map<String, dynamic>;
        for (final e in saved.entries) {
          if (toggles.containsKey(e.key)) toggles[e.key] = e.value as bool;
        }
      }
      state = state.copyWith(toggles: toggles, theme: theme);
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsKey, jsonEncode(state.toggles));
      await prefs.setInt(_kThemeKey, FalconTheme.values.indexOf(state.theme));
    } catch (_) {}
  }

  void setHasRoot(bool value) => state = state.copyWith(hasRoot: value);

  void toggle(String key, {bool? value}) {
    final meta = featureMeta(key);
    if (meta.requiresRoot && !state.hasRoot) return;
    final newToggles = Map<String, bool>.from(state.toggles);
    newToggles[key] = value ?? !(state[key]);
    state = state.copyWith(toggles: newToggles);
    _save();
  }

  void setTheme(FalconTheme theme) {
    state = state.copyWith(theme: theme);
    _save();
  }

  /// Set mode by name only (used by neo_matrix page for local-only changes)
  void setActiveMode(String modeName) {
    state = state.copyWith(activeModeName: modeName);
  }

  /// Unified profile: set BOTH mode + its linked theme in one call.
  /// Called when user taps any card in the unified profile selector.
  void setProfile({required String modeName, required FalconTheme theme}) {
    state = state.copyWith(activeModeName: modeName, theme: theme);
    _save();
  }

  /// Called from theme chips in Settings — also activates the paired mode.
  void setThemeProfile(FalconTheme theme) {
    state = state.copyWith(theme: theme, activeModeName: theme.linkedModeName);
    _save();
  }

  void resetToDefaults() {
    state = state.copyWith(toggles: _buildDefaults());
    _save();
  }
}

final featuresProvider = NotifierProvider<FeaturesService, FeaturesState>(() => FeaturesService());
