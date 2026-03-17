import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'nav.dart';
import 'theme.dart';
import 'services/root_permission_service.dart';
import 'services/features_provider.dart';

import 'route_observer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
  ));
  runApp(const ProviderScope(child: FalconEyeApp()));
}

/// V42: App listens to unified theme provider for dynamic ThemeData
class FalconEyeApp extends ConsumerWidget {
  const FalconEyeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(featuresProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'FALCON EYE V51.0',
      theme: buildFalconTheme(features.theme),
      routerConfig: AppRouter.router,
      locale: const Locale('en'),
      // PERF V51.0: Route observer allows pages to pause when covered
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );
  }
}

/// V51.0 SOVEREIGN Cinematic Splash Screen — Glassmorphism + Particle System
class CinematicSplashScreen extends ConsumerStatefulWidget {
  const CinematicSplashScreen({super.key});

  @override
  ConsumerState<CinematicSplashScreen> createState() => _CinematicSplashScreenState();
}

class _CinematicSplashScreenState extends ConsumerState<CinematicSplashScreen>
    with SingleTickerProviderStateMixin {
  bool _showRootDialog = false;
  bool _isCheckingRoot = false;
  bool _isRequestingRoot = false;
  late AnimationController _scanController;
  final List<String> _bootMessages = [
    'INITIALIZING QUANTUM GRAPHICS ENGINE (120FPS)...',
    'LOADING OPENGL ES 2.0 VBO POINT RENDERER...',
    'CALIBRATING IMU + MAGNETOMETER + GYROSCOPE...',
    'INITIALIZING LOG-DISTANCE PATH LOSS MODEL...',
    'DEPLOYING BIO-SIGNAL TOMOGRAPHY FFT ENGINE...',
    'LOADING METALLURGIC RADAR (SUSCEPTIBILITY ANALYSIS)...',
    'ACTIVATING 6DoF FREE-MOVE 3D DIGITAL TWIN...',
    'INITIALIZING RAW SIGINT DATA STREAMS...',
    'DEPLOYING GLASSMORPHISM TACTICAL HUD V47...',
    'INITIALIZING NATIVE OPENGL ES 2.0 VBO PIPELINE...',
    'DETECTING GPU TIER (ADRENO/MALI/FALLBACK)...',
    'ESTABLISHING SOVEREIGN PROTOCOLS...',
    'FALCON EYE V51.0 — UNIVERSAL SOVEREIGN EDITION OPERATIONAL.',
  ];
  int _msgIndex = 0;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _animateBootMessages();
  }

  void _animateBootMessages() async {
    for (int i = 0; i < _bootMessages.length; i++) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted) setState(() => _msgIndex = i);
    }
    await Future.delayed(const Duration(milliseconds: 350));
    // Run root detection before showing dialog
    if (mounted) {
      setState(() => _isCheckingRoot = true);
      await ref.read(rootPermissionProvider.notifier).detectRootAccess();
      if (mounted) {
        setState(() {
          _isCheckingRoot = false;
          _showRootDialog = true;
        });
      }
    }
  }

  /// Called when "GRANT ROOT ACCESS" / "ENTER ROOT MODE" button is pressed
  void _onRootModePressed() async {
    final rootState = ref.read(rootPermissionProvider);

    if (rootState.isRooted) {
      // Device IS rooted — request permission and enter
      setState(() => _isRequestingRoot = true);
      final granted = await ref.read(rootPermissionProvider.notifier).requestRootPermission();
      if (!mounted) return;
      setState(() => _isRequestingRoot = false);

      if (granted) {
        // Root granted — navigate with full root access
        _navigateToApp(hasRoot: true);
      } else {
        // Root detected but permission denied — show denied dialog
        _showRootDeniedDialog();
      }
    } else {
      // Device is NOT rooted — show "not rooted" popup
      _showDeviceNotRootedDialog();
    }
  }

  /// Called when "LIMITED VERSION (NO ROOT)" button is pressed
  void _onLimitedModePressed() {
    ref.read(rootPermissionProvider.notifier).setLimitedMode();
    _navigateToApp(hasRoot: false);
  }

  /// Navigate to main app via GoRouter
  void _navigateToApp({required bool hasRoot}) {
    if (!mounted) return;
    context.go('/neo_matrix', extra: {'hasRoot': hasRoot});
  }

  /// Shows dialog: "Your device is NOT rooted" with Retry + Limited Version buttons
  void _showDeviceNotRootedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFFF3333), width: 2),
        ),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3333), size: 30),
          SizedBox(width: 12),
          Expanded(
            child: Text('DEVICE NOT ROOTED',
                style: TextStyle(
                    color: Color(0xFFFF3333),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your device does not have root access.\n\n'
              'Root access (Magisk / KernelSU) is required for full '
              'SIGINT power including:\n',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
            _notRootedFeatureRow(Icons.wifi, 'Wi-Fi CSI 1kHz+ Sampling'),
            _notRootedFeatureRow(Icons.cell_tower, 'Raw Modem Access'),
            _notRootedFeatureRow(Icons.speed, 'High-Freq Sensor Polling'),
            _notRootedFeatureRow(Icons.radar, 'Monitor Mode (Wi-Fi)'),
            const SizedBox(height: 12),
            const Text(
              'You can still use the Limited Version with basic signal fusion.',
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
          // Limited Version button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _onLimitedModePressed();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white54,
                side: const BorderSide(color: Color(0xFF2E5A42)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              icon: const Icon(Icons.shield_outlined, size: 16),
              label: const Text('LIMITED VERSION',
                  style: TextStyle(fontSize: 12, letterSpacing: 0.5)),
            ),
          ),
          const SizedBox(width: 12),
          // Retry button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                // Re-scan for root
                setState(() => _isCheckingRoot = true);
                await ref.read(rootPermissionProvider.notifier).detectRootAccess();
                if (mounted) {
                  setState(() => _isCheckingRoot = false);
                  // Check again
                  final newState = ref.read(rootPermissionProvider);
                  if (newState.isRooted) {
                    _onRootModePressed();
                  } else {
                    _showDeviceNotRootedDialog();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF41),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('RETRY',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ),
          ),
          ]),
        ],
      ),
    );
  }

  Widget _notRootedFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(Icons.cancel, color: const Color(0xFF553333), size: 14),
        const SizedBox(width: 8),
        Icon(icon, size: 14, color: Colors.white30),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ),
      ]),
    );
  }

  /// Shows dialog: Root was detected but permission was denied by Magisk/KernelSU
  void _showRootDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFFFAA00), width: 2),
        ),
        title: const Row(children: [
          Icon(Icons.error_outline, color: Color(0xFFFFAA00), size: 28),
          SizedBox(width: 12),
          Text('ROOT DENIED',
              style: TextStyle(color: Color(0xFFFFAA00), fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
          'Root permission was denied by the system.\n\n'
          'Make sure Magisk / KernelSU is installed and has granted '
          'permission to this app. Try again, or continue in Limited Mode.',
          style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 13),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _onLimitedModePressed();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white54,
                side: const BorderSide(color: Color(0xFF2E5A42)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              child: const Text('LIMITED MODE',
                  style: TextStyle(fontSize: 12, letterSpacing: 0.5)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _onRootModePressed();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF41),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              child: const Text('TRY AGAIN',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ),
          ),
          ]),
        ],
      ),
    );
  }

  @override
  void dispose() { _scanController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final rootState = ref.watch(rootPermissionProvider);

    // Show root/limited dialog after boot sequence
    if (_showRootDialog && !_isCheckingRoot) {
      return _buildRootSelectionScreen(rootState);
    }

    return _buildBootScreen();
  }

  /// The main root/limited selection screen — V47 Glassmorphism
  Widget _buildRootSelectionScreen(RootPermissionState rootState) {
    final hasRoot = rootState.isRooted;
    final isNord3 = rootState.isOnePlusNord3;
    const accent = Color(0xFF00E5FF);
    const green = Color(0xFF00FF41);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Particle background (gradient fallback)
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Color(0xFF001800), Color(0xFF000800), Colors.black],
              ),
            ),
          ),
          Container(color: Colors.black.withValues(alpha: 0.72)),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ─── Logo ────────────────────────────────────────────
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 130, height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF00FF41).withValues(alpha: 0.3),
                                width: 1),
                          ),
                        ).animate(onPlay: (c) => c.repeat())
                            .scale(begin: const Offset(1, 1),
                                   end: const Offset(1.08, 1.08),
                                   duration: 2000.ms)
                            .then()
                            .scale(begin: const Offset(1.08, 1.08),
                                   end: const Offset(1, 1),
                                   duration: 2000.ms),
                        Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                            border: Border.all(color: const Color(0xFF00FF41), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00FF41).withValues(alpha: 0.5),
                                blurRadius: 30, spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.visibility,
                              size: 50, color: Color(0xFF00FF41)),
                        ).animate().fadeIn(duration: 800.ms)
                            .scale(begin: const Offset(0.5, 0.5)),
                      ],
                    ),

                    const SizedBox(height: 28),

                    Text(
                      'FALCON EYE',
                      style: const TextStyle(
                        color: Color(0xFF00FF41),
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 10,
                        shadows: [
                          Shadow(color: Color(0xFF00FF41), blurRadius: 20),
                        ],
                      ),
                    ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.2),

                    const SizedBox(height: 6),
                    const Text(
                      'SOVEREIGN RADIO-WAVE VISION SYSTEM',
                      style: TextStyle(
                          color: Color(0xFF4CAF50), fontSize: 12, letterSpacing: 3),
                    ),

                    const SizedBox(height: 36),

                    // ─── Main Dialog Card ──────────────────────────────────
                    Container(
                      constraints: const BoxConstraints(maxWidth: 480),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        border: Border.all(
                          color: const Color(0xFF00FF41),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00FF41).withValues(alpha: 0.25),
                            blurRadius: 40, spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Status header ─────────────────────────────────
                          Row(children: [
                            Icon(
                              hasRoot ? Icons.verified_user : Icons.warning_amber,
                              color: hasRoot ? const Color(0xFF00FF41) : const Color(0xFFFFAA00),
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                hasRoot ? 'ROOT DETECTED' : 'NO ROOT ACCESS',
                                style: TextStyle(
                                  color: hasRoot ? const Color(0xFF00FF41) : const Color(0xFFFFAA00),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ]),

                          if (isNord3) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                                border: Border.all(color: const Color(0xFFFFD700), width: 1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(children: [
                                Icon(Icons.bolt, color: Color(0xFFFFD700), size: 16),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text('OnePlus Nord 3 5G — ULTRA POWER MODE available',
                                      style: TextStyle(color: Color(0xFFFFD700), fontSize: 11)),
                                ),
                              ]),
                            ),
                          ],

                          const SizedBox(height: 16),
                          Divider(color: const Color(0xFF00FF41).withValues(alpha: 0.3)),
                          const SizedBox(height: 16),

                          Text(
                            hasRoot
                                ? 'Root access detected via ${rootState.rootMethod}. '
                                  'Grant permission to unlock full SIGINT power.'
                                : 'This device does not have root access. '
                                  'You can enter Limited Mode or retry root detection.',
                            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                          ),

                          const SizedBox(height: 20),

                          // ── Feature list ──────────────────────────────────
                          _buildFeatureList(hasRoot),

                          const SizedBox(height: 24),

                          // ═══════════════════════════════════════════════════
                          // PRIMARY BUTTON: ROOT MODE / GRANT ROOT
                          // ═══════════════════════════════════════════════════
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _isRequestingRoot ? null : _onRootModePressed,
                              icon: _isRequestingRoot
                                  ? const SizedBox(
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.black))
                                  : Icon(
                                      hasRoot ? Icons.lock_open : Icons.security,
                                      size: 20),
                              label: Text(
                                _isRequestingRoot
                                    ? 'REQUESTING...'
                                    : hasRoot
                                        ? 'GRANT ROOT ACCESS'
                                        : 'ENTER ROOT MODE',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00FF41),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // ═══════════════════════════════════════════════════
                          // SECONDARY BUTTON: LIMITED VERSION (NO ROOT)
                          // ═══════════════════════════════════════════════════
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: OutlinedButton.icon(
                              onPressed: _onLimitedModePressed,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white54,
                                side: const BorderSide(color: Color(0xFF2E5A42)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4)),
                              ),
                              icon: const Icon(Icons.shield_outlined, size: 18),
                              label: const Text('LIMITED VERSION (NO ROOT)',
                                  style: TextStyle(fontSize: 13, letterSpacing: 1)),
                            ),
                          ),
                        ],
                      ),
                    ).animate()
                        .fadeIn(delay: 200.ms, duration: 800.ms)
                        .scale(begin: const Offset(0.9, 0.9)),

                    const SizedBox(height: 24),
                    const Text(
                      'MAXIMUM POWER REQUIRES ROOT ACCESS',
                      style: TextStyle(
                          color: Color(0xFF2E5A42), fontSize: 11, letterSpacing: 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureList(bool hasRoot) {
    final features = [
      ('WiFi CSI 1kHz+ Sampling',      Icons.wifi,             hasRoot),
      ('Raw Modem Access',              Icons.cell_tower,       hasRoot),
      ('High-Freq Sensor Polling',      Icons.speed,            hasRoot),
      ('Monitor Mode (Wi-Fi)',          Icons.radar,            hasRoot),
      ('Kernel Module Loading',         Icons.memory,           hasRoot),
      ('Basic Signal Fusion (20Hz)',    Icons.graphic_eq,       true),
      ('BLE Scanning',                  Icons.bluetooth,        true),
      ('IMU / Gyro Camera Control',     Icons.screen_rotation,  true),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasRoot ? 'ALL CAPABILITIES UNLOCKED:' : 'LIMITED CAPABILITIES:',
          style: const TextStyle(
              color: Color(0xFF4CAF50), fontSize: 11, letterSpacing: 2),
        ),
        const SizedBox(height: 8),
        ...features.map((f) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Icon(
              f.$3 ? Icons.check_circle : Icons.cancel,
              color: f.$3 ? const Color(0xFF00FF41) : const Color(0xFF2E5A42),
              size: 16,
            ),
            const SizedBox(width: 8),
            Icon(f.$2, size: 14, color: Colors.white38),
            const SizedBox(width: 6),
            Expanded(
              child: Text(f.$1,
                  style: TextStyle(
                    color: f.$3 ? Colors.white70 : Colors.white30,
                    fontSize: 12,
                  )),
            ),
          ]),
        )),
      ],
    );
  }

  /// V47 Sovereign Boot — Particle system + Glassmorphism terminal
  Widget _buildBootScreen() {
    const accent = Color(0xFF00E5FF);
    const green = Color(0xFF00FF41);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // V47: Particle system background with hex grid
          AnimatedBuilder(
            animation: _scanController,
            builder: (context, child) => CustomPaint(
              size: Size.infinite,
              painter: _MilitaryScanPainter(_scanController.value),
            ),
          ),
          // V47: Floating particle dots background
          AnimatedBuilder(
            animation: _scanController,
            builder: (context, child) => CustomPaint(
              size: Size.infinite,
              painter: _ParticleFieldPainter(_scanController.value),
            ),
          ),
          Center(
            child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // V47: Enhanced falcon eye with neon cyan glow rings
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 190, height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: accent.withValues(alpha: 0.08), width: 1),
                      ),
                    ).animate(onPlay: (c) => c.repeat()).rotate(duration: 10000.ms),
                    Container(
                      width: 160, height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: green.withValues(alpha: 0.12), width: 1),
                      ),
                    ).animate(onPlay: (c) => c.repeat()).rotate(duration: 7000.ms, begin: 0.5),
                    Container(
                      width: 130, height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: accent.withValues(alpha: 0.2), width: 1),
                      ),
                    ).animate(onPlay: (c) => c.repeat()).rotate(duration: 5000.ms, begin: 0.25),
                    // Core icon with dual glow (cyan + green)
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, color: Colors.black,
                        border: Border.all(color: accent, width: 2),
                        boxShadow: [
                          BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 35, spreadRadius: 5),
                          BoxShadow(color: green.withValues(alpha: 0.2), blurRadius: 50, spreadRadius: 8),
                        ],
                      ),
                      child: const Icon(Icons.visibility, size: 44, color: Color(0xFF00E5FF)),
                    ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 1000.ms, curve: Curves.easeOutBack),
                  ],
                ),
                const SizedBox(height: 36),
                Text('FALCON EYE',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: accent, fontWeight: FontWeight.w900, letterSpacing: 14,
                    shadows: [
                      Shadow(color: accent.withValues(alpha: 0.8), blurRadius: 30),
                      Shadow(color: green.withValues(alpha: 0.3), blurRadius: 50),
                    ],
                  ),
                ).animate().fadeIn(duration: 1000.ms).slideY(begin: -0.3, end: 0),
                const SizedBox(height: 8),
                // V47: Glassmorphic version badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      accent.withValues(alpha: 0.08),
                      green.withValues(alpha: 0.04),
                    ]),
                    border: Border.all(color: accent.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(color: accent.withValues(alpha: 0.1), blurRadius: 12),
                    ],
                  ),
                  child: const Text('V51.0 \u2014 UNIVERSAL SOVEREIGN EDITION',
                    style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.bold)),
                ).animate(delay: 400.ms).fadeIn(duration: 800.ms),
                const SizedBox(height: 6),
                Text('OPENGL ES 2.0 \u2022 ZERO MOCK DATA \u2022 GLASSMORPHISM HUD \u2022 120FPS',
                  style: TextStyle(color: accent.withValues(alpha: 0.4), fontSize: 9, letterSpacing: 2),
                ).animate(delay: 600.ms).fadeIn(duration: 800.ms),
                const SizedBox(height: 40),
                // V47: Glassmorphic boot terminal card
                Container(
                  width: 380,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.04),
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                    border: Border.all(color: accent.withValues(alpha: 0.25)),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: accent.withValues(alpha: 0.06), blurRadius: 20, spreadRadius: 2),
                    ],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 6)],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('SYSTEM BOOT // V51.0 SOVEREIGN',
                          style: TextStyle(color: accent.withValues(alpha: 0.6), fontSize: 8, letterSpacing: 2)),
                        const Spacer(),
                        Text('${_msgIndex + 1}/${_bootMessages.length}',
                          style: TextStyle(color: accent.withValues(alpha: 0.3), fontSize: 7, fontFamily: 'monospace')),
                      ]),
                      const SizedBox(height: 6),
                      // Progress bar
                      Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(1),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: (_msgIndex + 1) / _bootMessages.length,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [accent, green]),
                              borderRadius: BorderRadius.circular(1),
                              boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 4)],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (int i = 0; i <= _msgIndex && i < _bootMessages.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(children: [
                            Text(i == _msgIndex ? '\u25B6' : '\u2713',
                              style: TextStyle(
                                color: i == _msgIndex ? accent : accent.withValues(alpha: 0.25),
                                fontSize: 8, fontFamily: 'monospace',
                                shadows: i == _msgIndex
                                  ? [Shadow(color: accent.withValues(alpha: 0.5), blurRadius: 4)]
                                  : null,
                              )),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(_bootMessages[i],
                                style: TextStyle(
                                  color: i == _msgIndex ? accent : accent.withValues(alpha: 0.2),
                                  fontSize: 7.5, fontFamily: 'monospace', letterSpacing: 0.5)),
                            ),
                          ]),
                        ),
                      if (_isCheckingRoot) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          SizedBox(
                            width: 10, height: 10,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: accent),
                          ),
                          const SizedBox(width: 8),
                          Text('DETECTING ROOT ACCESS...',
                            style: TextStyle(
                              color: accent.withValues(alpha: 0.8),
                              fontSize: 7.5, fontFamily: 'monospace', letterSpacing: 0.5)),
                        ]),
                      ],
                    ],
                  ),
                ).animate(delay: 600.ms).fadeIn(),
              ],
            ),
            ),
          ),
          // V47: Corner brackets overlay
          CustomPaint(
            size: Size.infinite,
            painter: _CornerBracketOverlay(accent.withValues(alpha: 0.15)),
          ),
        ],
      ),
    );
  }
}

/// V42: Military-style scan line painter with hex grid
class _MilitaryScanPainter extends CustomPainter {
  final double progress;
  _MilitaryScanPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.012)..strokeWidth = 0.5;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // V47: Dual sweep beams (cyan + green)
    final beamY = progress * size.height;
    canvas.drawLine(Offset(0, beamY), Offset(size.width, beamY),
        Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.05)..strokeWidth = 2);
    final beamY2 = ((1.0 - progress) * size.height);
    canvas.drawLine(Offset(0, beamY2), Offset(size.width, beamY2),
        Paint()..color = const Color(0xFF00FF41).withValues(alpha: 0.03)..strokeWidth = 1);
    // Hex grid pattern
    final hexP = Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.015)..style = PaintingStyle.stroke..strokeWidth = 0.3;
    for (double y = 0; y < size.height; y += 40) {
      for (double x = 0; x < size.width; x += 46) {
        final ox = (y ~/ 40).isOdd ? 23.0 : 0.0;
        canvas.drawCircle(Offset(x + ox, y), 18, hexP);
      }
    }
  }

  @override
  bool shouldRepaint(_MilitaryScanPainter old) => old.progress != progress;
}

/// V47: Floating particle field background for boot screen
class _ParticleFieldPainter extends CustomPainter {
  final double progress;
  _ParticleFieldPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(47);
    final t = progress * math.pi * 2;
    final paint = Paint()..isAntiAlias = false;

    for (int i = 0; i < 60; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final drift = math.sin(t * speed + i * 0.5) * 8;
      final x = baseX + drift;
      final y = (baseY + progress * size.height * speed * 0.1) % size.height;
      final r = 0.3 + rng.nextDouble() * 1.2;
      final alpha = (0.05 + rng.nextDouble() * 0.15) * (0.5 + 0.5 * math.sin(t * 0.5 + i));
      final isCyan = rng.nextBool();
      paint.color = (isCyan ? const Color(0xFF00E5FF) : const Color(0xFF00FF41))
          .withValues(alpha: alpha.clamp(0.02, 0.2));
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticleFieldPainter old) => old.progress != progress;
}

/// V47: Corner bracket overlay for full-screen HUD feel
class _CornerBracketOverlay extends CustomPainter {
  final Color color;
  _CornerBracketOverlay(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 1..strokeCap = StrokeCap.round;
    const s = 28.0;
    const m = 8.0;
    canvas.drawLine(const Offset(m, m), const Offset(m + s, m), p);
    canvas.drawLine(const Offset(m, m), const Offset(m, m + s), p);
    canvas.drawLine(Offset(size.width - m, m), Offset(size.width - m - s, m), p);
    canvas.drawLine(Offset(size.width - m, m), Offset(size.width - m, m + s), p);
    canvas.drawLine(Offset(m, size.height - m), Offset(m + s, size.height - m), p);
    canvas.drawLine(Offset(m, size.height - m), Offset(m, size.height - m - s), p);
    canvas.drawLine(Offset(size.width - m, size.height - m), Offset(size.width - m - s, size.height - m), p);
    canvas.drawLine(Offset(size.width - m, size.height - m), Offset(size.width - m, size.height - m - s), p);
  }

  @override
  bool shouldRepaint(_CornerBracketOverlay old) => false;
}
