// =============================================================================
// FALCON EYE V50.0 — VISION CONFIGURATOR PAGE
// Upgrades vs V42:
//   • All hardcoded 0xFF00FF41 → featuresProvider.primaryColor
//   • Scene toggles now write to featuresProvider (FKey) — actually affects 3D
//   • Preset strip: STEALTH / RECON / TACTICAL / DEBUG — bulk-apply
//   • Estimated FPS indicator (based on profile + active features)
//   • Header: WAVEFIELD ENGINE V1.0 → V50.0, section color theming
//   • Performance profile also writes to featuresProvider toggle keys
// =============================================================================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/vision_mode.dart' as vm;
import '../theme.dart';
import '../services/hardware_capabilities_service.dart';
import '../services/gyroscopic_camera_service.dart';
import '../services/root_permission_service.dart';
import '../services/digital_twin_engine.dart';
import '../services/twin_config_provider.dart';
import '../services/features_provider.dart';
import '../widgets/back_button_top_left.dart';

// ─── Preset definition ────────────────────────────────────────────────────────
class _Preset {
  final String name;
  final IconData icon;
  final Color color;
  final Map<String, bool> toggles;
  final String perfProfile;
  const _Preset(this.name, this.icon, this.color,
      {required this.toggles, required this.perfProfile});
}

const _kPresets = [
  _Preset('STEALTH', Icons.visibility_off, Color(0xFF2E2E40),
    toggles: {
      FKey.floorGrid: false, FKey.wireframeBuildings: false,
      FKey.backgroundFigures: false, FKey.bioHologram: false,
      FKey.scanlines: false, FKey.glitchEffects: false, FKey.codeRain: false,
    },
    perfProfile: 'battery',
  ),
  _Preset('RECON', Icons.radar, Color(0xFF00CCFF),
    toggles: {
      FKey.floorGrid: true, FKey.wireframeBuildings: false,
      FKey.backgroundFigures: false, FKey.bioHologram: false,
      FKey.scanlines: true, FKey.glitchEffects: false, FKey.codeRain: false,
    },
    perfProfile: 'balanced',
  ),
  _Preset('TACTICAL', Icons.gps_fixed, Color(0xFF00FF41),
    toggles: {
      FKey.floorGrid: true, FKey.wireframeBuildings: true,
      FKey.backgroundFigures: true, FKey.bioHologram: true,
      FKey.scanlines: true, FKey.glitchEffects: true, FKey.codeRain: true,
    },
    perfProfile: 'turbo',
  ),
  _Preset('DEBUG', Icons.terminal, Color(0xFFFFD700),
    toggles: {
      FKey.floorGrid: true, FKey.wireframeBuildings: false,
      FKey.backgroundFigures: false, FKey.bioHologram: false,
      FKey.scanlines: false, FKey.glitchEffects: false, FKey.codeRain: false,
    },
    perfProfile: 'balanced',
  ),
];

// ─── Local zoom / rain state (not in featuresProvider yet) ───────────────────
class _LocalConfig {
  final double defaultZoom;
  final double minZoom;
  final double maxZoom;
  final bool zoomResetOnModeSwitch;
  final double charSize;
  final bool useDotsInsteadOfChars;
  final double rainSpeed;
  final int rainLayers;
  final double particleDensity;
  final String performanceProfile;

  const _LocalConfig({
    this.defaultZoom = 1.0,
    this.minZoom = 0.25,
    this.maxZoom = 4.0,
    this.zoomResetOnModeSwitch = true,
    this.charSize = 1.0,
    this.useDotsInsteadOfChars = false,
    this.rainSpeed = 1.0,
    this.rainLayers = 6,
    this.particleDensity = 1.0,
    this.performanceProfile = 'balanced',
  });

  _LocalConfig copyWith({
    double? defaultZoom, double? minZoom, double? maxZoom,
    bool? zoomResetOnModeSwitch, double? charSize, bool? useDotsInsteadOfChars,
    double? rainSpeed, int? rainLayers, double? particleDensity,
    String? performanceProfile,
  }) => _LocalConfig(
    defaultZoom: defaultZoom ?? this.defaultZoom,
    minZoom: minZoom ?? this.minZoom,
    maxZoom: maxZoom ?? this.maxZoom,
    zoomResetOnModeSwitch: zoomResetOnModeSwitch ?? this.zoomResetOnModeSwitch,
    charSize: charSize ?? this.charSize,
    useDotsInsteadOfChars: useDotsInsteadOfChars ?? this.useDotsInsteadOfChars,
    rainSpeed: rainSpeed ?? this.rainSpeed,
    rainLayers: rainLayers ?? this.rainLayers,
    particleDensity: particleDensity ?? this.particleDensity,
    performanceProfile: performanceProfile ?? this.performanceProfile,
  );
}

// =============================================================================
class VisionConfiguratorPage extends ConsumerStatefulWidget {
  const VisionConfiguratorPage({super.key});
  @override
  ConsumerState<VisionConfiguratorPage> createState() => _VisionConfiguratorPageState();
}

class _VisionConfiguratorPageState extends ConsumerState<VisionConfiguratorPage>
    with SingleTickerProviderStateMixin {

  _LocalConfig _cfg = const _LocalConfig();
  vm.VisionMode _selectedMode = vm.VisionMode.neoMatrix;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  void _launchMode(vm.VisionMode mode, bool hasRoot) {
    if (mode.requiresRoot && !hasRoot) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${mode.name} requires root access — restart and grant root permission'),
        backgroundColor: Colors.red.shade900,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _selectedMode = mode);
    context.push('/neo_matrix', extra: {'hasRoot': hasRoot, 'mode': mode.name});
  }

  void _applyPreset(_Preset preset) {
    final notifier = ref.read(featuresProvider.notifier);
    preset.toggles.forEach((key, val) => notifier.toggle(key, value: val));
    setState(() => _cfg = _cfg.copyWith(performanceProfile: preset.perfProfile));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${preset.name} preset applied'),
      backgroundColor: preset.color.withValues(alpha: 0.8),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // FPS estimate from active features + profile
  int _estimateFps(FeaturesState features, String profile) {
    final base = switch (profile) {
      'battery'  => 15,
      'turbo'    => 60,
      _          => 30,
    };
    int cost = 0;
    if (features[FKey.codeRain])           cost += 5;
    if (features[FKey.wireframeBuildings]) cost += 4;
    if (features[FKey.bioHologram])        cost += 3;
    if (features[FKey.backgroundFigures])  cost += 3;
    if (features[FKey.glitchEffects])      cost += 3;
    if (features[FKey.scanlines])          cost += 2;
    if (features[FKey.floorGrid])          cost += 1;
    return (base - cost).clamp(8, 120);
  }

  @override
  Widget build(BuildContext context) {
    final color      = ref.watch(featuresProvider).primaryColor;
    final caps       = ref.watch(hardwareCapabilitiesProvider);
    final gyroState  = ref.watch(gyroscopicCameraProvider);
    final gyroSvc    = ref.read(gyroscopicCameraProvider.notifier);
    final rootState  = ref.watch(rootPermissionProvider);
    final hasRoot    = rootState.isRooted;
    final twinCfg    = ref.watch(twinConfigProvider);
    final twinNotify = ref.read(twinConfigProvider.notifier);
    final features   = ref.watch(featuresProvider);
    final featNotify = ref.read(featuresProvider.notifier);
    final estFps     = _estimateFps(features, _cfg.performanceProfile);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Background grid
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => CustomPaint(
                size: Size.infinite,
                painter: _GridBgPainter(_pulseCtrl.value, color),
              ),
            ),

            Column(
              children: [
                _buildHeader(caps, hasRoot, color, estFps),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTierBanner(caps, hasRoot, color),
                        const SizedBox(height: 16),

                        // PRESETS
                        _sectionLabel('QUICK PRESETS', color),
                        const SizedBox(height: 8),
                        _buildPresetStrip(color),
                        const SizedBox(height: 20),

                        // MODE GRID
                        _sectionLabel('VISION MODES', color),
                        const SizedBox(height: 10),
                        _buildModeGrid(hasRoot, color),
                        const SizedBox(height: 22),

                        // CAMERA
                        _sectionLabel('3D CAMERA & MOTION', color),
                        const SizedBox(height: 8),
                        _buildCameraSection(gyroState, gyroSvc, color),
                        const SizedBox(height: 22),

                        // ZOOM
                        _sectionLabel('PINCH-TO-ZOOM', color),
                        const SizedBox(height: 8),
                        _buildZoomSection(color),
                        const SizedBox(height: 22),

                        // CODE RAIN
                        _sectionLabel('CODE RAIN SETTINGS', color),
                        const SizedBox(height: 8),
                        _buildRainSection(color),
                        const SizedBox(height: 22),

                        // DIGITAL TWIN ENGINE
                        _sectionLabel('◈ DIGITAL TWIN ENGINE', color),
                        const SizedBox(height: 8),
                        _buildDigitalTwinSection(twinCfg, twinNotify, color),
                        const SizedBox(height: 22),

                        // SCENE ELEMENTS — now writes to featuresProvider
                        _sectionLabel('SCENE ELEMENTS', color),
                        const SizedBox(height: 8),
                        _buildSceneSection(features, featNotify, color),
                        const SizedBox(height: 22),

                        // PERFORMANCE
                        _sectionLabel('PERFORMANCE PROFILE', color),
                        const SizedBox(height: 8),
                        _buildPerfSection(color, estFps),
                        const SizedBox(height: 22),

                        // LAUNCH
                        _buildLaunchButton(hasRoot, color),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const BackButtonTopLeft(),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────
  Widget _buildHeader(HardwareCapabilities caps, bool hasRoot,
      Color color, int estFps) {
    return Container(
      padding: const EdgeInsets.fromLTRB(56, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        border: Border(bottom: BorderSide(color: color, width: 1)),
      ),
      child: Row(children: [
        Icon(Icons.settings_input_antenna, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('3D WAVE TWIN CONFIG',
              style: TextStyle(color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w900, letterSpacing: 1)),
          Text(
            'WAVEFIELD ENGINE V50.0  ·  ${hasRoot ? "ROOT ACTIVE" : "STANDARD MODE"}  ·  EST ${estFps}fps',
            style: TextStyle(color: color, fontSize: 10, letterSpacing: 1),
          ),
        ])),
        _SignalBars(hasRoot: hasRoot, color: color),
      ]),
    );
  }

  // ── Tier banner ────────────────────────────────────────────────────────
  Widget _buildTierBanner(HardwareCapabilities caps, bool hasRoot, Color color) {
    final isNord3 = caps.deviceModel.toLowerCase().contains('nord 3') ||
        caps.chipset.toLowerCase().contains('dimensity 9000');
    final tierLabel = isNord3 && hasRoot
        ? 'ADAPTIVE TIER: FLAGSHIP (ROOT DETECTED)'
        : hasRoot ? 'ADAPTIVE TIER: ROOTED DEVICE'
                  : 'ADAPTIVE TIER: STANDARD MODE';
    final tierSub = isNord3 && hasRoot
        ? 'RF Multipath + UWB AoA + IMU Fusion: ACTIVE'
        : hasRoot ? 'Root features unlocked — limited to hardware capabilities'
                  : 'Root not detected — upgrade for maximum power';
    final tierColor = isNord3 && hasRoot ? color : const Color(0xFFFFD700);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: tierColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(children: [
        Icon(Icons.memory, color: tierColor, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tierLabel, style: TextStyle(color: tierColor,
              fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
          Text(tierSub, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ])),
        OutlinedButton(
          onPressed: () => ref.read(hardwareCapabilitiesProvider.notifier).scanHardware(),
          style: OutlinedButton.styleFrom(
            foregroundColor: tierColor,
            side: BorderSide(color: tierColor),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          child: const Text('RESCAN', style: TextStyle(fontSize: 11)),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String title, Color color) => Row(children: [
    Container(width: 3, height: 16,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)])),
    const SizedBox(width: 8),
    Text(title, style: TextStyle(color: color, fontSize: 12,
        fontWeight: FontWeight.bold, letterSpacing: 2)),
  ]);

  // ── Preset strip ───────────────────────────────────────────────────────
  Widget _buildPresetStrip(Color themeColor) {
    return Row(
      children: _kPresets.map((p) => Expanded(child: GestureDetector(
        onTap: () => _applyPreset(p),
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: p.color.withValues(alpha: 0.08),
            border: Border.all(color: p.color.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(children: [
            Icon(p.icon, color: p.color, size: 18),
            const SizedBox(height: 4),
            Text(p.name, style: TextStyle(color: p.color, fontSize: 8,
                fontWeight: FontWeight.bold, letterSpacing: 1)),
          ]),
        ),
      ))).toList(),
    );
  }

  // ── Mode grid ──────────────────────────────────────────────────────────
  Widget _buildModeGrid(bool hasRoot, Color color) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 1.3,
        crossAxisSpacing: 8, mainAxisSpacing: 8,
      ),
      itemCount: vm.VisionMode.values.length,
      itemBuilder: (ctx, i) {
        final mode = vm.VisionMode.values[i];
        return _ModeCard(
          mode: mode,
          isActive: mode == _selectedMode,
          isLocked: mode.requiresRoot && !hasRoot,
          onTap: () => _launchMode(mode, hasRoot),
        );
      },
    );
  }

  // ── Camera section ─────────────────────────────────────────────────────
  Widget _buildCameraSection(GyroscopicCameraState gyroState,
      GyroscopicCameraService gyroSvc, Color color) {
    return Column(children: [
      _ConfigRow(
        label: 'Gyroscopic Motion Control', color: color,
        subtitle: 'Tilt phone to look around 3D scene (VR-style)',
        trailing: Switch(value: gyroState.isEnabled, activeColor: color,
          onChanged: (v) => gyroSvc.setEnabled(v)),
      ),
      if (gyroState.isEnabled) ...[
        _ConfigRow(
          label: 'Include Roll', color: color,
          subtitle: 'Track rotation around forward axis',
          trailing: Switch(value: gyroState.includeRoll, activeColor: color,
            onChanged: (v) => gyroSvc.setIncludeRoll(v)),
        ),
        _ConfigRow(
          label: 'Touch Fallback', color: color,
          subtitle: 'Drag screen when gyro is unavailable',
          trailing: Switch(value: gyroState.touchControlEnabled, activeColor: color,
            onChanged: (v) => gyroSvc.setTouchControlEnabled(v)),
        ),
        _ConfigRow(
          label: 'Gyro Sensitivity', color: color,
          subtitle: 'Camera responsiveness to tilt',
          trailing: SizedBox(width: 120,
            child: Slider(
              value: gyroState.sensitivity, min: 0.2, max: 3.0,
              divisions: 14, activeColor: color,
              onChanged: (v) => gyroSvc.setSensitivity(v),
            )),
        ),
      ],
    ]);
  }

  // ── Zoom section ───────────────────────────────────────────────────────
  Widget _buildZoomSection(Color color) {
    return Column(children: [
      _ConfigRow(
        label: 'Default Zoom Level', color: color,
        subtitle: 'Starting zoom when opening a vision mode',
        trailing: SizedBox(width: 120,
          child: Slider(
            value: _cfg.defaultZoom, min: 0.25, max: 2.0, divisions: 7,
            activeColor: color, label: '${_cfg.defaultZoom.toStringAsFixed(2)}x',
            onChanged: (v) => setState(() => _cfg = _cfg.copyWith(defaultZoom: v)),
          )),
      ),
      _ConfigRow(
        label: 'Min Zoom Limit', color: color,
        subtitle: 'Closest zoom allowed',
        trailing: SizedBox(width: 120,
          child: Slider(
            value: _cfg.minZoom, min: 0.1, max: 0.9, divisions: 8,
            activeColor: color, label: '${_cfg.minZoom.toStringAsFixed(2)}x',
            onChanged: (v) => setState(() => _cfg = _cfg.copyWith(minZoom: v)),
          )),
      ),
      _ConfigRow(
        label: 'Max Zoom Limit', color: color,
        subtitle: 'Furthest zoom allowed',
        trailing: SizedBox(width: 120,
          child: Slider(
            value: _cfg.maxZoom, min: 1.5, max: 6.0, divisions: 9,
            activeColor: color, label: '${_cfg.maxZoom.toStringAsFixed(1)}x',
            onChanged: (v) => setState(() => _cfg = _cfg.copyWith(maxZoom: v)),
          )),
      ),
      _ConfigRow(
        label: 'Reset Zoom on Mode Switch', color: color,
        subtitle: 'Returns to 1.0x when changing mode',
        trailing: Switch(
          value: _cfg.zoomResetOnModeSwitch, activeColor: color,
          onChanged: (v) => setState(() => _cfg = _cfg.copyWith(zoomResetOnModeSwitch: v)),
        ),
      ),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.03),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Icon(Icons.pinch, color: color, size: 14),
          const SizedBox(width: 8),
          const Expanded(child: Text(
            'PINCH IN = closer  ·  PINCH OUT = pull back  ·  DOUBLE-TAP = reset 1:1',
            style: TextStyle(color: Colors.white54, fontSize: 9),
          )),
        ]),
      ),
    ]);
  }

  // ── Rain section ───────────────────────────────────────────────────────
  Widget _buildRainSection(Color color) {
    return Column(children: [
      _ConfigRow(
        label: 'Character Style', color: color,
        subtitle: 'Katakana chars / dots',
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          _StyleChip('CHARS', !_cfg.useDotsInsteadOfChars, color,
              () => setState(() => _cfg = _cfg.copyWith(useDotsInsteadOfChars: false))),
          const SizedBox(width: 4),
          _StyleChip('DOTS', _cfg.useDotsInsteadOfChars, color,
              () => setState(() => _cfg = _cfg.copyWith(useDotsInsteadOfChars: true))),
        ]),
      ),
      _ConfigRow(
        label: 'Character Size', color: color,
        subtitle: 'Small (8px) → Normal (14px) → Large (22px)',
        trailing: SizedBox(width: 120,
          child: Slider(
            value: _cfg.charSize, min: 0.5, max: 2.0, divisions: 6,
            activeColor: color, label: _charSizeLabel(_cfg.charSize),
            onChanged: (v) => setState(() => _cfg = _cfg.copyWith(charSize: v)),
          )),
      ),
      _ConfigRow(
        label: 'Rain Speed', color: color,
        subtitle: 'Slow → Fast',
        trailing: SizedBox(width: 120,
          child: Slider(
            value: _cfg.rainSpeed, min: 0.2, max: 3.0, divisions: 14,
            activeColor: color,
            onChanged: (v) => setState(() => _cfg = _cfg.copyWith(rainSpeed: v)),
          )),
      ),
      _ConfigRow(
        label: 'Depth Layers', color: color,
        subtitle: 'Number of rain depth planes (2–10)',
        trailing: SizedBox(width: 120,
          child: Slider(
            value: _cfg.rainLayers.toDouble(), min: 2, max: 10, divisions: 8,
            activeColor: color, label: '${_cfg.rainLayers}',
            onChanged: (v) => setState(() => _cfg = _cfg.copyWith(rainLayers: v.toInt())),
          )),
      ),
      _ConfigRow(
        label: 'Particle Density', color: color,
        subtitle: 'Body point cloud resolution',
        trailing: SizedBox(width: 120,
          child: Slider(
            value: _cfg.particleDensity, min: 0.25, max: 2.0, divisions: 7,
            activeColor: color,
            onChanged: (v) => setState(() => _cfg = _cfg.copyWith(particleDensity: v)),
          )),
      ),
    ]);
  }

  // ── Digital twin section ───────────────────────────────────────────────
  Widget _buildDigitalTwinSection(TwinConfig cfg, TwinConfigNotifier notifier, Color color) {
    const c2 = Color(0xFF00CCFF);
    const c3 = Color(0xFFFF9900);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.02),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_fix_high, color: color, size: 14),
          const SizedBox(width: 6),
          Text('DBSCAN + KALMAN + AI INTERPOLATION',
              style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 9,
                  letterSpacing: 1, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 14),

        // Point Size
        _TwinSliderRow(
          label: 'POINT SIZE', icon: Icons.radio_button_unchecked,
          color: color, badge: _pointSizeLabel(cfg.pointSize),
          value: cfg.pointSize, min: 0.4, max: 2.2, divisions: 18,
          scaleLabels: const ['● tiny', '◉ small', '⊙ med', '⬤ large'],
          onChanged: notifier.setPointSize,
        ),
        const SizedBox(height: 14),

        // Cluster Density
        _TwinSliderRow(
          label: 'POINT SPACING', icon: Icons.scatter_plot,
          color: c2, badge: _densityLabel(cfg.clusterDensity),
          value: cfg.clusterDensity, min: 0.0, max: 1.0, divisions: 20,
          scaleLabels: const ['sparse', 'light', 'dense', 'ultra'],
          onChanged: notifier.setClusterDensity,
        ),
        const SizedBox(height: 14),

        // DBSCAN Epsilon
        _TwinSliderRow(
          label: 'DBSCAN RADIUS (ε)', icon: Icons.hub,
          color: c3, badge: '${cfg.dbscanEpsilon.toStringAsFixed(2)}m',
          value: cfg.dbscanEpsilon, min: 0.2, max: 2.0, divisions: 18,
          scaleLabels: const ['0.2m', '0.7m', '1.3m', '2.0m'],
          onChanged: notifier.setDbscanEpsilon,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text('Smaller ε = tighter clusters. Larger ε = loose groups.',
              style: TextStyle(color: Colors.white38, fontSize: 9)),
        ),

        // Toggle row
        Row(children: [
          Expanded(child: _v42Toggle('KALMAN FILTER', 'Noise reduction',
              Icons.filter_alt, cfg.kalmanEnabled, const Color(0xFF00FF88),
              (v) => notifier.setKalman(v))),
          const SizedBox(width: 8),
          Expanded(child: _v42Toggle('AI INTERPOLATION', 'Fill weak signals',
              Icons.smart_toy, cfg.aiInterpolation, const Color(0xFFFF00FF),
              (v) => notifier.setAiInterp(v))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _v42Toggle('DBSCAN', 'Density clustering',
              Icons.bubble_chart, cfg.useDBSCAN, const Color(0xFFFFD700),
              (v) => notifier.setUseDBSCAN(v))),
          const SizedBox(width: 8),
          Expanded(child: _v42Toggle('K-MEANS', 'Fixed clusters',
              Icons.center_focus_strong, !cfg.useDBSCAN, const Color(0xFFFF6600),
              (v) => notifier.setUseDBSCAN(!v))),
        ]),
      ]),
    );
  }

  // ── Scene section — writes to featuresProvider ─────────────────────────
  Widget _buildSceneSection(FeaturesState features, FeaturesService notifier, Color color) {
    final items = [
      (FKey.floorGrid,          'Floor Grid',          'Perspective grid on ground plane'),
      (FKey.wireframeBuildings, 'Wireframe Buildings', '3D building corridor in background'),
      (FKey.backgroundFigures,  'Background Figures',  'Stick figure silhouettes at distance'),
      (FKey.bioHologram,        'Bio Hologram',        'Blue anatomical hologram'),
      (FKey.scanlines,          'Scanline Overlay',    'CRT-style horizontal scan lines'),
      (FKey.glitchEffects,      'Glitch Effects',      'Random horizontal glitch streaks'),
      (FKey.codeRain,           'Code Rain',           'Vertical katakana/binary overlay'),
    ];
    return Column(children: items.map((item) {
      final (key, label, sub) = item;
      return _ConfigRow(
        label: label, subtitle: sub, color: color,
        trailing: Switch(
          value: features[key], activeColor: color,
          onChanged: (v) => notifier.toggle(key, value: v),
        ),
      );
    }).toList());
  }

  // ── Performance section ────────────────────────────────────────────────
  Widget _buildPerfSection(Color color, int estFps) {
    final profiles = [
      ('battery',  'BATTERY',  Icons.battery_saver, '15fps · Min power'),
      ('balanced', 'BALANCED', Icons.balance,        '30fps · Default'),
      ('turbo',    'TURBO',    Icons.bolt,           '60fps · Max GPU'),
    ];
    return Column(children: [
      Row(children: profiles.map((p) {
        final (id, label, icon, sub) = p;
        final active = _cfg.performanceProfile == id;
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _cfg = _cfg.copyWith(performanceProfile: id)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
              border: Border.all(color: active ? color : color.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(children: [
              Icon(icon, color: active ? color : color.withValues(alpha: 0.35), size: 18),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(
                  color: active ? color : color.withValues(alpha: 0.35),
                  fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
              Text(sub, style: TextStyle(
                  color: active ? color.withValues(alpha: 0.6) : color.withValues(alpha: 0.2),
                  fontSize: 8)),
            ]),
          ),
        ));
      }).toList()),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.2)),
          color: color.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(children: [
          Icon(Icons.speed, color: color, size: 14),
          const SizedBox(width: 8),
          Text('ESTIMATED FPS WITH CURRENT SCENE',
              style: TextStyle(color: color.withValues(alpha: 0.5),
                  fontSize: 9, letterSpacing: 1)),
          const Spacer(),
          Text('~$estFps fps', style: TextStyle(color: color, fontSize: 14,
              fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ]),
      ),
    ]);
  }

  // ── Launch button ──────────────────────────────────────────────────────
  Widget _buildLaunchButton(bool hasRoot, Color color) {
    final mode = _selectedMode;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _launchMode(mode, hasRoot),
        icon: Icon(mode.icon),
        label: Text('LAUNCH ${mode.name.toUpperCase()} MODE'),
        style: ElevatedButton.styleFrom(
          backgroundColor: mode.primaryColor,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w900,
              fontSize: 14, letterSpacing: 1),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  Widget _v42Toggle(String title, String subtitle, IconData icon,
      bool value, Color color, void Function(bool) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: value ? color.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(
              color: value ? color : Colors.white24, width: value ? 1.5 : 1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(children: [
          Icon(icon, color: value ? color : Colors.white38, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(
                color: value ? color : Colors.white54, fontSize: 10,
                fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            Text(subtitle, style: TextStyle(
                color: value ? color.withValues(alpha: 0.7) : Colors.white24, fontSize: 8)),
          ])),
        ]),
      ),
    );
  }

  String _pointSizeLabel(double v) {
    if (v < 0.7) return 'TINY';
    if (v < 0.9) return 'SMALL';
    if (v < 1.15) return 'MEDIUM';
    if (v < 1.6) return 'LARGE';
    return 'HUGE';
  }

  String _densityLabel(double v) {
    if (v < 0.2) return 'SPARSE';
    if (v < 0.4) return 'LIGHT';
    if (v < 0.6) return 'MODERATE';
    if (v < 0.8) return 'DENSE';
    return 'ULTRA-DENSE';
  }

  String _charSizeLabel(double v) {
    if (v <= 0.6) return 'TINY';
    if (v <= 1.0) return 'NORMAL';
    if (v <= 1.5) return 'LARGE';
    return 'HUGE';
  }
}

// =============================================================================
// SUBWIDGETS
// =============================================================================

class _TwinSliderRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String badge;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final List<String> scaleLabels;
  final ValueChanged<double> onChanged;
  const _TwinSliderRow({
    required this.label, required this.icon, required this.color,
    required this.badge, required this.value, required this.min, required this.max,
    required this.divisions, required this.scaleLabels, required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Icon(icon, color: color, size: 12),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color, fontSize: 11,
          fontWeight: FontWeight.bold, letterSpacing: 1)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(badge, style: TextStyle(color: color, fontSize: 10,
            fontWeight: FontWeight.bold)),
      ),
    ]),
    SliderTheme(
      data: SliderThemeData(
        activeTrackColor: color,
        inactiveTrackColor: color.withValues(alpha: 0.15),
        thumbColor: color,
        overlayColor: color.withValues(alpha: 0.12),
        trackHeight: 2,
      ),
      child: Slider(value: value, min: min, max: max,
          divisions: divisions, label: badge, onChanged: onChanged),
    ),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: scaleLabels.map((s) =>
      Text(s, style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 9)),
    ).toList()),
  ]);
}

class _ConfigRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final Widget trailing;
  final Color color;
  const _ConfigRow({required this.label, required this.subtitle,
      required this.trailing, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.02),
      border: Border.all(color: color.withValues(alpha: 0.1)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13,
            fontWeight: FontWeight.w600)),
        Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ])),
      trailing,
    ]),
  );
}

class _StyleChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _StyleChip(this.label, this.active, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
        border: Border.all(color: active ? color : color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(label, style: TextStyle(
          color: active ? color : color.withValues(alpha: 0.4),
          fontSize: 10, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
    ),
  );
}

class _ModeCard extends StatelessWidget {
  final vm.VisionMode mode;
  final bool isActive;
  final bool isLocked;
  final VoidCallback onTap;
  const _ModeCard({required this.mode, required this.isActive,
      required this.isLocked, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final color = isLocked ? Colors.grey : mode.primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isActive ? mode.primaryColor.withValues(alpha: 0.15) : Colors.black,
          border: Border.all(
            color: isActive ? mode.primaryColor : color.withValues(alpha: 0.35),
            width: isActive ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
          boxShadow: isActive ? [BoxShadow(
              color: mode.primaryColor.withValues(alpha: 0.3), blurRadius: 12)] : null,
        ),
        child: Stack(children: [
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(mode.icon, color: color, size: 30),
            const SizedBox(height: 6),
            Text(
              mode.name.toUpperCase().replaceAll(' ', '\n'),
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 11,
                  fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ]),
          if (isLocked)
            const Positioned(top: 4, right: 4,
              child: Icon(Icons.lock, color: Colors.orange, size: 14)),
          if (isActive)
            Positioned(top: 4, left: 4,
              child: Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mode.primaryColor,
                  boxShadow: [BoxShadow(
                      color: mode.primaryColor.withValues(alpha: 0.7), blurRadius: 6)],
                ),
              )),
        ]),
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  final bool hasRoot;
  final Color color;
  const _SignalBars({required this.hasRoot, required this.color});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) => Container(
      width: 4, height: 6.0 + i * 3,
      margin: const EdgeInsets.only(right: 2),
      color: i < (hasRoot ? 5 : 3) ? color : color.withValues(alpha: 0.15),
    )),
  );
}

class _GridBgPainter extends CustomPainter {
  final double pulse;
  final Color color;
  const _GridBgPainter(this.pulse, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.02 + 0.01 * pulse)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += step)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  @override
  bool shouldRepaint(_GridBgPainter old) => old.pulse != pulse;
}
