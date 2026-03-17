// =============================================================================
// FALCON EYE V48.1 — METALLURGIC RADAR SERVICE (Stub)
// Magnetometer susceptibility analysis for element identification
// =============================================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MetallurgicRadarState {
  final bool isActive;
  final double scanDepth;
  final List<String> detectedElements;
  final double magneticSusceptibility;

  const MetallurgicRadarState({
    this.isActive = false,
    this.scanDepth = 2.0,
    this.detectedElements = const [],
    this.magneticSusceptibility = 0,
  });

  // V47: Additional getters
  double get scanDepthCm => scanDepth * 100;

  MetallurgicRadarState copyWith({
    bool? isActive, double? scanDepth,
    List<String>? detectedElements, double? magneticSusceptibility,
  }) => MetallurgicRadarState(
    isActive: isActive ?? this.isActive,
    scanDepth: scanDepth ?? this.scanDepth,
    detectedElements: detectedElements ?? this.detectedElements,
    magneticSusceptibility: magneticSusceptibility ?? this.magneticSusceptibility,
  );
}

class MetallurgicRadarService extends Notifier<MetallurgicRadarState> {
  @override
  MetallurgicRadarState build() => const MetallurgicRadarState();

  void start() => state = state.copyWith(isActive: true);
  void stop() => state = state.copyWith(isActive: false);
  void setScanDepth(double v) => state = state.copyWith(scanDepth: v);
}

final metallurgicRadarProvider =
    NotifierProvider<MetallurgicRadarService, MetallurgicRadarState>(MetallurgicRadarService.new);
