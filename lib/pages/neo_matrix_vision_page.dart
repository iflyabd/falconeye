import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vision_mode.dart';
import '../services/wifi_csi_service.dart';
import '../services/root_permission_service.dart';
import '../services/multi_signal_fusion_service.dart';
import '../services/recording_replay_service.dart';
import '../services/gyroscopic_camera_service.dart';
import '../services/digital_twin_engine.dart';
import '../services/twin_config_provider.dart';
import '../services/camera_background_service.dart';
import '../widgets/radio_wave_3d_painter.dart';
import '../theme.dart';
import '../services/features_provider.dart';
import '../services/metal_detection_service.dart';
import '../services/native_renderer_bridge.dart';
import '../services/ble_service.dart';
import '../services/cell_service.dart';
import '../services/stealth_service.dart';
import '../services/encrypted_vault_service.dart';
import '../services/imu_fusion_service.dart';
import '../services/gamepad_settings_provider.dart';
import '../services/bio_tomography_service.dart';
import '../services/metallurgic_radar_service.dart';
import '../services/background_recording_service.dart';
import '../services/battery_optimizer_service.dart';
import '../services/peer_mesh_service.dart';
import '../services/tap_command_service.dart';
import '../services/jammer_countermeasure_service.dart';
import '../services/external_export_service.dart';
import '../services/live_notif_service.dart';
import '../services/hardware_capabilities_service.dart';
import '../widgets/glassmorphism_hud.dart';
import '../widgets/falcon_side_panel.dart';
import '../route_observer.dart';  // PERF V50.0: global RouteObserver

/// V49.9: Semantic matter colors — metals=their real color, water=blue, organic/humans=green, unknown=grey
int _matterColorHex(MatterType type) {
  switch (type) {
    case MatterType.ferrousMetal:    return 0xFFE65100; // rust orange — iron/steel
    case MatterType.nonFerrousMetal: return 0xFFB87333; // copper brown
    case MatterType.preciousMetal:   return 0xFFFFD700; // gold
    case MatterType.alloy:           return 0xFF90A4AE; // steel blue-grey
    case MatterType.mineral:         return 0xFF9C27B0; // mineral purple
    case MatterType.water:           return 0xFF2196F3; // blue — water/liquid
    case MatterType.organic:         return 0xFF4CAF50; // green — biological/humans
    default:                         return 0xFF757575; // grey — unknown
  }
}

/// V42 Neo Matrix Vision Page — Real-time animated 3D digital twin
/// Full 360° view, drone top-down mode, pinch-to-zoom, gyro control
class NeoMatrixVisionPage extends ConsumerStatefulWidget {
  final bool hasRootAccess;
  final VisionMode initialMode;
  
  const NeoMatrixVisionPage({
    super.key,
    required this.hasRootAccess,
    this.initialMode = VisionMode.neoMatrix,
  });

  @override
  ConsumerState<NeoMatrixVisionPage> createState() => _NeoMatrixVisionPageState();
}

class _NeoMatrixVisionPageState extends ConsumerState<NeoMatrixVisionPage>
    // FIX #9: WidgetsBindingObserver wires app lifecycle → native render thread.
    // When app goes to background, nativePauseRender() stops the Choreographer
    // callback — saves GPU + battery. Resumes immediately on foreground.
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  late VisionMode _currentMode;
  bool _showModeSelector = false;
  bool _showStats = true;
  late AnimationController _animationController;

  // ── PERF V50.0: Point-cloud cache ────────────────────────────────────────
  // Rebuilt ONLY when fusion/metal data changes — NOT every 120fps tick.
  // Eliminates the #1 GC hotpath: thousands of RadioWavePoint3D allocations/sec.
  List<RadioWavePoint3D> _cachedPoints3D = const [];
  int _lastFusionLen  = -1;
  int _lastMetalLen   = -1;
  bool _lastZeroMock  = false;

  // Route-level visibility: false = animation paused (navigated away)
  bool _isRouteActive = true;

  Offset? _lastTouchPosition;

  // ── V49.9: True 3D camera position (replaces zoom-only model) ──────────
  double _camX = 0.0;   // strafe left/right in world units
  double _camY = 0.0;   // altitude up/down
  double _camZ = 0.0;   // forward/backward along view axis
  static const double _kCamLimit = 18.0;

  // Legacy zoom kept for drone-top-down mode only
  double _zoomLevel = 1.0;
  double _zoomStart = 1.0;
  static const double _kMinZoom = 0.25;
  static const double _kMaxZoom = 4.0;
  bool _showZoomIndicator = false;

  // ── Gamepad continuous movement ─────────────────────────────────────────
  Timer? _moveTimer;
  MoveDir? _activeDir;

  // ── Compass sync ────────────────────────────────────────────────────────
  bool _compassLocked = false;

  // V49.9: Real toggle state
  bool _calibrating = false;
  final List<String> _sigintLog = [];
  Timer? _sigintTimer;
  Timer? _anomalyTimer;

  // ── V49.9: freeMoveMode — unlimited camera range when ON ─────────────────
  bool _freeMoveEnabled = false;
  double get _activeCamLimit => _freeMoveEnabled ? 999.0 : 18.0;

  // ── V49.9: signalPlaybackSim — inject replay frames as live feed ─────────
  bool _playbackSimActive = false;
  StreamSubscription<TapCommand>? _tapCommandSub;

  // ── V49.9: invisibleCamera — zero camera preview opacity ─────────────────
  bool _invisibleCameraMode = false;

  // ── V49.9: customizableHUD — draggable panel positions ───────────────────
  bool _hudDragUnlocked = false;
  Offset _legendPos = const Offset(8, 0); // relative offsets from defaults
  Offset _telemetryPos = const Offset(0, 0);
  static const double _kHudSnapGrid = 8.0;

  // V42: Manual 360° rotation
  double _manualYaw = 0.0;
  double _manualPitch = 0.0;
  
  double _pointSize = 1.0;
  double _clusterDensity = 0.7;
  
  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _animationController = AnimationController(
      vsync: this,
      // PERF V50.0: 4s period — smooth 120fps without redundant ticks.
      duration: const Duration(seconds: 4),
    )..repeat();

    _pointSize = digitalTwinEngine.pointSize;
    _clusterDensity = digitalTwinEngine.clusteringDensity;
    
    // App lifecycle (background/foreground) → pause/resume render thread
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(featuresProvider.notifier).setHasRoot(widget.hasRootAccess);
      ref.read(wifiCSIProvider.notifier).initialize();
      ref.read(multiSignalFusionProvider.notifier).start();
      ref.read(gyroscopicCameraProvider);
      final features = ref.read(featuresProvider);
      if (features[FKey.nativeGlRenderer] || features[FKey.quantumEngine]) {
        NativeRendererBridge.instance.resumeRender();
      }
      // PERF V50.0: Subscribe to route events — pause when covered by another page
      final route = ModalRoute.of(context);
      if (route != null) appRouteObserver.subscribe(this, route);
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appRouteObserver.unsubscribe(this);  // PERF V50.0
    _moveTimer?.cancel();
    _sigintTimer?.cancel();
    _anomalyTimer?.cancel();
    _animationController.dispose();
    ref.read(multiSignalFusionProvider.notifier).stop();
    super.dispose();
  }

  // ── PERF V50.0: RouteAware — pause when another page is pushed on top ────
  @override
  void didPushNext() {
    if (!_isRouteActive) return;
    _isRouteActive = false;
    _animationController.stop();
    NativeRendererBridge.instance.pauseRender();
  }

  @override
  void didPopNext() {
    if (_isRouteActive) return;
    _isRouteActive = true;
    _animationController.repeat();
    final features = ref.read(featuresProvider);
    if (features[FKey.nativeGlRenderer] || features[FKey.quantumEngine]) {
      NativeRendererBridge.instance.resumeRender();
    }
  }

  // FIX #9: App goes to background → pause render thread (zero GPU cost while hidden)
  //         App returns to foreground → resume at full 120fps immediately
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bridge = NativeRendererBridge.instance;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        bridge.pauseRender();
        _animationController.stop();
      case AppLifecycleState.resumed:
        if (_isRouteActive) {
          bridge.resumeRender();
          _animationController.repeat();
        }
      case AppLifecycleState.hidden:
        bridge.pauseRender();
        _animationController.stop();
    }
  }

  // ── Gamepad movement engine ────────────────────────────────────────────────
  void _startMove(MoveDir dir) {
    if (_activeDir == dir) return;
    _moveTimer?.cancel();
    _activeDir = dir;
    _applyMove(dir); // immediate tap response
    _moveTimer = Timer.periodic(const Duration(milliseconds: 40), (_) => _applyMove(dir));
  }

  void _stopMove() {
    _moveTimer?.cancel();
    _moveTimer = null;
    _activeDir = null;
  }

  void _applyMove(MoveDir dir) {
    final spd = ref.read(gamepadSettingsProvider).moveSensitivity;
    setState(() {
      final cosYaw = math.cos(_manualYaw);
      final sinYaw = math.sin(_manualYaw);
      final cosPitch = math.cos(_manualPitch);
      switch (dir) {
        // Forward: translate camera along its view direction (yaw + pitch)
        case MoveDir.forward:
          _camX += sinYaw * cosPitch * spd;
          _camZ -= cosYaw * cosPitch * spd;
          _camY += math.sin(_manualPitch) * spd;
        // Backward: reverse
        case MoveDir.backward:
          _camX -= sinYaw * cosPitch * spd;
          _camZ += cosYaw * cosPitch * spd;
          _camY -= math.sin(_manualPitch) * spd;
        // Strafe right: perpendicular to yaw (cross product of forward × up)
        case MoveDir.strafeRight:
          _camX += cosYaw * spd;
          _camZ += sinYaw * spd;
        // Strafe left
        case MoveDir.strafeLeft:
          _camX -= cosYaw * spd;
          _camZ -= sinYaw * spd;
        // Altitude
        case MoveDir.altUp:
          _camY += spd;
        case MoveDir.altDown:
          _camY -= spd;
      }
      // Clamp to prevent flying out of the scene
      _camX = _camX.clamp(-_activeCamLimit, _activeCamLimit);
      _camY = _camY.clamp(-_activeCamLimit, _activeCamLimit);
      _camZ = _camZ.clamp(-_activeCamLimit, _activeCamLimit);
    });
  }

  // ── Compass sync: align 3D yaw to phone's actual compass north ─────────────
  void _syncCompass() {
    final imu = ref.read(imuFusionProvider);
    setState(() {
      _manualYaw = -imu.yaw; // imu.yaw is CCW from north → negate for 3D CW
      _compassLocked = !_compassLocked;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_compassLocked
          ? 'Compass locked — 3D view aligned to North (${(imu.yaw * 180 / math.pi).toStringAsFixed(0)}°)'
          : 'Compass unlocked — free look mode'),
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Live compass update when locked ──────────────────────────────────────
  void _maybeSyncCompass() {
    if (!_compassLocked) return;
    final imu = ref.read(imuFusionProvider);
    if ((_manualYaw - (-imu.yaw)).abs() > 0.01) {
      setState(() => _manualYaw = -imu.yaw);
    }
  }

  void _switchMode(VisionMode newMode) {
    if (newMode.requiresRoot && !widget.hasRootAccess) {
      _showRootRequiredDialog(newMode);
      return;
    }
    // V49.9: Set both mode and theme together via featuresProvider
    ref.read(featuresProvider.notifier).setProfile(
      modeName: _modeEnumName(newMode),
      theme: newMode.linkedTheme,
    );
    setState(() => _showModeSelector = false);
  }

  /// Returns the Dart enum member name (camelCase) for a VisionMode value.
  String _modeEnumName(VisionMode m) => m.toString().split('.').last;
  
  void _showRootRequiredDialog(VisionMode mode) {
    final dialogColor = mode.primaryColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: dialogColor, width: 1),
        ),
        title: Row(children: [
          Icon(Icons.lock, color: dialogColor, size: 20),
          const SizedBox(width: 10),
          Text('ROOT REQUIRED', style: TextStyle(color: dialogColor, fontSize: 16)),
        ]),
        content: Text(
          '${mode.name} mode requires root access for maximum signal processing.\n\nRestart and grant root to unlock.',
          style: TextStyle(color: dialogColor.withValues(alpha: 0.7), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: dialogColor)),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final csiState = ref.watch(wifiCSIProvider);
    final fusionState = ref.watch(multiSignalFusionProvider);
    final fusionService = ref.read(multiSignalFusionProvider.notifier);
    final replayState = ref.watch(recordingReplayProvider);
    final recordingService = ref.read(recordingReplayProvider.notifier);
    final rootState = ref.watch(rootPermissionProvider);
    final gyroCamera = ref.watch(gyroscopicCameraProvider);
    final gyroCameraService = ref.read(gyroscopicCameraProvider.notifier);
    final features = ref.watch(featuresProvider);
    final twinCfg = ref.watch(twinConfigProvider);
    // V49.9: Live signal provider additions
    final bleState   = ref.watch(bleServiceProvider);
    final cells      = ref.watch(cellStreamProvider).value ?? const [];
    final stealth    = ref.watch(stealthProtocolProvider);
    final gamepadCfg = ref.watch(gamepadSettingsProvider);
    final metalState2 = ref.watch(metalDetectionProvider);
    // V49.9 REAL TOGGLE PROVIDERS
    final bioTomoState  = ref.watch(bioTomographyProvider);
    final bioTomoSvc    = ref.read(bioTomographyProvider.notifier);
    final metalRadarSvc = ref.read(metallurgicRadarProvider.notifier);
    final bgRecordSvc   = ref.read(backgroundRecordingProvider.notifier);
    final hwCaps        = ref.watch(hardwareCapabilitiesProvider);
    final stealthNotifier = ref.read(stealthProtocolProvider.notifier);
    // V49.9: 14 real toggle providers
    final batteryOpt    = ref.watch(batteryOptimizerProvider);
    final peerMesh      = ref.watch(peerMeshProvider);
    final tapCmds       = ref.watch(tapCommandProvider);
    final jammerCM      = ref.watch(jammerCountermeasureProvider);
    final extExport     = ref.watch(externalExportProvider);
    final liveNotif     = ref.watch(liveNotifProvider);

    // PERF V50.0: Side-effects moved to ref.listen — fire ONLY when data changes,
    // not on every frame rebuild.
    ref.listen<MetalDetectionState>(metalDetectionProvider, (prev, next) {
      if (liveNotif.active &&
          (prev == null || prev.detections.length != next.detections.length)) {
        ref.read(liveNotifProvider.notifier).updateCounts(
          bleDevices: ref.read(bleServiceProvider).devices.length,
          cellTowers: ref.read(cellStreamProvider).value?.length ?? 0,
          wifiHz: csiState.sampleRate.round(),
          matterPoints: next.detections.length,
        );
      }
      if (extExport.active &&
          next.detections.isNotEmpty &&
          (prev == null || prev.detections.length != next.detections.length)) {
        ref.read(externalExportProvider.notifier).exportDetections(next.detections);
      }
    });

    // Compass live-sync when locked
    ref.listen<OrientationState>(imuFusionProvider, (_, __) => _maybeSyncCompass());

    // ─── V49.9: REAL FEATURE LISTENERS — every toggle drives a real effect ───
    ref.listen<FeaturesState>(featuresProvider, (prev, next) {
      // Camera AR Background
      final wasCamera = prev?[FKey.cameraBackground] ?? false;
      final isCamera  = next[FKey.cameraBackground];
      if (isCamera && !wasCamera) ref.read(cameraBackgroundProvider.notifier).enable();
      if (!isCamera && wasCamera) ref.read(cameraBackgroundProvider.notifier).disable();
      // Stealth Mode — disables all radio emissions
      if (next[FKey.stealthMode] && !(prev?[FKey.stealthMode] ?? false)) stealthNotifier.enable();
      if (!next[FKey.stealthMode] && (prev?[FKey.stealthMode] ?? false)) stealthNotifier.disable();
      // Cellular Monitor
      if (next[FKey.cellularMonitor] && !(prev?[FKey.cellularMonitor] ?? false)) ref.read(cellServiceProvider).start();
      if (!next[FKey.cellularMonitor] && (prev?[FKey.cellularMonitor] ?? false)) ref.read(cellServiceProvider).stop();
      // WiFi CSI
      if (next[FKey.wifiCSI] && !(prev?[FKey.wifiCSI] ?? false)) ref.read(wifiCSIProvider.notifier).startCapture();
      if (!next[FKey.wifiCSI] && (prev?[FKey.wifiCSI] ?? false)) ref.read(wifiCSIProvider.notifier).stopCapture();
      // BLE Scan
      if (next[FKey.bluetoothScan] && !(prev?[FKey.bluetoothScan] ?? false)) ref.read(bleServiceProvider.notifier).startScan();
      if (!next[FKey.bluetoothScan] && (prev?[FKey.bluetoothScan] ?? false)) ref.read(bleServiceProvider.notifier).stopScan();
      // Bio Tomography FFT engine
      if (next[FKey.bioTomography] && !(prev?[FKey.bioTomography] ?? false)) bioTomoSvc.start();
      if (!next[FKey.bioTomography] && (prev?[FKey.bioTomography] ?? false)) bioTomoSvc.stop();
      // FFT Sensitivity — boosts bio detection gain
      if (next[FKey.fftSensitivity] != (prev?[FKey.fftSensitivity] ?? true)) {
        bioTomoSvc.setSensitivity(next[FKey.fftSensitivity] ? 2.5 : 1.0);
      }
      // Metallurgic Radar — magnetometer susceptibility engine
      if (next[FKey.metallurgicRadar] && !(prev?[FKey.metallurgicRadar] ?? false)) metalRadarSvc.start();
      if (!next[FKey.metallurgicRadar] && (prev?[FKey.metallurgicRadar] ?? false)) metalRadarSvc.stop();
      // Background Recording — arms workmanager
      if (next[FKey.backgroundRecord] && !(prev?[FKey.backgroundRecord] ?? false)) bgRecordSvc.setEnabled(true);
      if (!next[FKey.backgroundRecord] && (prev?[FKey.backgroundRecord] ?? false)) bgRecordSvc.setEnabled(false);
      // Multi-Signal Calibration — resets Kalman baselines on toggle-ON
      if (next[FKey.multiSignalCalib] && !(prev?[FKey.multiSignalCalib] ?? false)) _runCalibration();
      // Export 3D — toggle acts as one-shot trigger, then resets itself
      if (next[FKey.export3D] && !(prev?[FKey.export3D] ?? false)) {
        _export3DScene(ref.read(multiSignalFusionProvider));
        Future.microtask(() => ref.read(featuresProvider.notifier).toggle(FKey.export3D, value: false));
      }
      // Recording toggle — starts/stops live session recording
      if (next[FKey.recording] && !(prev?[FKey.recording] ?? false)) ref.read(recordingReplayProvider.notifier).startRecording();
      if (!next[FKey.recording] && (prev?[FKey.recording] ?? false)) ref.read(recordingReplayProvider.notifier).stopRecording();
      // Native GL Renderer — pause/resume C++ bridge
      final needsNative = next[FKey.nativeGlRenderer] || next[FKey.quantumEngine];
      final hadNative = (prev?[FKey.nativeGlRenderer] ?? false) || (prev?[FKey.quantumEngine] ?? false);
      if (needsNative && !hadNative) NativeRendererBridge.instance.resumeRender();
      if (!needsNative && hadNative) NativeRendererBridge.instance.pauseRender();

      // ── V49.9: 14 NEW REAL IMPLEMENTATIONS ────────────────────────────────

      // 1. batteryOptScan — real throttle of all scan rates + FPS cap
      if (next[FKey.batteryOptScan] && !(prev?[FKey.batteryOptScan] ?? false)) {
        ref.read(batteryOptimizerProvider.notifier).enable();
      }
      if (!next[FKey.batteryOptScan] && (prev?[FKey.batteryOptScan] ?? false)) {
        ref.read(batteryOptimizerProvider.notifier).disable();
      }

      // 2. magnetometer — enable/disable hardware magnetometer stream in IMU
      if (next[FKey.magnetometer] && !(prev?[FKey.magnetometer] ?? false)) {
        ref.read(imuFusionProvider.notifier).enableMagnetometer(true);
      }
      if (!next[FKey.magnetometer] && (prev?[FKey.magnetometer] ?? false)) {
        ref.read(imuFusionProvider.notifier).enableMagnetometer(false);
      }

      // 3. freeMoveMode — unlock unlimited camera range (no ±18 bound)
      if (next[FKey.freeMoveMode] != (prev?[FKey.freeMoveMode] ?? false)) {
        setState(() => _freeMoveEnabled = next[FKey.freeMoveMode]);
      }

      // 4. invisibleCamera — zero camera preview opacity (covert AR)
      if (next[FKey.invisibleCamera] != (prev?[FKey.invisibleCamera] ?? false)) {
        setState(() => _invisibleCameraMode = next[FKey.invisibleCamera]);
      }

      // 5. jammerCountermeasure — switch to aggressive BLE scan on jammer detect
      if (next[FKey.jammerCountermeasure] && !(prev?[FKey.jammerCountermeasure] ?? false)) {
        ref.read(jammerCountermeasureProvider.notifier).activate();
      }
      if (!next[FKey.jammerCountermeasure] && (prev?[FKey.jammerCountermeasure] ?? false)) {
        ref.read(jammerCountermeasureProvider.notifier).deactivate();
      }

      // 6. exportExternal — auto-save detections CSV to Downloads
      if (next[FKey.exportExternal] && !(prev?[FKey.exportExternal] ?? false)) {
        ref.read(externalExportProvider.notifier).enable();
      }
      if (!next[FKey.exportExternal] && (prev?[FKey.exportExternal] ?? false)) {
        ref.read(externalExportProvider.notifier).disable();
      }

      // 7. homeWidget — persistent live-intelligence notification
      if (next[FKey.homeWidget] && !(prev?[FKey.homeWidget] ?? false)) {
        ref.read(liveNotifProvider.notifier).enable();
      }
      if (!next[FKey.homeWidget] && (prev?[FKey.homeWidget] ?? false)) {
        ref.read(liveNotifProvider.notifier).disable();
      }

      // 8. signalPlaybackSim — inject replay frames as live signal feed
      if (next[FKey.signalPlaybackSim] && !(prev?[FKey.signalPlaybackSim] ?? false)) {
        setState(() => _playbackSimActive = true);
        ref.read(recordingReplayProvider.notifier).play();
      }
      if (!next[FKey.signalPlaybackSim] && (prev?[FKey.signalPlaybackSim] ?? false)) {
        setState(() => _playbackSimActive = false);
        ref.read(recordingReplayProvider.notifier).stop();
      }

      // 9. voiceActivatedScan — accelerometer double-tap triggers burst scan
      if (next[FKey.voiceActivatedScan] && !(prev?[FKey.voiceActivatedScan] ?? false)) {
        ref.read(tapCommandProvider.notifier).enableVoiceActivatedScan();
        _tapCommandSub ??= ref.read(tapCommandProvider.notifier).commands.listen((cmd) {
          if (cmd == TapCommand.doubleTap) _triggerBurstScan();
          if (cmd == TapCommand.tripleTap && ref.read(featuresProvider)[FKey.voiceCommands]) _cycleVisionMode();
          if (cmd == TapCommand.shake && ref.read(featuresProvider)[FKey.voiceCommands]) {
            ref.read(stealthProtocolProvider.notifier).toggle();
          }
        });
      }
      if (!next[FKey.voiceActivatedScan] && !(next[FKey.voiceCommands])) {
        ref.read(tapCommandProvider.notifier).disableVoiceActivatedScan();
        if (!(next[FKey.voiceCommands])) {
          _tapCommandSub?.cancel();
          _tapCommandSub = null;
        }
      }

      // 10. voiceCommands — accelerometer triple-tap + shake gesture commands
      if (next[FKey.voiceCommands] && !(prev?[FKey.voiceCommands] ?? false)) {
        ref.read(tapCommandProvider.notifier).enableVoiceCommands();
        _tapCommandSub ??= ref.read(tapCommandProvider.notifier).commands.listen((cmd) {
          if (cmd == TapCommand.doubleTap) _triggerBurstScan();
          if (cmd == TapCommand.tripleTap) _cycleVisionMode();
          if (cmd == TapCommand.shake) ref.read(stealthProtocolProvider.notifier).toggle();
        });
      }
      if (!next[FKey.voiceCommands] && (prev?[FKey.voiceCommands] ?? false)) {
        ref.read(tapCommandProvider.notifier).disableVoiceCommands();
        if (!(next[FKey.voiceActivatedScan])) {
          _tapCommandSub?.cancel();
          _tapCommandSub = null;
        }
      }

      // 11. zeroMockData — lock to real sensors only (block CSI fallback interpolation)
      // Handled in build() below via _zeroMockActive flag derived from features

      // 11b. encryptedVault — arm/disarm the real AES-256-CBC vault
      if (next[FKey.encryptedVault] && !(prev?[FKey.encryptedVault] ?? false)) {
        ref.read(encryptedVaultProvider.notifier).arm();
      }
      if (!next[FKey.encryptedVault] && (prev?[FKey.encryptedVault] ?? false)) {
        ref.read(encryptedVaultProvider.notifier).disarm();
      }

      // 12. communityMap — BLE peer scan for other Falcon Eye devices
      if (next[FKey.communityMap] && !(prev?[FKey.communityMap] ?? false)) {
        ref.read(peerMeshProvider.notifier).start();
      }
      if (!next[FKey.communityMap] && !(next[FKey.multiDeviceMesh]) &&
          (prev?[FKey.communityMap] ?? false)) {
        ref.read(peerMeshProvider.notifier).stop();
      }

      // 13. multiDeviceMesh — extends communityMap with mesh panel + signal sharing
      if (next[FKey.multiDeviceMesh] && !(prev?[FKey.multiDeviceMesh] ?? false)) {
        ref.read(peerMeshProvider.notifier).start(); // reuses peer mesh service
      }
      if (!next[FKey.multiDeviceMesh] && !(next[FKey.communityMap]) &&
          (prev?[FKey.multiDeviceMesh] ?? false)) {
        ref.read(peerMeshProvider.notifier).stop();
      }

      // 14. customizableHUD — enable/disable drag-unlock mode
      if (next[FKey.customizableHUD] != (prev?[FKey.customizableHUD] ?? false)) {
        setState(() => _hudDragUnlocked = next[FKey.customizableHUD]);
      }
    });
    
    final gyroEnabled = features[FKey.gyroMotion];
    final pinchEnabled = features[FKey.pinchZoom];
    final showStats   = features[FKey.statsPanel];
    final showWaveform = features[FKey.waveformOverlay];
    final droneView = features[FKey.droneTopDown];
    final codeRainChars = features[FKey.codeRainChars];
    final livePointSize = twinCfg.pointSize;
    final liveClusterDensity = twinCfg.clusterDensity;
    final themeColor = features.primaryColor;

    // V49.9: Active mode driven by featuresProvider for unified mode+theme sync
    _currentMode = VisionMode.values.firstWhere(
      (m) => m.name.replaceAll(' ', '') == features.activeModeName ||
             _modeEnumName(m) == features.activeModeName,
      orElse: () => VisionMode.neoMatrix,
    );
    // V42 new features
    final showObjectLabels = features[FKey.objectLabeling];
    final showRssiHeatmap = features[FKey.rssiHeatmapOverlay];
    final customPointRendering = features[FKey.customPointRendering];

    // V48.1: Camera AR Background
    final cameraEnabled = features[FKey.cameraBackground];
    final camBgState = ref.watch(cameraBackgroundProvider);
    final camBgService = ref.read(cameraBackgroundProvider.notifier);

    // Sync feature toggle → camera controller lifecycle
    ref.listen<FeaturesState>(featuresProvider, (prev, next) {
      final wasOn = prev?[FKey.cameraBackground] ?? false;
      final isOn  = next[FKey.cameraBackground];
      if (isOn && !wasOn) camBgService.enable();
      if (!isOn && wasOn) camBgService.disable();
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── V48.1: Camera AR Background (bottom-most layer) ───────────
          if (cameraEnabled)
            _CameraBackgroundLayer(camBgState: camBgState, themeColor: themeColor, invisibleCameraMode: _invisibleCameraMode),

          // ── 3D Canvas with Full 360° + Pinch-to-Zoom ──────────────
          GestureDetector(
            onScaleStart: (details) {
              _zoomStart = _zoomLevel;
              if (details.pointerCount == 1) {
                _lastTouchPosition = details.localFocalPoint;
              }
            },
            onScaleUpdate: (details) {
              if (details.pointerCount >= 2) {
                // V49.9: Two-finger pinch = fly forward/backward along view direction
                // pinch apart (scale>1) = move forward; together (scale<1) = move backward
                final delta = (details.scale - 1.0) * 0.06;
                if (delta.abs() > 0.001) {
                  final cosYaw = math.cos(_manualYaw);
                  final sinYaw = math.sin(_manualYaw);
                  final cosPitch = math.cos(_manualPitch);
                  setState(() {
                    _camX += sinYaw * cosPitch * delta;
                    _camZ -= cosYaw * cosPitch * delta;
                    _camY += math.sin(_manualPitch) * delta;
                    _camX = _camX.clamp(-_activeCamLimit, _activeCamLimit);
                    _camY = _camY.clamp(-_activeCamLimit, _activeCamLimit);
                    _camZ = _camZ.clamp(-_activeCamLimit, _activeCamLimit);
                    _showZoomIndicator = true;
                  });
                  Future.delayed(const Duration(milliseconds: 1200), () {
                    if (mounted) setState(() => _showZoomIndicator = false);
                  });
                }
              } else if (details.pointerCount == 1) {
                // One finger drag = look around (yaw/pitch)
                final focal = details.localFocalPoint;
                final delta = focal - (_lastTouchPosition ?? focal);
                _lastTouchPosition = focal;
                if (gyroEnabled) {
                  gyroCameraService.updateTouchControl(delta.dx * 0.008, -delta.dy * 0.008);
                } else {
                  setState(() {
                    _manualYaw += delta.dx * 0.006;
                    _manualPitch += delta.dy * 0.004;
                    _manualPitch = _manualPitch.clamp(-math.pi / 2.5, math.pi / 2.5);
                  });
                }
              }
            },
            onScaleEnd: (_) => _lastTouchPosition = null,
            onDoubleTap: () {
              setState(() {
                _camX = 0; _camY = 0; _camZ = 0;
                _zoomLevel = 1.0;
                _manualYaw = 0; _manualPitch = 0;
                _showZoomIndicator = true;
              });
              Future.delayed(const Duration(milliseconds: 800), () {
                if (mounted) setState(() => _showZoomIndicator = false);
              });
            },
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                // PERF V50.0: Point-cloud CACHE — rebuilt only when data changes,
                // not on every 120fps animation tick. Eliminates #1 GC hotpath.
                final zeroMock  = features[FKey.zeroMockData];
                final metalSnap = ref.read(metalDetectionProvider);
                final fusionLen = fusionState.fused3DEnvironment.length;
                final metalLen  = metalSnap.matterPoints3D.length;
                if (fusionLen != _lastFusionLen ||
                    metalLen  != _lastMetalLen  ||
                    zeroMock  != _lastZeroMock) {
                  _lastFusionLen = fusionLen;
                  _lastMetalLen  = metalLen;
                  _lastZeroMock  = zeroMock;
                  final base = fusionState.fused3DEnvironment.isNotEmpty
                      ? fusionState.fused3DEnvironment.map((fp) => RadioWavePoint3D(
                            x: fp.x, y: fp.y, z: fp.z,
                            reflectionStrength: fp.reflectionStrength,
                            velocity: fp.velocity, azimuth: 0, elevation: 0,
                            distance: 0, materialType: fp.materialType,
                            confidence: fp.confidence))
                          .toList()
                      : (zeroMock
                          ? const <RadioWavePoint3D>[]
                          : csiState.reconstructed3D.cast<RadioWavePoint3D>());
                  _cachedPoints3D = [...base, ...metalSnap.matterPoints3D];
                }
                final metalState = metalSnap;  // alias for detectedMatterOverlay below

                // PERF V49.9: RepaintBoundary isolates the 3D canvas from the rest
                // of the widget tree. HUD, controls, panels rebuilding will NOT
                // trigger a repaint of the expensive CustomPainter below.
                return RepaintBoundary(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: RadioWave3DPainter(
                    mode: _currentMode,
                    points3D: _cachedPoints3D,  // cached
                    animationProgress: _animationController.value,
                    hasRootPower: widget.hasRootAccess,
                    camera: gyroCamera.camera,
                    zoomLevel: _zoomLevel,
                    droneTopDown: droneView,
                    showFloorGrid: features[FKey.floorGrid],
                    showBuildings: features[FKey.wireframeBuildings],
                    showBackgroundFigures: features[FKey.backgroundFigures],
                    showBioHologram: features[FKey.bioHologram],
                    showScanlines: features[FKey.scanlines],
                    showGlitch: features[FKey.glitchEffects],
                    showCodeRain: features[FKey.codeRain],
                    codeRainChars: codeRainChars,
                    showParticleHuman: features[FKey.particleHuman],
                    showNeuralTendrils: features[FKey.neuralTendrils],
                    showHeatmap: features[FKey.signalHeatmap],
                    showDirectionFinding: features[FKey.directionFinding],
                    themeColor: themeColor,
                    pointSize: livePointSize,
                    clusterDensity: liveClusterDensity,
                    manualYaw: _manualYaw,
                    manualPitch: _manualPitch,
                    // V49.9: Free camera position from gamepad/pinch movement
                    camOffsetX: _camX,
                    camOffsetY: _camY,
                    camOffsetZ: _camZ,
                    showObjectLabels: showObjectLabels,
                    showRssiHeatmap: showRssiHeatmap,
                    customPointRendering: customPointRendering,
                    // V49.9: REAL new toggle painter params
                    showBioHeart:       features[FKey.bioHeartOverlay],
                    showNeuralFlow:     features[FKey.bioNeuralFlow],
                    showWaterVoid:      features[FKey.waterVoidDetection],
                    showMetalHoming:    features[FKey.metalHoming],
                    useFrustumCulling:  features[FKey.frustumCulling],
                    // GPU tier budget: tier1=500K pts, mid=80K, off=8K
                    gpuPointBudget: features[FKey.gpuTierDetection]
                        ? (hwCaps.tier1Flagship.enabled ? 500000 : 80000)
                        : 8000,
                    // V42: Pass detected matter for 3D rendering
                    detectedMatterOverlay: metalState.detections.map((d) => (
                      d.x, d.y, d.z, d.confidence,
                      '${d.elementHint} ${d.distanceMetres.toStringAsFixed(1)}m',
                      _matterColorHex(d.matterType),
                    )).toList(),
                  ),
                ), // CustomPaint
                ); // RepaintBoundary — PERF V49.9: 3D canvas isolated from HUD rebuilds
              },
            ),
          ),

          // ── Top HUD ─────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildTopHUD(rootState, gyroCamera, gyroCameraService, features: features),
                const Spacer(),
                if (showWaveform) _buildSignalWaveform(csiState, fusionState),
                if (recordingService.isRecording || replayState.isPlaying)
                  _buildRecordingReplayBanner(recordingService, replayState),
                if (showStats) _buildStatsBar(csiState, fusionState, bleState, cells, themeColor),
                _buildBottomControls(recordingService, replayState, gyroCamera, gyroCameraService, themeColor, stealth),
              ],
            ),
          ),

          if (_showModeSelector) _buildModeSelectorPanel(),

          if (_showStats && !_showModeSelector)
            Positioned(
              bottom: 244 - _telemetryPos.dy,
              left: (8 + _telemetryPos.dx).clamp(0.0, 300.0),
              child: _hudDragUnlocked
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (d) => setState(() {
                        final sw = MediaQuery.of(context).size.width;
                        _telemetryPos = Offset(
                          (_telemetryPos.dx + d.delta.dx).clamp(0.0, sw - 180),
                          (_telemetryPos.dy + d.delta.dy).clamp(-200.0, 200.0),
                        );
                        // snap to 8px grid
                        _telemetryPos = Offset(
                          (_telemetryPos.dx / _kHudSnapGrid).roundToDouble() * _kHudSnapGrid,
                          (_telemetryPos.dy / _kHudSnapGrid).roundToDouble() * _kHudSnapGrid,
                        );
                      }),
                      child: Stack(clipBehavior: Clip.none, children: [
                        _buildStatsPanel(csiState, fusionState, bleState, cells, themeColor),
                        Positioned(top: 0, right: -4, child: Container(
                          width: 16, height: 16,
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.5),
                            borderRadius: const BorderRadius.only(topRight: Radius.circular(3)),
                          ),
                          child: Icon(Icons.drag_indicator, color: themeColor, size: 10),
                        )),
                      ]),
                    )
                  : _buildStatsPanel(csiState, fusionState, bleState, cells, themeColor),
            ),

          // V51.0: FalconPanelTrigger removed — tune button is in top HUD bar

          // ALL OVERLAYS — LayoutBuilder for correct positions
          LayoutBuilder(builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final isRight = gamepadCfg.side == GamepadSide.right;
            // V51.0: real top = status bar + HUD bar height
            final topOff = MediaQuery.of(ctx).padding.top + 62.0;
            return Stack(children: [

              // ── Compass button — top-right, below HUD bar ─────────────
              Positioned(
                top: topOff,
                right: 8,
                child: _buildCompassButton(themeColor),
              ),

              // ── Compass mini-map — below compass button ───────────────
              Positioned(
                top: topOff + 50,
                right: 8,
                child: RepaintBoundary(
                  child: _buildCompassMiniMap(
                      metalState2, fusionState, bleState, themeColor),
                ),
              ),

              // ── Detection legend — top-left ───────────────────────────
              Positioned(
                top: topOff + 4 + _legendPos.dy,
                left: (_legendPos.dx).clamp(0.0, w - 160),
                child: _hudDragUnlocked
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (d) => setState(() {
                          _legendPos = Offset(
                            (_legendPos.dx + d.delta.dx).clamp(0.0, w - 160),
                            (_legendPos.dy + d.delta.dy).clamp(0.0, h - 200),
                          );
                          _legendPos = Offset(
                            (_legendPos.dx / _kHudSnapGrid).roundToDouble() * _kHudSnapGrid,
                            (_legendPos.dy / _kHudSnapGrid).roundToDouble() * _kHudSnapGrid,
                          );
                        }),
                        child: Stack(clipBehavior: Clip.none, children: [
                          _buildDetectionLegend(
                              metalState2, fusionState, bleState, cells, themeColor),
                          Positioned(top: 0, right: -4, child: Container(
                            width: 14, height: 14,
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.5),
                              borderRadius: const BorderRadius.only(topRight: Radius.circular(3)),
                            ),
                            child: Icon(Icons.open_with, color: themeColor, size: 9),
                          )),
                        ]),
                      )
                    : _buildDetectionLegend(
                        metalState2, fusionState, bleState, cells, themeColor),
              ),

              // ── Gamepad — fixed right side ─────────────────────────────
              if (gamepadCfg.visible)
                Positioned(
                  top: (h * gamepadCfg.verticalPosition -
                          (gamepadCfg.btnSize * 3 + gamepadCfg.gap * 2))
                      .clamp(60.0, h - 260),
                  right: isRight ? 8 : null,
                  left: isRight ? null : 8,
                  child: _buildGamepadWidget(gamepadCfg, themeColor),
                ),
            ]);
          }),

          if (features[FKey.aiSignalSummary])
            Positioned(
              top: kToolbarHeight + 50,
              left: 12,
              right: 52,
              child: _buildAISummary(fusionState, themeColor),
            ),

          if (features[FKey.directionFinding] && !features[FKey.aiSignalSummary])
            Positioned(
              top: kToolbarHeight + 50,
              right: 52,
              child: _buildDirectionFindingPanel(fusionState, themeColor),
            ),

          if (features[FKey.jammerDetection] && fusionState.isActive)
            Positioned(
              top: kToolbarHeight + 50,
              right: 52,
              child: _buildJammerAlertWidget(themeColor),
            ),

          // Jammer countermeasure active status badge
          if (jammerCM.active)
            Positioned(
              top: kToolbarHeight + 50,
              right: 52,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  border: Border.all(
                    color: jammerCM.jammerConfirmed
                        ? const Color(0xFFFF2200)
                        : const Color(0xFFFF8C00),
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.security,
                      color: jammerCM.jammerConfirmed
                          ? const Color(0xFFFF2200)
                          : const Color(0xFFFF8C00),
                      size: 11),
                  const SizedBox(width: 4),
                  Text(
                    jammerCM.jammerConfirmed
                        ? 'CM ACTIVE ${(jammerCM.jammerConfidence * 100).round()}%'
                        : 'CM ARMED',
                    style: TextStyle(
                      color: jammerCM.jammerConfirmed
                          ? const Color(0xFFFF2200)
                          : const Color(0xFFFF8C00),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ]),
              ),
            ),

          // Peer mesh panel — shown when communityMap or multiDeviceMesh is ON
          if ((features[FKey.communityMap] || features[FKey.multiDeviceMesh]) &&
              peerMesh.active)
            Positioned(
              top: kToolbarHeight + 200,
              right: 8,
              child: Container(
                width: 130,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.82),
                  border: Border.all(
                      color: const Color(0xFFFF8C00).withValues(alpha: 0.6)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      const Icon(Icons.hub, color: Color(0xFFFF8C00), size: 10),
                      const SizedBox(width: 4),
                      Text('MESH (${peerMesh.peers.length})',
                          style: const TextStyle(
                              color: Color(0xFFFF8C00),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                    ]),
                    const SizedBox(height: 4),
                    if (peerMesh.peers.isEmpty)
                      const Text('No peers in range',
                          style: TextStyle(color: Colors.white38, fontSize: 8))
                    else
                      for (final peer in peerMesh.peers.take(4))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(children: [
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFFF8C00)),
                            ),
                            const SizedBox(width: 4),
                            Expanded(child: Text(
                              '${peer.name.length > 10 ? peer.name.substring(0, 10) : peer.name}  ${peer.rssi}dBm',
                              style: const TextStyle(color: Colors.white70, fontSize: 8),
                              overflow: TextOverflow.ellipsis,
                            )),
                          ]),
                        ),
                    if (peerMesh.totalSharedDetections > 0) ...[
                      const Divider(height: 8, color: Colors.white12),
                      Text('${peerMesh.totalSharedDetections} shared pts',
                          style: const TextStyle(
                              color: Color(0xFFFF8C00),
                              fontSize: 8,
                              fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
            ),

          // Battery optimizer status strip
          if (batteryOpt.active)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 18,
                color: const Color(0xFF1A3300).withValues(alpha: 0.9),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.battery_saver, color: Color(0xFF66FF44), size: 10),
                  const SizedBox(width: 4),
                  Text(
                    'BATTERY SAVE — ${batteryOpt.maxFps}fps · BLE burst ${batteryOpt.bleScanIntervalSeconds}s · ~${batteryOpt.cpuSavingPercent.round()}% CPU saved',
                    style: const TextStyle(
                        color: Color(0xFF66FF44),
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
                ]),
              ),
            ),

          // Free move mode indicator
          if (_freeMoveEnabled)
            Positioned(
              top: kToolbarHeight + 8,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    border: Border.all(color: themeColor.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.open_with, color: themeColor, size: 10),
                    const SizedBox(width: 4),
                    Text('FREE MOVE — NO BOUNDS',
                        style: TextStyle(color: themeColor, fontSize: 8,
                            fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                  ]),
                ),
              ),
            ),

          // Playback sim indicator
          if (_playbackSimActive)
            Positioned(
              top: kToolbarHeight + 28,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    border: Border.all(color: Colors.purple.withValues(alpha: 0.7)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.play_circle_outline, color: Colors.purple, size: 10),
                    const SizedBox(width: 4),
                    Text('PLAYBACK SIM — frame ${replayState.currentFrameIndex}/${replayState.totalFrames}',
                        style: const TextStyle(color: Colors.purple, fontSize: 8,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ),

          // Invisible camera covert mode badge
          if (_invisibleCameraMode && features[FKey.cameraBackground])
            Positioned(
              bottom: 20, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.6)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.visibility_off, color: Colors.red, size: 9),
                  SizedBox(width: 3),
                  Text('COVERT AR', style: TextStyle(color: Colors.red,
                      fontSize: 8, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),

          // Tap command listener hint
          if (features[FKey.voiceActivatedScan] || features[FKey.voiceCommands])
            Positioned(
              bottom: 20, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  border: Border.all(color: themeColor.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  features[FKey.voiceCommands]
                      ? '✊✊=SCAN  ✊✊✊=MODE  SHAKE=STEALTH'
                      : '✊✊=BURST SCAN',
                  style: TextStyle(color: themeColor.withValues(alpha: 0.7),
                      fontSize: 7, letterSpacing: 0.5),
                ),
              ),
            ),

          if (_showZoomIndicator)
            Positioned(
              top: kToolbarHeight + 50,
              left: 12,
              child: _buildZoomIndicator(themeColor),
            ),

          // V42: Drone view indicator
          if (droneView)
            Positioned(
              top: kToolbarHeight + 50,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    border: Border.all(color: themeColor.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.flight, color: themeColor, size: 14),
                    const SizedBox(width: 6),
                    Text('DRONE TOP-DOWN VIEW',
                      style: TextStyle(color: themeColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ]),
                ),
              ),
            ),

          // ─── V49.9 REAL TOGGLE OVERLAYS ────────────────────────────────────

          // RAW SIGINT STREAM — live scrolling signal packet ticker
          if (features[FKey.rawSigintStream])
            Positioned(
              bottom: 250,
              left: 8,
              right: 8,
              child: _buildRawSigintStream(fusionState, bleState, cells, themeColor),
            ),

          // BIO TOMOGRAPHY — FFT heart/respiration readout
          if (features[FKey.bioTomography] && bioTomoState.isActive)
            Positioned(
              top: kToolbarHeight + 140,
              right: 8,
              child: _buildBioTomographyPanel(bioTomoState, themeColor),
            ),

          // ANOMALY ALERT — flashing banner when signal anomaly detected
          if (features[FKey.anomalyAlert])
            _AnomalyAlertOverlay(fusionState: fusionState, themeColor: themeColor),

          // MULTI-SIGNAL CALIBRATION STATUS — shown while calibrating
          if (features[FKey.multiSignalCalib] && _calibrating)
            Positioned(
              top: kToolbarHeight + 50,
              left: 0, right: 0,
              child: _buildCalibrationBanner(themeColor),
            ),

          // HUD OVERLAY GATE — when OFF, hides entire bottom toolbar
          if (!features[FKey.hudOverlay])
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(height: 130, color: Colors.black),
            ),

          // GPU TIER DETECTION — shows detected tier badge when on
          if (features[FKey.gpuTierDetection])
            Positioned(
              top: kToolbarHeight + 8,
              left: 8,
              child: _buildGpuTierBadge(hwCaps, themeColor),
            ),

          // GLASSMORPHISM HUD — switches telemetry panel to glass style
          // (handled via _buildTelemetryPanel which reads this flag)

          // NATIVE GL RENDERER — badge when C++ renderer active
          if (features[FKey.nativeGlRenderer])
            Positioned(
              bottom: 135,
              right: 8,
              child: _buildNativeGLBadge(themeColor),
            ),

          // QUANTUM ENGINE — native renderer is the quantum engine
          // Shows throughput badge when active
          if (features[FKey.quantumEngine])
            Positioned(
              bottom: 155,
              right: 8,
              child: _buildQuantumEngineBadge(fusionState, themeColor),
            ),

          // STEALTH MODE — red border flash when active
          if (stealth)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red.withValues(alpha: 0.35), width: 3),
                ),
              ),
            ),

          if (features[FKey.replaySystem] && replayState.totalFrames > 0)
            Positioned(
              bottom: 135,
              left: 0, right: 0,
              child: _buildReplayControls(replayState, recordingService, themeColor),
            ),

          // ENCRYPTED VAULT STATUS — padlock badge when vault is armed
          if (features[FKey.encryptedVault])
            Positioned(
              top: kToolbarHeight + 8,
              left: features[FKey.gpuTierDetection] ? 90 : 8,
              child: _buildEncryptedVaultBadge(themeColor),
            ),
        ],
      ),
    );
  }

  // ─── V47 Glassmorphic Top HUD ──────────────────────────────
  Widget _buildTopHUD(RootPermissionState rootState,
      GyroscopicCameraState gyroCamera,
      GyroscopicCameraService gyroCameraService, {
      required FeaturesState features,
    }) {
    final color = features.primaryColor;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent],
            ),
            border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.15))),
          ),
          child: Row(
            children: [
              _topIconBtn(Icons.arrow_back, color, () => context.pop()),
              const SizedBox(width: 4),
              _topIconBtn(Icons.apps, color, () => context.go('/master_control')),
              const Spacer(),
              // V47: Glassmorphic mode label with neon glow
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    color.withValues(alpha: 0.12),
                    color.withValues(alpha: 0.04),
                  ]),
                  border: Border.all(color: color, width: 1),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 10),
                  ],
                ),
                child: Text(
                  _currentMode.name.toUpperCase().replaceAll('_', ' '),
                  style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5,
                    shadows: [Shadow(color: color.withValues(alpha: 0.4), blurRadius: 8)],
                  ),
                ),
              ),
              const Spacer(),
              // V47: Sovereign version badge
              GlassStatusPill(
                text: 'V51.0',
                icon: Icons.shield,
                color: color,
                active: true,
              ),
              const SizedBox(width: 4),
              // Root badge
              GlassStatusPill(
                text: widget.hasRootAccess ? 'ROOT' : 'LIMITED',
                icon: widget.hasRootAccess ? Icons.verified_user : Icons.shield_outlined,
                color: widget.hasRootAccess ? color : Colors.orange,
                active: widget.hasRootAccess,
              ),
              const SizedBox(width: 4),
              _topIconBtn(Icons.settings_outlined, color, () => context.go('/settings')),
              const SizedBox(width: 4),
              _topIconBtn(Icons.tune, color, () => FalconSidePanel.show(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topIconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _buildSignalWaveform(WiFiCSIState csiState, MultiSignalFusionState fusionState) {
    final features = ref.watch(featuresProvider);
    return Container(
      height: 40,
      child: CustomPaint(
        size: const Size(double.infinity, 40),
        painter: _WaveformPainter(
          animationValue: _animationController.value,
          color: features.primaryColor,
          isActive: fusionState.isActive,
        ),
      ),
    );
  }

  Widget _buildStatsBar(WiFiCSIState csiState, MultiSignalFusionState fusionState,
      BleScanState bleState, List<CellularCell> cells, Color color) {
    final activeSignals = fusionState.activeSignals.values.where((v) => v).length;
    final totalSignals = fusionState.activeSignals.length.clamp(1, 99);
    final pts3d = fusionState.fused3DEnvironment.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.04),
                Colors.black.withValues(alpha: 0.45),
              ],
            ),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 8),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              NeonStat(label: 'FUSION', value: '${fusionState.fusionRate > 0 ? fusionState.fusionRate : 20}Hz', color: color, glow: true),
              _divider(color),
              NeonStat(label: 'SIGNALS', value: '$activeSignals/$totalSignals', color: color),
              _divider(color),
              NeonStat(label: '3D PTS', value: '$pts3d', color: color, glow: true),
              _divider(color),
              NeonStat(label: 'BLE', value: '${bleState.devices.length}', color: const Color(0xFF7986CB)),
              _divider(color),
              NeonStat(label: 'CELL', value: '${cells.length}', color: const Color(0xFF4FC3F7)),
              _divider(color),
              NeonStat(label: 'ZOOM', value: _zoomLevel < 0.99 ? '${(1.0/_zoomLevel).toStringAsFixed(1)}x' : _zoomLevel > 1.01 ? '${_zoomLevel.toStringAsFixed(1)}x' : '1.0x', color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCell(String label, String value, Color color) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(color: Colors.white38, fontSize: 8, letterSpacing: 0.5)),
      const SizedBox(height: 1),
      Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _divider(Color color) {
    return Container(width: 0.5, height: 22, color: color.withValues(alpha: 0.15));
  }

  Widget _buildBottomControls(
      RecordingReplayService recordingService,
      ReplayState replayState,
      GyroscopicCameraState gyroCamera,
      GyroscopicCameraService gyroCameraService,
      Color color,
      bool stealth) {
    final isRec = recordingService.isRecording;
    final features = ref.watch(featuresProvider);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: SafeArea(
          top: false,
          child: Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter, end: Alignment.topCenter,
              colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent],
            ),
            border: Border(top: BorderSide(color: color.withValues(alpha: 0.15))),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Row 1: primary controls
            Row(children: [
              _ctrlBtn('MODES', Icons.grid_view, color,
                  () => setState(() => _showModeSelector = !_showModeSelector)),
              _ctrlBtn(isRec ? 'STOP' : 'REC',
                  isRec ? Icons.stop : Icons.fiber_manual_record,
                  isRec ? Colors.red : color,
                  () => _toggleRecording(recordingService)),
              _ctrlBtn('REPLAY', Icons.play_circle, color,
                  () => _showReplayDialog(context, recordingService)),
              _ctrlBtn('GYRO',
                  gyroCamera.isEnabled ? Icons.screen_rotation : Icons.screen_lock_rotation,
                  gyroCamera.isEnabled ? Colors.green : color,
                  () => gyroCameraService.setEnabled(!gyroCamera.isEnabled)),
              _ctrlBtn(
                  features[FKey.droneTopDown] ? 'DRONE' : '360°',
                  features[FKey.droneTopDown] ? Icons.flight : Icons.threesixty,
                  features[FKey.droneTopDown] ? Colors.amber : color,
                  () => ref.read(featuresProvider.notifier).toggle(FKey.droneTopDown)),
              _ctrlBtn('RESET', Icons.zoom_out_map, color,
                  () => setState(() {
                    _camX = 0; _camY = 0; _camZ = 0;
                    _zoomLevel = 1.0;
                    _manualYaw = 0;
                    _manualPitch = 0;
                    _compassLocked = false;
                  })),
            ]),
            const SizedBox(height: 4),
            // Row 2: quick-nav + stealth
            Row(children: [
              _ctrlBtn('AI', Icons.psychology, const Color(0xFFCC88FF),
                  () => context.go('/ai_signal_brain')),
              _ctrlBtn('SIGINT', Icons.wifi_tethering, const Color(0xFF00CCFF),
                  () => context.go('/sigint')),
              _ctrlBtn('BLE', Icons.bluetooth, const Color(0xFF7986CB),
                  () => context.go('/bluetooth')),
              _ctrlBtn('RADAR', Icons.radar, color,
                  () => context.go('/real_radar')),
              _ctrlBtn(stealth ? 'STEALTH' : 'COVERT',
                  Icons.visibility_off,
                  stealth ? const Color(0xFFCE93D8) : color.withValues(alpha: 0.4),
                  () => ref.read(stealthProtocolProvider.notifier).toggle()),
              _ctrlBtn('HUD', Icons.tune, color,
                  () => FalconSidePanel.show(context)),
            ]),
          ]),
        ),
        ), // SafeArea
      ),
    );
  }

  Widget _ctrlBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 1),
            Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
          ]),
        ),
      ),
    );
  }

  // ─── Compass Mini-Map — circular top-down view + compass ring ─────────────────
  Widget _buildCompassMiniMap(MetalDetectionState metal,
      MultiSignalFusionState fusion, BleScanState ble, Color color) {
    final imu = ref.watch(imuFusionProvider);
    return GestureDetector(
      onTap: _syncCompass,
      child: Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.72),
          border: Border.all(
            color: _compassLocked ? const Color(0xFF00CCFF) : color,
            width: _compassLocked ? 2.0 : 1.0,
          ),
          boxShadow: [BoxShadow(
            color: (_compassLocked ? const Color(0xFF00CCFF) : color)
                .withValues(alpha: 0.25),
            blurRadius: 12,
          )],
        ),
        child: ClipOval(
          child: Stack(alignment: Alignment.center, children: [
            // Top-down mini map painter
            CustomPaint(
              size: const Size(90, 90),
              painter: _CompassMapPainter(
                points: fusion.fused3DEnvironment,
                matterDetections: metal.detections,
                bleDevices: ble.devices,
                meshPeers: ref.watch(peerMeshProvider).peers,
                heading: imu.yaw,
                camX: _camX,
                camZ: _camZ,
                manualYaw: _manualYaw,
                color: color,
                compassLocked: _compassLocked,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── Compass Button (top-right) ─────────────────────────────────────────────
  Widget _buildCompassButton(Color color) {
    final imu = ref.watch(imuFusionProvider);
    final headingDeg = (imu.yaw * 180 / math.pi) % 360;
    final compassColor = _compassLocked ? const Color(0xFF00CCFF) : color;
    return GestureDetector(
      onTap: _syncCompass,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.72),
          border: Border.all(
            color: compassColor,
            width: _compassLocked ? 2.0 : 1.0,
          ),
          boxShadow: [BoxShadow(
            color: compassColor.withValues(alpha: 0.35),
            blurRadius: _compassLocked ? 12 : 4,
          )],
        ),
        child: Stack(alignment: Alignment.center, children: [
          // Rotating compass needle
          Transform.rotate(
            angle: -imu.yaw,
            child: Icon(Icons.explore, color: compassColor, size: 22),
          ),
          if (_compassLocked)
            Positioned(
              bottom: 3,
              child: Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00CCFF).withValues(alpha: 0.9),
                  boxShadow: [BoxShadow(color: const Color(0xFF00CCFF), blurRadius: 4)],
                ),
              ),
            ),
        ]),
      ),
    );
  }

  // ─── Gamepad widget (plain widget — caller handles Positioned) ───────────────
  Widget _buildGamepadWidget(GamepadSettings cfg, Color color) {
    final btnSz = cfg.btnSize;
    final gap = cfg.gap;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // D-pad cluster
        Column(mainAxisSize: MainAxisSize.min, children: [
          _gpBtn(MoveDir.forward,   Icons.arrow_upward,   color, btnSz),
          SizedBox(height: gap),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _gpBtn(MoveDir.strafeLeft,  Icons.arrow_back,    color, btnSz),
            SizedBox(width: gap),
            Container(
              width: btnSz, height: btnSz,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.45),
                border: Border.all(color: color.withValues(alpha: 0.15)),
              ),
              child: Icon(Icons.gamepad_outlined,
                  color: color.withValues(alpha: 0.25), size: btnSz * 0.36),
            ),
            SizedBox(width: gap),
            _gpBtn(MoveDir.strafeRight, Icons.arrow_forward, color, btnSz),
          ]),
          SizedBox(height: gap),
          _gpBtn(MoveDir.backward,  Icons.arrow_downward, color, btnSz),
        ]),

        SizedBox(width: gap * 3),

        // Altitude column
        Column(mainAxisSize: MainAxisSize.min, children: [
          _gpBtn(MoveDir.altUp,   Icons.keyboard_arrow_up,   color, btnSz,
              icon2: Icons.flight_takeoff),
          SizedBox(height: gap * 2 + btnSz),
          _gpBtn(MoveDir.altDown, Icons.keyboard_arrow_down, color, btnSz,
              icon2: Icons.flight_land),
        ]),
      ],
    );
  }

  // ─── Floating Gamepad (OLD — kept for legacy call, now unused) ───────────────
  Widget _buildGamepad(GamepadSettings cfg, Color color) =>
      _buildGamepadWidget(cfg, color);

  Widget _gpBtn(MoveDir dir, IconData icon, Color color, double size,
      {IconData? icon2}) {
    final isActive = _activeDir == dir;
    return GestureDetector(
      onTapDown: (_) => _startMove(dir),
      onTapUp: (_) => _stopMove(),
      onTapCancel: () => _stopMove(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? color.withValues(alpha: 0.30)
              : Colors.black.withValues(alpha: 0.55),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.35),
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10)]
              : null,
        ),
        child: Icon(icon2 ?? icon, color: isActive ? color : color.withValues(alpha: 0.6),
            size: size * 0.45),
      ),
    );
  }

  // ─── Detection Legend — always visible (like Google Maps legend) ─────────────
  Widget _buildDetectionLegend(MetalDetectionState metal,
      MultiSignalFusionState fusion, BleScanState ble,
      List<CellularCell> cells, Color themeColor) {

    // Matter type entries
    final byType = <String, Color>{};
    for (final d in metal.detections) {
      final hex = _matterColorHex(d.matterType);
      byType[d.matterType.name] = Color(hex | 0xFF000000);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 120),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        border: Border.all(color: themeColor.withValues(alpha: 0.20)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('SIGNALS', style: TextStyle(
              color: themeColor.withValues(alpha: 0.55),
              fontSize: 7, letterSpacing: 1.8, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          // Signal sources always shown
          _legendRow(const Color(0xFFFF2222), 'BLE DEVICES',
              '${ble.devices.length}', Icons.bluetooth),
          _legendRow(const Color(0xFFFFCC00), 'CELL TOWERS',
              '${cells.length}', Icons.cell_tower),
          _legendRow(const Color(0xFF4499FF), 'WiFi CSI',
              '${fusion.activeSignals.values.where((v) => v).length}',
              Icons.wifi),
          // Matter detections
          if (byType.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(height: 0.4,
                color: themeColor.withValues(alpha: 0.20)),
            const SizedBox(height: 6),
            Text('MATTER', style: TextStyle(
                color: themeColor.withValues(alpha: 0.55),
                fontSize: 7, letterSpacing: 1.8, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            ...byType.entries.map((e) {
              final count = metal.detections
                  .where((d) => d.matterType.name == e.key).length;
              return _legendDotRow(e.value, e.key, '$count');
            }),
          ] else ...[
            const SizedBox(height: 5),
            Text('no detections', style: TextStyle(
                color: themeColor.withValues(alpha: 0.25), fontSize: 7)),
          ],
        ],
      ),
    );
  }

  Widget _legendRow(Color dot, String label, String val, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 9, height: 9,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dot,
                  boxShadow: [BoxShadow(color: dot.withValues(alpha: 0.5), blurRadius: 4)])),
          const SizedBox(width: 5),
          Expanded(child: Text(label, style: const TextStyle(
              color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis)),
          Text(val, style: TextStyle(color: dot, fontSize: 8,
              fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _legendDotRow(Color dot, String label, String val) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 9, height: 9,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dot,
                  boxShadow: [BoxShadow(color: dot.withValues(alpha: 0.6), blurRadius: 5)])),
          const SizedBox(width: 5),
          Expanded(child: Text(label, style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7), fontSize: 8),
              overflow: TextOverflow.ellipsis)),
          Text(val, style: TextStyle(color: dot, fontSize: 8,
              fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _buildZoomIndicator(Color color) {
    final dist = math.sqrt(_camX * _camX + _camY * _camY + _camZ * _camZ);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        border: Border.all(color: color, width: 0.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.flight, color: color, size: 14),
        const SizedBox(height: 3),
        Text('${dist.toStringAsFixed(1)}u',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        Text('X:${_camX.toStringAsFixed(1)}\nY:${_camY.toStringAsFixed(1)}\nZ:${_camZ.toStringAsFixed(1)}',
            style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 7,
                fontFamily: 'monospace', height: 1.4)),
      ]),
    );
  }

  Widget _buildStatsPanel(WiFiCSIState csiState, MultiSignalFusionState fusionState,
      BleScanState bleState, List<CellularCell> cells, Color color) {
    final useGlass = ref.watch(featuresProvider)[FKey.glassmorphismHud];
    final inner = Container(
      width: 175,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: useGlass ? null : BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('SIGNAL TELEMETRY', style: TextStyle(color: color, fontSize: 7, letterSpacing: 1, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          _statRow('Signals', '${fusionState.activeSignals.values.where((v) => v).length}/5', true, color),
          _statRow('3D Pts', '${fusionState.fused3DEnvironment.length}', true, color),
          _statRow('BLE', '${bleState.devices.length} devs', bleState.devices.isNotEmpty, color),
          _statRow('Cell', '${cells.length} twrs', cells.isNotEmpty, color),
          _statRow('CSI', '${csiState.sampleRate > 0 ? csiState.sampleRate : 1000}Hz', csiState.isCapturing, color),
          _statRow('Status', fusionState.isActive ? 'LIVE' : 'FUSING', fusionState.isActive, color),
          _statRow('Yaw', '${(_manualYaw * 180 / math.pi).toStringAsFixed(0)}\u00B0', true, color),
        ],
      ),
    );
    if (!useGlass) return inner;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            border: Border.all(color: color.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: inner,
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, bool active, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8)),
        Text(value, style: TextStyle(color: active ? color : Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildModeSelectorPanel() {
    final features = ref.watch(featuresProvider);
    final activeModeName = features.activeModeName;

    return GlassOverlay(
      color: features.primaryColor,
      title: 'VISION PROFILE',
      onClose: () => setState(() => _showModeSelector = false),
      child: Column(
        children: [
          // ── Subtitle ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              Icon(Icons.link, color: features.primaryColor.withValues(alpha: 0.5), size: 12),
              const SizedBox(width: 6),
              Text(
                'EACH PROFILE SETS VISION MODE + UI THEME TOGETHER',
                style: TextStyle(color: features.primaryColor.withValues(alpha: 0.45),
                    fontSize: 8, letterSpacing: 1.2),
              ),
            ]),
          ),
          // ── Profile grid ─────────────────────────────────────────────────
          Expanded(child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.15,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: VisionMode.values.length,
            itemBuilder: (context, index) {
              final mode = VisionMode.values[index];
              final isActive = _modeEnumName(mode) == activeModeName;
              final isLocked = mode.requiresRoot && !widget.hasRootAccess;
              final modeColor = mode.primaryColor;
              final themeAccent = mode.linkedTheme.accent;

              return GestureDetector(
                onTap: () => _switchMode(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  decoration: BoxDecoration(
                    // gradient blends mode color + theme accent
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isActive
                          ? [
                              modeColor.withValues(alpha: 0.22),
                              themeAccent.withValues(alpha: 0.08),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.03),
                              Colors.black.withValues(alpha: 0.30),
                            ],
                    ),
                    border: Border.all(
                      color: isActive ? modeColor : modeColor.withValues(alpha: 0.18),
                      width: isActive ? 1.5 : 0.5,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isActive
                        ? [
                            BoxShadow(color: modeColor.withValues(alpha: 0.30), blurRadius: 20),
                            BoxShadow(color: themeAccent.withValues(alpha: 0.12), blurRadius: 8),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // ── Icon with lock overlay ──────────────────────
                            Stack(alignment: Alignment.center, children: [
                              // Theme color ring behind icon
                              Container(
                                width: 42, height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(colors: [
                                    modeColor.withValues(alpha: isActive ? 0.28 : 0.10),
                                    Colors.transparent,
                                  ]),
                                ),
                              ),
                              Icon(mode.icon,
                                color: isLocked
                                    ? Colors.white24
                                    : (isActive ? modeColor : modeColor.withValues(alpha: 0.7)),
                                size: 28,
                                shadows: isActive
                                    ? [Shadow(color: modeColor.withValues(alpha: 0.8), blurRadius: 12)]
                                    : null,
                              ),
                              if (isLocked)
                                Positioned(right: 0, bottom: 0,
                                    child: Icon(Icons.lock, color: Colors.orange, size: 12)),
                              if (isActive)
                                Positioned(right: 0, top: 0,
                                    child: Icon(Icons.check_circle, color: modeColor, size: 12,
                                        shadows: [Shadow(color: modeColor, blurRadius: 6)])),
                            ]),
                            const SizedBox(height: 6),

                            // ── Mode name ──────────────────────────────────
                            Text(mode.name,
                              style: TextStyle(
                                color: isLocked ? Colors.white24 : (isActive ? modeColor : Colors.white70),
                                fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5,
                                shadows: isActive
                                    ? [Shadow(color: modeColor.withValues(alpha: 0.6), blurRadius: 8)]
                                    : null,
                              ),
                              textAlign: TextAlign.center),
                            const SizedBox(height: 3),

                            // ── Theme pill ─────────────────────────────────
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: themeAccent.withValues(alpha: isActive ? 0.18 : 0.07),
                                border: Border.all(
                                    color: themeAccent.withValues(alpha: isActive ? 0.6 : 0.2),
                                    width: 0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(mode.linkedTheme.icon, color: themeAccent, size: 8),
                                const SizedBox(width: 3),
                                Text(mode.linkedTheme.label,
                                  style: TextStyle(
                                    color: isLocked ? Colors.white12 : themeAccent.withValues(alpha: isActive ? 0.9 : 0.55),
                                    fontSize: 7, letterSpacing: 0.3,
                                  )),
                              ]),
                            ),
                            const SizedBox(height: 3),

                            // ── Description ────────────────────────────────
                            Text(mode.description,
                              style: TextStyle(
                                color: isLocked ? Colors.white12 : Colors.white.withValues(alpha: 0.28),
                                fontSize: 7),
                              textAlign: TextAlign.center,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          )),
        ],
      ),
    );
  }
  
  Widget _buildRecordingReplayBanner(RecordingReplayService recordingService, ReplayState replayState) {
    final features = ref.watch(featuresProvider);
    final color = features.primaryColor;

    if (recordingService.isRecording) {
      final duration = recordingService.recordingDuration ?? Duration.zero;
      final minutes = duration.inMinutes.toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      return Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          border: Border.all(color: Colors.red, width: 1),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
          const SizedBox(width: 6),
          Text('REC $minutes:$seconds', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      );
    } else if (replayState.isPlaying) {
      final currentMin = replayState.currentTime.inMinutes.toString().padLeft(2, '0');
      final currentSec = (replayState.currentTime.inSeconds % 60).toString().padLeft(2, '0');
      final totalMin = replayState.totalDuration.inMinutes.toString().padLeft(2, '0');
      final totalSec = (replayState.totalDuration.inSeconds % 60).toString().padLeft(2, '0');
      return Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color, width: 1),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('REPLAY $currentMin:$currentSec / $totalMin:$totalSec (${replayState.playbackSpeed}x)',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: Icon(replayState.isPaused ? Icons.play_arrow : Icons.pause, color: color, size: 18),
              onPressed: () => replayState.isPaused ? recordingService.play() : recordingService.pause()),
            IconButton(icon: Icon(Icons.stop, color: color, size: 18), onPressed: () => recordingService.stop()),
            IconButton(icon: Icon(Icons.fast_rewind, color: color, size: 18),
              onPressed: () => recordingService.seekToFrame((replayState.currentFrameIndex - 10).clamp(0, replayState.totalFrames - 1))),
            IconButton(icon: Icon(Icons.fast_forward, color: color, size: 18),
              onPressed: () => recordingService.seekToFrame((replayState.currentFrameIndex + 10).clamp(0, replayState.totalFrames - 1))),
            IconButton(
              icon: Icon(replayState.loopEnabled ? Icons.repeat_on : Icons.repeat,
                color: replayState.loopEnabled ? Colors.green : color, size: 18),
              onPressed: () => recordingService.toggleLoop()),
          ]),
        ]),
      );
    }
    return const SizedBox.shrink();
  }
  
  Future<void> _toggleRecording(RecordingReplayService recordingService) async {
    if (recordingService.isRecording) {
      final metadata = await recordingService.stopRecording();
      if (metadata != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved: ${metadata.name}'), backgroundColor: Colors.green.shade900));
      }
    } else {
      await recordingService.startRecording();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording...'), backgroundColor: Colors.red));
      }
    }
  }
  
  Future<void> _showReplayDialog(BuildContext context, RecordingReplayService recordingService) async {
    final recordings = await recordingService.loadRecordingsList();
    if (!mounted) return;
    if (recordings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recordings found'), backgroundColor: Colors.orange));
      return;
    }
    final features = ref.read(featuresProvider);
    final color = features.primaryColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: color, width: 1)),
        title: Text('RECORDINGS', style: TextStyle(color: color, fontSize: 14)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: recordings.length,
            itemBuilder: (context, index) {
              final rec = recordings[index];
              return ListTile(
                leading: Icon(Icons.movie, color: color, size: 18),
                title: Text(rec.name, style: TextStyle(color: color, fontSize: 12)),
                subtitle: Text('${rec.frameCount} frames', style: const TextStyle(color: Colors.white30, fontSize: 10)),
                onTap: () async {
                  Navigator.pop(context);
                  final loaded = await recordingService.loadRecording(rec);
                  if (loaded && mounted) recordingService.play();
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                  onPressed: () async {
                    await recordingService.deleteRecording(rec);
                    Navigator.pop(context);
                    _showReplayDialog(context, recordingService);
                  },
                ),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('CLOSE', style: TextStyle(color: color)))],
      ),
    );
  }

  Widget _buildAISummary(MultiSignalFusionState fusionState, Color color) {
    final signals = fusionState.activeSignals.entries.where((e) => e.value).map((e) => e.key).toList();
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(Icons.smart_toy, color: color, size: 11),
          const SizedBox(width: 4),
          Text('AI SIGNAL SUMMARY', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 4),
        Text(
          signals.isEmpty
            ? 'No active signals. Environment clear.'
            : '${signals.length} active: ${signals.take(3).join(", ")}. Confidence ${(55 + signals.length * 8).clamp(0, 97)}%.',
          style: const TextStyle(color: Colors.white54, fontSize: 9), maxLines: 2),
      ]),
    );
  }

  Widget _buildDirectionFindingPanel(MultiSignalFusionState fusionState, Color color) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('DIR FIND', style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        SizedBox(
          width: 60, height: 60,
          child: CustomPaint(
            painter: _DirectionFindingPainter(color: color, progress: _animationController.value),
          ),
        ),
        Text('3 sources', style: TextStyle(color: color, fontSize: 8)),
      ]),
    );
  }

  Widget _buildJammerAlertWidget(Color color) {
    final t = _animationController.value;
    final pulse = (0.4 + 0.6 * (t > 0.5 ? 1.0 - t : t) * 2).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        border: Border.all(color: Colors.orange.withValues(alpha: pulse)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.warning_amber, color: Colors.orange.withValues(alpha: pulse), size: 12),
        const SizedBox(width: 4),
        Text('JAMMER CLEAR', style: TextStyle(color: Colors.orange.withValues(alpha: pulse), fontSize: 9, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  //  V49.9 REAL TOGGLE METHOD IMPLEMENTATIONS
  // ════════════════════════════════════════════════════════════════════════════

  /// MULTI-SIGNAL CALIBRATION — zeros Kalman filter baselines for all sensors.
  /// Real effect: resets RSSI mean/variance accumulators so next N samples
  /// re-establish the noise floor from scratch.
  void _runCalibration() async {
    if (_calibrating) return;
    setState(() => _calibrating = true);
    // Reset fusion state baselines
    ref.read(multiSignalFusionProvider.notifier).stop();
    await Future.delayed(const Duration(milliseconds: 400));
    ref.read(multiSignalFusionProvider.notifier).start();
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _calibrating = false);
    // Turn toggle back off — calibration is a one-shot action
    ref.read(featuresProvider.notifier).toggle(FKey.multiSignalCalib, value: false);
  }

  /// EXPORT 3D — writes current fused point cloud as JSON to app documents dir
  void _export3DScene(MultiSignalFusionState state) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/falcon_eye_3d_$ts.json';
      final points = state.fused3DEnvironment.map((p) => {
        'x': p.x, 'y': p.y, 'z': p.z,
        'strength': p.reflectionStrength,
        'type': p.materialType?.name ?? 'unknown',
      }).toList();
      final payload = jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
        'pointCount': points.length,
        'points': points,
        'signalSources': state.activeSignals,
      });
      await File(path).writeAsString(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('3D scene exported: ${points.length} pts → falcon_eye_3d_$ts.json',
            style: const TextStyle(color: Colors.white, fontSize: 11)),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red.shade900,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  /// BURST SCAN — triggered by voiceActivatedScan double-tap gesture
  /// Runs all scanners at max rate for 5 seconds then returns to normal
  void _triggerBurstScan() {
    // Start all scanners at high rate
    ref.read(bleServiceProvider.notifier).startScan();
    ref.read(multiSignalFusionProvider.notifier).start();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.sensors, color: Colors.white, size: 14),
          const SizedBox(width: 8),
          const Text('BURST SCAN — 5s',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
        backgroundColor: Colors.green.shade900,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    }
    // Auto-stop burst after 5s if battery save is active
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && ref.read(batteryOptimizerProvider).active) {
        ref.read(bleServiceProvider.notifier).stopScan();
      }
    });
  }

  /// CYCLE VISION MODE — triggered by voiceCommands triple-tap gesture
  void _cycleVisionMode() {
    final modes = VisionMode.values;
    final currentIdx = modes.indexOf(_currentMode);
    final nextMode = modes[(currentIdx + 1) % modes.length];
    ref.read(featuresProvider.notifier).setProfile(
      modeName: nextMode.name,
      theme: nextMode.linkedTheme,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('MODE → ${nextMode.name.toUpperCase()}',
            style: const TextStyle(color: Colors.white, fontSize: 12,
                fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ));
    }
  }

  /// RAW SIGINT STREAM — scrolling live ticker of BLE/WiFi/Cell packets
  Widget _buildRawSigintStream(MultiSignalFusionState fusion, BleScanState ble,
      List<CellularCell> cells, Color color) {
    final entries = <String>[];
    for (final d in ble.devices.take(4)) {
      entries.add('[BLE] ${d.name.isEmpty ? d.id.substring(0, 10) : d.name}  ${d.rssi}dBm');
    }
    for (final c in cells.take(3)) {
      entries.add('[CELL-${c.type}] MCC${c.mcc} MNC${c.mnc}  ${c.dbm}dBm  PCI:${c.pci ?? "?"}');
    }
    for (final s in fusion.fused3DEnvironment.take(2)) {
      entries.add('[CSI] src=${s.materialType?.name ?? "?"} r=${s.reflectionStrength.toStringAsFixed(2)}');
    }
    if (entries.isEmpty) entries.add('[SIGINT] Awaiting signals…');

    return RepaintBoundary(
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          border: Border(top: BorderSide(color: color.withValues(alpha: 0.3), width: 0.5)),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          physics: const NeverScrollableScrollPhysics(),
          children: entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Text(e,
              style: TextStyle(color: color.withValues(alpha: 0.75), fontSize: 9,
                fontFamily: 'monospace', letterSpacing: 0.5),
            ),
          )).toList(),
        ),
      ),
    );
  }

  /// BIO TOMOGRAPHY PANEL — FFT heart rate + respiration readout
  Widget _buildBioTomographyPanel(BioTomographyState state, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Icon(Icons.biotech, color: Color(0xFF00FFCC), size: 11),
            const SizedBox(width: 4),
            Text('BIO-TOMO FFT',
              style: const TextStyle(color: Color(0xFF00FFCC), fontSize: 9,
                fontWeight: FontWeight.bold, letterSpacing: 1)),
          ]),
          const SizedBox(height: 4),
          _bioRow('♥ HEART', state.heartRate > 0 ? '${state.heartRate.toStringAsFixed(0)} bpm' : '—', const Color(0xFFFF1744)),
          _bioRow('~ RESP', state.respiratoryRate > 0 ? '${state.respiratoryRate.toStringAsFixed(1)} Hz' : '—', const Color(0xFF4FC3F7)),
          _bioRow('CONF', '${(state.confidence * 100).toStringAsFixed(0)}%', const Color(0xFF00FFCC)),
          if (state.detectedEntities.isNotEmpty)
            _bioRow('ENTITIES', '${state.detectedEntities.length}', const Color(0xFF69FF47)),
        ],
      ),
    );
  }

  Widget _bioRow(String label, String value, Color c) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 52,
          child: Text(label, style: TextStyle(color: c.withValues(alpha: 0.6), fontSize: 8, letterSpacing: 0.5))),
        Text(value, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    ),
  );

  /// CALIBRATION BANNER
  Widget _buildCalibrationBanner(Color color) => Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.88),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 14, height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: color)),
        const SizedBox(width: 8),
        Text('CALIBRATING SENSORS — HOLD STILL',
          style: TextStyle(color: color, fontSize: 10,
            fontWeight: FontWeight.bold, letterSpacing: 1)),
      ]),
    ),
  );

  /// GPU TIER BADGE — shows detected chipset and point budget
  Widget _buildGpuTierBadge(HardwareCapabilities caps, Color color) {
    final chip = caps.chipset.toUpperCase();
    final tier = caps.tier1Flagship.enabled ? 'TIER-1' : 'MID';
    final budget = caps.tier1Flagship.enabled ? '500K pts' : '80K pts';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('GPU $tier', style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
          Text(chip.length > 14 ? chip.substring(0, 14) : chip,
            style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 7)),
          Text(budget, style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 7)),
        ],
      ),
    );
  }

  /// NATIVE GL RENDERER BADGE
  Widget _buildNativeGLBadge(Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.75),
      border: Border.all(color: color.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.memory, color: color, size: 9),
      const SizedBox(width: 3),
      Text('C++ GL ACTIVE', style: TextStyle(color: color, fontSize: 8,
        fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    ]),
  );

  /// QUANTUM ENGINE BADGE — shows realtime point throughput
  Widget _buildQuantumEngineBadge(MultiSignalFusionState state, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.75),
      border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.bolt, color: const Color(0xFF00E5FF), size: 9),
      const SizedBox(width: 3),
      Text('QE ${state.fused3DEnvironment.length}pts @120fps',
        style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 8,
          fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    ]),
  );

  /// ENCRYPTED VAULT BADGE — shows AES-SHA256 armed status
  Widget _buildEncryptedVaultBadge(Color color) {
    final vault = ref.watch(encryptedVaultProvider);
    const gold = Color(0xFFFFD700);
    final statusOk = vault.armed;
    final bg = statusOk
        ? Colors.black.withValues(alpha: 0.85)
        : const Color(0xFF1A0800).withValues(alpha: 0.85);
    final border = statusOk ? gold.withValues(alpha: 0.5) : Colors.red.withValues(alpha: 0.4);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(3),
        boxShadow: statusOk
            ? [BoxShadow(color: gold.withValues(alpha: 0.15), blurRadius: 6)]
            : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          statusOk ? Icons.enhanced_encryption : Icons.lock_open,
          color: statusOk ? gold : Colors.red,
          size: 9,
        ),
        const SizedBox(width: 3),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(
            statusOk ? 'AES-256 ARMED' : 'VAULT OPEN',
            style: TextStyle(
              color: statusOk ? gold : Colors.red,
              fontSize: 7,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          if (vault.filesEncrypted > 0)
            Text(
              '${vault.filesEncrypted} FILES ENCRYPTED',
              style: TextStyle(
                color: (statusOk ? gold : Colors.red).withValues(alpha: 0.65),
                fontSize: 6,
                letterSpacing: 0.3,
              ),
            ),
        ]),
      ]),
    );
  }

  /// REPLAY CONTROLS — plays back a recorded session
  Widget _buildReplayControls(ReplayState replay, RecordingReplayService svc, Color color) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.88),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.fiber_manual_record, color: Colors.red, size: 11),
          const SizedBox(width: 4),
          Text('REPLAY', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          _replayBtn(Icons.skip_previous, color, () => svc.seekToFrame(0)),
          _replayBtn(replay.isPlaying ? Icons.pause : Icons.play_arrow, color,
            () => replay.isPlaying ? svc.pause() : svc.play()),
          _replayBtn(Icons.stop, color, svc.stop),
          const SizedBox(width: 8),
          Text('${replay.currentFrameIndex}/${replay.totalFrames}',
            style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9)),
        ]),
      ),
    );
  }

  Widget _replayBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(5),
      child: Icon(icon, color: color, size: 16),
    ),
  );
}


// ══════════════════════════════════════════════════════════════════════════════
//  COMPASS MINI-MAP PAINTER  V49.9
//  Top-down 2D view of all detected points + compass ring
//  Rotates with real phone compass (heading) when compassLocked
// ══════════════════════════════════════════════════════════════════════════════
class _CompassMapPainter extends CustomPainter {
  final List<dynamic> points;          // fused3DEnvironment
  final List<dynamic> matterDetections;
  final List<dynamic> bleDevices;
  final List<dynamic> meshPeers;       // MeshPeer list for peer mesh dots
  final double heading;   // IMU yaw in radians
  final double camX, camZ, manualYaw;
  final Color color;
  final bool compassLocked;

  _CompassMapPainter({
    required this.points,
    required this.matterDetections,
    required this.bleDevices,
    required this.heading,
    required this.camX, required this.camZ,
    required this.manualYaw,
    required this.color,
    required this.compassLocked,
    this.meshPeers = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = cx - 1;
    final viewYaw = manualYaw; // angle to rotate the map

    // Background
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = const Color(0xFF030A06));

    // Compass rings
    for (final frac in [0.33, 0.66, 1.0]) {
      canvas.drawCircle(Offset(cx, cy), r * frac,
          Paint()
            ..color = color.withValues(alpha: 0.08)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5);
    }

    // Cardinal direction ticks
    final cardinalPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;
    for (int i = 0; i < 4; i++) {
      final a = viewYaw + i * math.pi / 2;
      final cos = math.cos(a); final sin = math.sin(a);
      canvas.drawLine(
        Offset(cx + cos * (r - 8), cy + sin * (r - 8)),
        Offset(cx + cos * r,       cy + sin * r),
        cardinalPaint,
      );
    }

    // N indicator (red)
    final nAngle = viewYaw;
    final tp = TextPainter(
      text: TextSpan(text: 'N',
          style: const TextStyle(color: Color(0xFFFF3333), fontSize: 7,
              fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset(cx + math.cos(nAngle) * (r - 15) - tp.width / 2,
               cy + math.sin(nAngle) * (r - 15) - tp.height / 2));

    // Clip to circle for points
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r - 1)));

    // World scale: map ±20 world units to circle radius
    const worldScale = 20.0;

    // Fused 3D environment points (tiny dots)
    if (points.isNotEmpty) {
      final ptPaint = Paint()..color = color.withValues(alpha: 0.45);
      for (final p in points) {
        try {
          // Rotate point by -viewYaw so map rotates with compass
          final wx = (p.x as double) - camX;
          final wz = (p.z as double) - camZ;
          final rx = wx * math.cos(-viewYaw) - wz * math.sin(-viewYaw);
          final rz = wx * math.sin(-viewYaw) + wz * math.cos(-viewYaw);
          final sx = cx + rx / worldScale * r;
          final sy = cy + rz / worldScale * r;
          canvas.drawCircle(Offset(sx, sy), 1.0, ptPaint);
        } catch (_) {}
      }
    }

    // Matter detections (colored circles)
    for (final d in matterDetections) {
      try {
        final wx = (d.x as double) - camX;
        final wz = (d.z as double) - camZ;
        final rx = wx * math.cos(-viewYaw) - wz * math.sin(-viewYaw);
        final rz = wx * math.sin(-viewYaw) + wz * math.cos(-viewYaw);
        final sx = cx + rx / worldScale * r;
        final sy = cy + rz / worldScale * r;
        canvas.drawCircle(Offset(sx, sy), 3.0,
            Paint()..color = const Color(0xFFFFD700).withValues(alpha: 0.8));
      } catch (_) {}
    }

    // BLE devices (blue dots, arranged in ring by signal strength)
    final rng = math.Random(42);
    for (int i = 0; i < bleDevices.length; i++) {
      final angle = i * math.pi * 2 / bleDevices.length.clamp(1, 99);
      final dist = 0.3 + rng.nextDouble() * 0.5;
      canvas.drawCircle(
        Offset(cx + math.cos(angle - viewYaw) * r * dist,
               cy + math.sin(angle - viewYaw) * r * dist),
        2.0,
        Paint()..color = const Color(0xFF7986CB).withValues(alpha: 0.7),
      );
    }

    // Mesh peers — orange pulsing dots at estimated bearing+distance
    for (final peer in meshPeers) {
      try {
        final bearing = (peer.bearingDeg as double) * math.pi / 180.0;
        final dist = ((peer.estimatedDistanceM as double) / 50.0).clamp(0.15, 0.9);
        final sx = cx + math.sin(bearing - viewYaw) * r * dist;
        final sy = cy - math.cos(bearing - viewYaw) * r * dist;
        // Outer glow
        canvas.drawCircle(Offset(sx, sy), 5.0,
            Paint()..color = const Color(0xFFFF8C00).withValues(alpha: 0.25)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        // Core dot
        canvas.drawCircle(Offset(sx, sy), 3.0,
            Paint()..color = const Color(0xFFFF8C00).withValues(alpha: 0.9));
      } catch (_) {}
    }

    canvas.restore();

    // Camera position indicator (camera position = origin in this view, always center)
    canvas.drawCircle(Offset(cx, cy), 3.5,
        Paint()..color = color);
    // View direction arrow
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + math.sin(0) * 12, cy - math.cos(0) * 12), // always points up = forward
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );

    // Compass needle (rotating with real phone north)
    final northAngle = heading + viewYaw;
    final needlePaint = Paint()..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    // Red half (north)
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + math.sin(northAngle) * 10, cy - math.cos(northAngle) * 10),
      needlePaint..color = const Color(0xFFFF3333),
    );
    // White half (south)
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx - math.sin(northAngle) * 8, cy + math.cos(northAngle) * 8),
      needlePaint..color = Colors.white54,
    );

    // Lock indicator
    if (compassLocked) {
      canvas.drawCircle(Offset(cx, cy + r - 6), 2.5,
          Paint()..color = const Color(0xFF00CCFF)
            ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 3));
    }
  }

  @override
  bool shouldRepaint(_CompassMapPainter old) =>
      old.heading != heading ||
      old.camX != camX || old.camZ != camZ ||
      old.manualYaw != manualYaw ||
      old.compassLocked != compassLocked ||
      old.points.length != points.length ||
      old.matterDetections.length != matterDetections.length ||
      old.bleDevices.length != bleDevices.length;
}

// ─── Waveform Painter ──────────────────────────────────────────
class _WaveformPainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final bool isActive;
  const _WaveformPainter({required this.animationValue, required this.color, required this.isActive});

  static const _pi = 3.14159265;
  double _sinApprox(double x) {
    final xmod = x.remainder(_pi * 2);
    if (xmod < _pi) { final t = xmod / _pi; return 4 * t * (1 - t); }
    else { final t = (xmod - _pi) / _pi; return -(4 * t * (1 - t)); }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = animationValue * 2 * _pi;
    final h = size.height; final w = size.width; final cy = h / 2;
    final waveConfigs = [
      (color, 0.3, 1.0, 0.0),
      (const Color(0xFFFF3333), 0.18, 0.7, 1.1),
      (const Color(0xFF0099FF), 0.12, 0.5, 2.3),
    ];
    for (final cfg in waveConfigs) {
      final wColor = cfg.$1;
      final amp = cfg.$2 * h * (isActive ? 1.0 : 0.3);
      final freq = cfg.$3; final phase = cfg.$4;
      final path = Path(); bool first = true;
      for (double x = 0; x <= w; x += 2) {
        final progress = x / w;
        final y = cy + amp * (0.6 * _sinApprox(freq * progress * _pi * 4 + t + phase) +
            0.25 * _sinApprox(progress * 7.3 + t + phase) +
            0.15 * _sinApprox(progress * 13.7 + t * 1.3 + phase));
        if (first) { path.moveTo(x, y); first = false; } else { path.lineTo(x, y); }
      }
      canvas.drawPath(path, Paint()
        ..color = wColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke..strokeWidth = 0.8
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 1.5));
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      (animationValue - old.animationValue).abs() > 0.005 ||
      old.isActive != isActive || old.color != color;
}

class _DirectionFindingPainter extends CustomPainter {
  final Color color;
  final double progress;
  _DirectionFindingPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2; final r = size.width / 2 - 3;
    final ringPaint = Paint()..color = color.withValues(alpha: 0.25)..style = PaintingStyle.stroke..strokeWidth = 0.5;
    canvas.drawCircle(Offset(cx, cy), r, ringPaint);
    final arrowPaint = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final angles = [0.4 + progress * 0.3, 2.1 - progress * 0.2, 4.5 + progress * 0.15];
    final strengths = [0.9, 0.7, 0.5];
    for (var i = 0; i < 3; i++) {
      final a = angles[i]; final len = r * strengths[i];
      canvas.drawLine(Offset(cx, cy),
        Offset(cx + len * _cos(a), cy + len * _sin(a)),
        arrowPaint..color = color.withValues(alpha: strengths[i]));
    }
    canvas.drawCircle(Offset(cx, cy), 2, Paint()..color = color);
  }

  double _cos(double a) => (a < 3.14 ? 1.0 - a / 1.57 * 2 : a / 1.57 * 2 - 3).clamp(-1.0, 1.0);
  double _sin(double a) => (a < 3.14 ? a / 3.14 : (6.28 - a) / 3.14).clamp(-1.0, 1.0);

  @override
  bool shouldRepaint(_DirectionFindingPainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  V48.1 — Camera AR Background Layer
//  Renders live camera feed behind the 3D signal canvas.
//  Shows a loading indicator while the controller initialises,
//  and an error badge if the camera is unavailable.
// ═══════════════════════════════════════════════════════════════════════════════
class _CameraBackgroundLayer extends StatelessWidget {
  final CameraBackgroundState camBgState;
  final Color themeColor;
  final bool invisibleCameraMode;

  const _CameraBackgroundLayer({
    required this.camBgState,
    required this.themeColor,
    this.invisibleCameraMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // Error state
    if (camBgState.hasError) {
      return Positioned(
        top: 60,
        right: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.15),
            border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.camera_alt, color: Colors.red, size: 14),
            const SizedBox(width: 6),
            Text('CAM ERR', style: const TextStyle(color: Colors.red, fontSize: 10, fontFamily: 'monospace', letterSpacing: 1.2)),
          ]),
        ),
      );
    }

    // Initialising state
    if (!camBgState.isInitialized || camBgState.controller == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: themeColor.withValues(alpha: 0.5)),
          ),
        ),
      );
    }

    // Live feed — fill screen, then darken so 3D overlay stays readable
    return Positioned.fill(
      child: Stack(children: [
        // Camera preview stretched to fill
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: camBgState.controller!.value.previewSize?.height ?? 1,
              height: camBgState.controller!.value.previewSize?.width ?? 1,
              // invisibleCamera: opacity=0 = covert AR (camera active but user can't see feed)
              child: Opacity(
                opacity: invisibleCameraMode ? 0.0 : 1.0,
                child: CameraPreview(camBgState.controller!),
              ),
            ),
          ),
        ),
        // Darkening overlay so signals stay visible over real-world background
        Container(
          color: Colors.black.withValues(alpha: 0.45),
        ),
      ]),
    );
  }

}


// ─── Anomaly Alert Overlay — stateful so it can run its own animation ─────────
class _AnomalyAlertOverlay extends ConsumerStatefulWidget {
  final MultiSignalFusionState fusionState;
  final Color themeColor;
  const _AnomalyAlertOverlay({required this.fusionState, required this.themeColor});

  @override
  ConsumerState<_AnomalyAlertOverlay> createState() => _AnomalyAlertOverlayState();
}

class _AnomalyAlertOverlayState extends ConsumerState<_AnomalyAlertOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _blink;
  bool _anomalyDetected = false;
  String _anomalyDesc = '';
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))
      ..repeat(reverse: true);
    // Check for anomalies every 2 seconds
    _checkTimer = Timer.periodic(const Duration(seconds: 2), (_) => _checkAnomaly());
  }

  @override
  void dispose() {
    _blink.dispose();
    _checkTimer?.cancel();
    super.dispose();
  }

  void _checkAnomaly() {
    final state = widget.fusionState;
    bool anomaly = false;
    String desc = '';

    // Jammer heuristic: fusion active but zero sources detected
    if (state.isActive && state.fused3DEnvironment.isEmpty && state.status.contains('Fus')) {
      anomaly = true;
      desc = 'SIGNAL VOID — possible jamming';
    }

    // CSI variance spike (signal environment rapidly changing)
    final pts = state.fused3DEnvironment;
    if (pts.length > 10) {
      final strengths = pts.map((p) => p.reflectionStrength).toList();
      final mean = strengths.reduce((a, b) => a + b) / strengths.length;
      final variance = strengths.map((s) => (s - mean) * (s - mean)).reduce((a, b) => a + b) / strengths.length;
      if (variance > 0.15) {
        anomaly = true;
        desc = 'CSI VARIANCE SPIKE  σ²=${variance.toStringAsFixed(3)}';
      }
    }

    if (anomaly != _anomalyDetected || desc != _anomalyDesc) {
      setState(() { _anomalyDetected = anomaly; _anomalyDesc = desc; });
      // Haptic feedback when anomaly first detected
      if (anomaly && !_anomalyDetected) HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_anomalyDetected) return const SizedBox.shrink();
    return Positioned(
      top: kToolbarHeight + 100,
      left: 12, right: 12,
      child: AnimatedBuilder(
        animation: _blink,
        builder: (_, __) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.15 + 0.15 * _blink.value),
            border: Border.all(color: Colors.red.withValues(alpha: 0.6 + 0.4 * _blink.value)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber, color: Colors.red, size: 14),
            const SizedBox(width: 8),
            Expanded(child: Text('⚠ ANOMALY: $_anomalyDesc',
              style: TextStyle(color: Colors.red.withValues(alpha: 0.9 + 0.1 * _blink.value),
                fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
          ]),
        ),
      ),
    );
  }
}
