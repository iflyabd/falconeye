import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  FALCON EYE V48.1 — CAMERA BACKGROUND SERVICE
//  Optional real-time camera feed as AR background layer behind 3D canvas.
//  Disabled by default. Toggled via FKey.cameraBackground in settings/side menu.
//  Zero-allocation: controller is only created when enabled, disposed on disable.
// ═══════════════════════════════════════════════════════════════════════════════

class CameraBackgroundState {
  final bool isEnabled;
  final bool isInitialized;
  final bool hasError;
  final String? errorMessage;
  final CameraController? controller;

  const CameraBackgroundState({
    this.isEnabled = false,
    this.isInitialized = false,
    this.hasError = false,
    this.errorMessage,
    this.controller,
  });

  CameraBackgroundState copyWith({
    bool? isEnabled,
    bool? isInitialized,
    bool? hasError,
    String? errorMessage,
    CameraController? controller,
    bool clearController = false,
    bool clearError = false,
  }) {
    return CameraBackgroundState(
      isEnabled: isEnabled ?? this.isEnabled,
      isInitialized: isInitialized ?? this.isInitialized,
      hasError: hasError ?? this.hasError,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      controller: clearController ? null : (controller ?? this.controller),
    );
  }
}

class CameraBackgroundService extends Notifier<CameraBackgroundState> {
  @override
  CameraBackgroundState build() => const CameraBackgroundState();

  Future<void> enable() async {
    if (state.isEnabled && state.isInitialized) return;

    state = state.copyWith(isEnabled: true, isInitialized: false, hasError: false, clearError: true);

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        state = state.copyWith(hasError: true, errorMessage: 'No camera found on device', isEnabled: false);
        return;
      }

      // Prefer back camera; fallback to first available
      final camDesc = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camDesc,
        ResolutionPreset.medium, // Medium = good perf/quality balance for background
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (!state.isEnabled) {
        // Was disabled while initializing
        await controller.dispose();
        return;
      }

      state = state.copyWith(
        isEnabled: true,
        isInitialized: true,
        controller: controller,
        hasError: false,
        clearError: true,
      );
    } on CameraException catch (e) {
      state = state.copyWith(
        hasError: true,
        errorMessage: e.description ?? 'Camera error: ${e.code}',
        isEnabled: false,
        isInitialized: false,
      );
    } catch (e) {
      state = state.copyWith(
        hasError: true,
        errorMessage: 'Failed to start camera: $e',
        isEnabled: false,
        isInitialized: false,
      );
    }
  }

  Future<void> disable() async {
    final ctrl = state.controller;
    state = state.copyWith(
      isEnabled: false,
      isInitialized: false,
      clearController: true,
      clearError: true,
    );
    await ctrl?.dispose();
  }

  Future<void> setEnabled(bool value) async {
    if (value) {
      await enable();
    } else {
      await disable();
    }
  }

  // camera controller is disposed in disable()
}

final cameraBackgroundProvider =
    NotifierProvider<CameraBackgroundService, CameraBackgroundState>(
  () => CameraBackgroundService(),
);
