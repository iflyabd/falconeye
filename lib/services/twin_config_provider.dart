// ═══════════════════════════════════════════════════════════════════════════
//  FALCON EYE V42 — TWIN CONFIG PROVIDER
//  Persistent Riverpod state for Digital Twin Engine user settings.
//  Writes to SharedPreferences on every change so settings survive restarts.
// ═══════════════════════════════════════════════════════════════════════════
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'digital_twin_engine.dart';

// ─── Config state ─────────────────────────────────────────────────────────────
class TwinConfig {
  final double pointSize;       // 0.4 → 2.2
  final double clusterDensity;  // 0.0 → 1.0
  final double dbscanEpsilon;   // 0.2 → 2.0
  final bool kalmanEnabled;
  final bool aiInterpolation;
  final bool useDBSCAN;

  const TwinConfig({
    this.pointSize = 1.0,
    this.clusterDensity = 0.7,
    this.dbscanEpsilon = 0.6,
    this.kalmanEnabled = true,
    this.aiInterpolation = true,
    this.useDBSCAN = true,
  });

  TwinConfig copyWith({
    double? pointSize,
    double? clusterDensity,
    double? dbscanEpsilon,
    bool? kalmanEnabled,
    bool? aiInterpolation,
    bool? useDBSCAN,
  }) => TwinConfig(
    pointSize: pointSize ?? this.pointSize,
    clusterDensity: clusterDensity ?? this.clusterDensity,
    dbscanEpsilon: dbscanEpsilon ?? this.dbscanEpsilon,
    kalmanEnabled: kalmanEnabled ?? this.kalmanEnabled,
    aiInterpolation: aiInterpolation ?? this.aiInterpolation,
    useDBSCAN: useDBSCAN ?? this.useDBSCAN,
  );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────
class TwinConfigNotifier extends Notifier<TwinConfig> {
  static const _kPrefix = 'twin_config_v42_';

  @override
  TwinConfig build() {
    // Async load happens in init; return defaults while loading
    _loadFromPrefs();
    return const TwinConfig();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final cfg = TwinConfig(
      pointSize:      prefs.getDouble('${_kPrefix}point_size') ?? 1.0,
      clusterDensity: prefs.getDouble('${_kPrefix}cluster_density') ?? 0.7,
      dbscanEpsilon:  prefs.getDouble('${_kPrefix}dbscan_epsilon') ?? 0.6,
      kalmanEnabled:  prefs.getBool('${_kPrefix}kalman') ?? true,
      aiInterpolation: prefs.getBool('${_kPrefix}ai_interp') ?? true,
      useDBSCAN:      prefs.getBool('${_kPrefix}use_dbscan') ?? true,
    );
    state = cfg;
    _applyToEngine(cfg);
  }

  Future<void> _saveToPrefs(TwinConfig cfg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${_kPrefix}point_size', cfg.pointSize);
    await prefs.setDouble('${_kPrefix}cluster_density', cfg.clusterDensity);
    await prefs.setDouble('${_kPrefix}dbscan_epsilon', cfg.dbscanEpsilon);
    await prefs.setBool('${_kPrefix}kalman', cfg.kalmanEnabled);
    await prefs.setBool('${_kPrefix}ai_interp', cfg.aiInterpolation);
    await prefs.setBool('${_kPrefix}use_dbscan', cfg.useDBSCAN);
  }

  void _applyToEngine(TwinConfig cfg) {
    digitalTwinEngine.updateConfig(
      pointSize: cfg.pointSize,
      clusteringDensity: cfg.clusterDensity,
      epsilon: cfg.dbscanEpsilon,
      kalman: cfg.kalmanEnabled,
      aiInterp: cfg.aiInterpolation,
      useDBSCAN: cfg.useDBSCAN,
    );
  }

  void update(TwinConfig cfg) {
    state = cfg;
    _applyToEngine(cfg);
    _saveToPrefs(cfg);
  }

  void setPointSize(double v) => update(state.copyWith(pointSize: v));
  void setClusterDensity(double v) => update(state.copyWith(clusterDensity: v));
  void setDbscanEpsilon(double v) => update(state.copyWith(dbscanEpsilon: v));
  void setKalman(bool v) => update(state.copyWith(kalmanEnabled: v));
  void setAiInterp(bool v) => update(state.copyWith(aiInterpolation: v));
  void setUseDBSCAN(bool v) => update(state.copyWith(useDBSCAN: v));
}

final twinConfigProvider = NotifierProvider<TwinConfigNotifier, TwinConfig>(
  () => TwinConfigNotifier(),
);
