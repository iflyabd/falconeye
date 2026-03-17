import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/root_permission_service.dart';
import '../theme.dart';

class RootPermissionDialogPage extends ConsumerStatefulWidget {
  final VoidCallback onRootGranted;
  final VoidCallback onLimitedMode;

  const RootPermissionDialogPage({
    super.key,
    required this.onRootGranted,
    required this.onLimitedMode,
  });

  @override
  ConsumerState<RootPermissionDialogPage> createState() =>
      _RootPermissionDialogPageState();
}

class _RootPermissionDialogPageState
    extends ConsumerState<RootPermissionDialogPage> {
  bool _isChecking = true;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _checkRoot();
  }

  Future<void> _checkRoot() async {
    await ref.read(rootPermissionProvider.notifier).detectRootAccess();
    if (mounted) setState(() => _isChecking = false);
  }

  Future<void> _requestRoot() async {
    setState(() => _isRequesting = true);
    final granted =
        await ref.read(rootPermissionProvider.notifier).requestRootPermission();
    if (!mounted) return;
    setState(() => _isRequesting = false);
    if (granted) {
      widget.onRootGranted();
    } else {
      _showDeniedDialog();
    }
  }

  void _showDeniedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFFF3333), width: 2),
        ),
        title: const Row(children: [
          Icon(Icons.error_outline, color: Color(0xFFFF3333), size: 28),
          SizedBox(width: 12),
          Text('ROOT DENIED', style: TextStyle(color: Color(0xFFFF3333))),
        ]),
        content: const Text(
          'Root permission was denied by the system.\n\n'
          'Make sure Magisk / KernelSU is installed and has granted '
          'permission to this app. Try again, or continue in Limited Mode.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onLimitedMode();
            },
            child: const Text('LIMITED MODE',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _requestRoot();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF41),
                foregroundColor: Colors.black),
            child: const Text('TRY AGAIN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rootState = ref.watch(rootPermissionProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Particle background (gradient fallback - particles_flutter not in pubspec)
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
                    // ─── Logo ─────────────────────────────────────────────
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
                      child: _isChecking
                          ? _buildChecking()
                          : _buildPermissionUI(rootState),
                    ).animate()
                        .fadeIn(delay: 500.ms, duration: 800.ms)
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

  Widget _buildChecking() {
    return Column(children: [
      const CircularProgressIndicator(color: Color(0xFF00FF41), strokeWidth: 2),
      const SizedBox(height: 16),
      const Text('SCANNING SYSTEM...',
          style: TextStyle(color: Color(0xFF00FF41), letterSpacing: 2, fontSize: 14)),
      const SizedBox(height: 6),
      const Text('Detecting root access and hardware capabilities',
          style: TextStyle(color: Colors.white54, fontSize: 12)),
    ]);
  }

  Widget _buildPermissionUI(RootPermissionState rootState) {
    final hasRoot = rootState.isRooted;
    final isNord3 = rootState.isOnePlusNord3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Status header ──────────────────────────────────────────────────
        Row(children: [
          Icon(
            hasRoot ? Icons.verified_user : Icons.warning_amber,
            color: hasRoot ? const Color(0xFF00FF41) : const Color(0xFFFFAA00),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasRoot ? 'ROOT DETECTED' : 'ROOT ACCESS REQUIRED',
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
              Text('OnePlus Nord 3 5G detected — ULTRA POWER MODE available',
                  style: TextStyle(color: Color(0xFFFFD700), fontSize: 11)),
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
              : 'This device does not appear to have root access. '
                'You can still try requesting root — if Magisk or KernelSU '
                'is installed it will prompt you now.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),

        const SizedBox(height: 20),

        // ── Feature list ───────────────────────────────────────────────────
        _buildFeatures(hasRoot),

        const SizedBox(height: 24),

        // ── PRIMARY: REQUEST ROOT (always shown) ──────────────────────────
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isRequesting ? null : _requestRoot,
            icon: _isRequesting
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.lock_open, size: 20),
            label: Text(
              _isRequesting ? 'REQUESTING...' : 'GRANT ROOT ACCESS',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
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

        // ── SECONDARY: Continue without root ──────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton(
            onPressed: widget.onLimitedMode,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white54,
              side: const BorderSide(color: Color(0xFF2E5A42)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('CONTINUE WITHOUT ROOT',
                style: TextStyle(fontSize: 13, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatures(bool hasRoot) {
    final features = [
      ('WiFi CSI 1kHz+ Sampling',      Icons.wifi,        hasRoot),
      ('Raw Modem Access',              Icons.cell_tower,  hasRoot),
      ('High-Freq Sensor Polling',      Icons.speed,       hasRoot),
      ('Monitor Mode (Wi-Fi)',          Icons.radar,       hasRoot),
      ('Kernel Module Loading',         Icons.memory,      hasRoot),
      ('Basic Signal Fusion (20Hz)',    Icons.graphic_eq,  true),
      ('BLE Scanning',                  Icons.bluetooth,   true),
      ('IMU / Gyro Camera Control',     Icons.screen_rotation, true),
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
            Text(f.$1,
                style: TextStyle(
                  color: f.$3 ? Colors.white70 : Colors.white30,
                  fontSize: 12,
                )),
          ]),
        )),
      ],
    );
  }
}
