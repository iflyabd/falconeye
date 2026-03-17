import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root Access Level
enum RootAccessLevel {
  none,
  limited,
  full,
  magisk,
  shizuku,
}

/// Root Permission State
class RootPermissionState {
  final RootAccessLevel accessLevel;
  final bool isRooted;
  final bool suBinaryAvailable;
  final bool magiskDetected;
  final bool shizukuAvailable;
  final String rootMethod;
  final String errorMessage;
  final bool permissionGranted;
  final bool isOnePlusNord3;
  final bool ultraPowerMode;

  const RootPermissionState({
    this.accessLevel = RootAccessLevel.none,
    this.isRooted = false,
    this.suBinaryAvailable = false,
    this.magiskDetected = false,
    this.shizukuAvailable = false,
    this.rootMethod = 'None',
    this.errorMessage = '',
    this.permissionGranted = false,
    this.isOnePlusNord3 = false,
    this.ultraPowerMode = false,
  });

  RootPermissionState copyWith({
    RootAccessLevel? accessLevel,
    bool? isRooted,
    bool? suBinaryAvailable,
    bool? magiskDetected,
    bool? shizukuAvailable,
    String? rootMethod,
    String? errorMessage,
    bool? permissionGranted,
    bool? isOnePlusNord3,
    bool? ultraPowerMode,
  }) => RootPermissionState(
    accessLevel: accessLevel ?? this.accessLevel,
    isRooted: isRooted ?? this.isRooted,
    suBinaryAvailable: suBinaryAvailable ?? this.suBinaryAvailable,
    magiskDetected: magiskDetected ?? this.magiskDetected,
    shizukuAvailable: shizukuAvailable ?? this.shizukuAvailable,
    rootMethod: rootMethod ?? this.rootMethod,
    errorMessage: errorMessage ?? this.errorMessage,
    permissionGranted: permissionGranted ?? this.permissionGranted,
    isOnePlusNord3: isOnePlusNord3 ?? this.isOnePlusNord3,
    ultraPowerMode: ultraPowerMode ?? this.ultraPowerMode,
  );
}

/// Real Root Permission Service
class RootPermissionService extends Notifier<RootPermissionState> {
  @override
  RootPermissionState build() => const RootPermissionState();

  /// Manually set root access (used when entering limited mode)
  void setLimitedMode() {
    state = state.copyWith(
      isRooted: false,
      permissionGranted: false,
      accessLevel: RootAccessLevel.limited,
    );
  }

  /// Manually grant full root access (for when root is confirmed)
  void setFullRootGranted() {
    state = state.copyWith(
      isRooted: true,
      permissionGranted: true,
      accessLevel: RootAccessLevel.full,
    );
  }

  Future<void> detectRootAccess() async {
    // On web/desktop, root detection is not applicable
    if (kIsWeb) {
      state = state.copyWith(
        isRooted: false,
        errorMessage: 'Root detection not available on web',
        accessLevel: RootAccessLevel.none,
      );
      return;
    }

    if (!Platform.isAndroid) {
      state = state.copyWith(
        isRooted: false,
        errorMessage: 'Root detection only on Android',
        accessLevel: RootAccessLevel.none,
      );
      return;
    }

    try {
      final hasSu = await _checkSuBinary();
      final magisk = await _checkMagisk();
      final shizuku = await _checkShizuku();
      final nord3 = await _checkOnePlusNord3();

      RootAccessLevel level = RootAccessLevel.none;
      String method = 'None';

      if (magisk) {
        level = RootAccessLevel.magisk;
        method = 'Magisk';
      } else if (hasSu) {
        level = RootAccessLevel.full;
        method = 'SuperSU / KernelSU';
      } else if (shizuku) {
        level = RootAccessLevel.shizuku;
        method = 'Shizuku';
      }

      state = state.copyWith(
        isRooted: hasSu || magisk,
        suBinaryAvailable: hasSu,
        magiskDetected: magisk,
        shizukuAvailable: shizuku,
        accessLevel: level,
        rootMethod: method,
        isOnePlusNord3: nord3,
        ultraPowerMode: (hasSu || magisk) && nord3,
      );
    } catch (e) {
      state = state.copyWith(
        isRooted: false,
        errorMessage: e.toString(),
        accessLevel: RootAccessLevel.none,
      );
    }
  }

  Future<bool> requestRootPermission() async {
    // On web, root is never available
    if (kIsWeb) return false;

    try {
      // Use Process.run directly — process_run's Shell class is desktop-oriented
      // and fails silently on Android even when Magisk grants root.
      final result = await Process.run('su', ['-c', 'id']);
      final output = result.stdout.toString();
      if (output.contains('uid=0')) {
        state = state.copyWith(
          permissionGranted: true,
          isRooted: true,
          accessLevel: RootAccessLevel.full,
          ultraPowerMode: state.isOnePlusNord3,
        );
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Root request failed: $e');
      }
    }
    return false;
  }

  Future<bool> _checkSuBinary() async {
    if (kIsWeb) return false;
    final paths = ['/sbin/su', '/system/bin/su', '/system/xbin/su',
                   '/data/local/xbin/su', '/data/local/bin/su'];
    for (final path in paths) {
      if (await File(path).exists()) return true;
    }
    return false;
  }

  Future<bool> _checkMagisk() async {
    if (kIsWeb) return false;
    // Cover Magisk v20–v27+ path layouts
    final magiskPaths = [
      '/sbin/.magisk',
      '/sbin/magisk',
      '/data/adb/magisk',
      '/data/adb/magisk.db',   // present on Magisk v24+
      '/data/adb/modules',     // always exists when Magisk is installed
      '/data/adb/ksu',         // KernelSU overlay
    ];
    for (final path in magiskPaths) {
      if (await Directory(path).exists()) return true;
      if (await File(path).exists()) return true;
    }
    // Fallback: check if the magisk binary is callable
    try {
      final result = await Process.run('magisk', ['--version']);
      if (result.exitCode == 0) return true;
    } catch (_) {}
    return false;
  }

  Future<bool> _checkShizuku() async {
    if (kIsWeb) return false;
    try {
      final result = await Process.run('pm', ['list', 'packages', 'moe.shizuku.privileged.api']);
      return result.stdout.toString().contains('moe.shizuku');
    } catch (_) {
      return false;
    }
  }

  Future<bool> _checkOnePlusNord3() async {
    if (kIsWeb) return false;
    try {
      final result = await Process.run('getprop', ['ro.product.model']);
      final model = result.stdout.toString().toLowerCase();
      return model.contains('nord 3') || model.contains('cph2493');
    } catch (_) {
      return false;
    }
  }
}

final rootPermissionProvider =
    NotifierProvider<RootPermissionService, RootPermissionState>(() {
  return RootPermissionService();
});
