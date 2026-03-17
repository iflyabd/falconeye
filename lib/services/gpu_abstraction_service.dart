// =============================================================================
// FALCON EYE V48.1 — GPU HARDWARE ABSTRACTION SERVICE
// Detects GPU chipset (Adreno/Mali/unknown), selects rendering tier,
// and provides dynamic point budget + FPS target based on device capability.
// Fallback: if no GPU detected or Web, uses CustomPainter software renderer.
// =============================================================================
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:process_run/shell.dart';
import 'native_renderer_bridge.dart';

class GpuInfo {
  final String chipset;
  final String gpuName;
  final GpuTier tier;
  final int maxPoints;
  final int targetFps;
  final bool nativeAvailable;

  const GpuInfo({
    required this.chipset,
    required this.gpuName,
    required this.tier,
    required this.maxPoints,
    required this.targetFps,
    required this.nativeAvailable,
  });

  factory GpuInfo.unknown() => const GpuInfo(
        chipset: 'Unknown',
        gpuName: 'Software Fallback',
        tier: GpuTier.tier3,
        maxPoints: 10000,
        targetFps: 30,
        nativeAvailable: false,
      );
}

class GpuAbstractionService extends Notifier<GpuInfo> {
  @override
  GpuInfo build() {
    _detect();
    return GpuInfo.unknown();
  }

  Future<void> _detect() async {
    if (kIsWeb) {
      state = GpuInfo.unknown();
      return;
    }

    try {
      if (!Platform.isAndroid) {
        state = GpuInfo.unknown();
        return;
      }

      // Read chipset
      final shell = Shell(verbose: false);
      String chipset = '';
      try {
        final r = await shell.run('getprop ro.board.platform');
        chipset = r.map((x) => x.stdout.toString()).join().trim();
      } catch (_) {}

      if (chipset.isEmpty) {
        try {
          final r = await shell.run('getprop ro.hardware');
          chipset = r.map((x) => x.stdout.toString()).join().trim();
        } catch (_) {}
      }

      // Read GPU name from /sys or getprop
      String gpuName = 'Unknown GPU';
      try {
        final r = await shell.run(
            'cat /sys/class/kgsl/kgsl-3d0/gpu_model 2>/dev/null || getprop ro.hardware.egl 2>/dev/null');
        final name = r.map((x) => x.stdout.toString()).join().trim();
        if (name.isNotEmpty) gpuName = name;
      } catch (_) {}

      // Detect tier
      final bridge = NativeRendererBridge.instance;
      bridge.detectGpuTier(chipset);
      final tier = bridge.gpuTier;

      state = GpuInfo(
        chipset: chipset.isNotEmpty ? chipset : 'Unknown',
        gpuName: gpuName,
        tier: tier,
        maxPoints: tier.maxPoints,
        targetFps: tier.targetFps,
        nativeAvailable: bridge.isAvailable,
      );

      if (kDebugMode) {
        debugPrint('[GPU] Chipset: ${state.chipset}');
        debugPrint('[GPU] GPU: ${state.gpuName}');
        debugPrint('[GPU] Tier: ${tier.label}');
        debugPrint('[GPU] Max points: ${state.maxPoints}');
        debugPrint('[GPU] Native available: ${state.nativeAvailable}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GPU] Detection failed: $e');
      state = GpuInfo.unknown();
    }
  }

  Future<void> rescan() => _detect();
}

final gpuAbstractionProvider =
    NotifierProvider<GpuAbstractionService, GpuInfo>(GpuAbstractionService.new);
