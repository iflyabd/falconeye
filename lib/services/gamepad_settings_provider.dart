// =============================================================================
// FALCON EYE V49.9 — GAMEPAD SETTINGS PROVIDER
// Controls position, side, size of the floating 3D movement gamepad
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum GamepadSide { left, right }

class GamepadSettings {
  final GamepadSide side;
  final double size;             // 0.7 = small, 1.0 = medium, 1.3 = large
  final double verticalPosition; // 0.0 (top) → 1.0 (bottom) fraction
  final double moveSensitivity;  // 0.02 → 0.12
  final bool visible;

  const GamepadSettings({
    this.side = GamepadSide.right,
    this.size = 1.0,
    this.verticalPosition = 0.6,
    this.moveSensitivity = 0.05,
    this.visible = true,
  });

  GamepadSettings copyWith({
    GamepadSide? side,
    double? size,
    double? verticalPosition,
    double? moveSensitivity,
    bool? visible,
  }) => GamepadSettings(
    side: side ?? this.side,
    size: size ?? this.size,
    verticalPosition: verticalPosition ?? this.verticalPosition,
    moveSensitivity: moveSensitivity ?? this.moveSensitivity,
    visible: visible ?? this.visible,
  );

  // Button base size in logical pixels
  double get btnSize => 44.0 * size;
  // Gap between buttons
  double get gap => 4.0 * size;
}

class GamepadSettingsNotifier extends Notifier<GamepadSettings> {
  @override
  GamepadSettings build() => const GamepadSettings();

  void setSide(GamepadSide side) => state = state.copyWith(side: side);
  void setSize(double v) => state = state.copyWith(size: v.clamp(0.6, 1.5));
  void setVerticalPosition(double v) => state = state.copyWith(verticalPosition: v.clamp(0.1, 0.9));
  void setSensitivity(double v) => state = state.copyWith(moveSensitivity: v.clamp(0.01, 0.15));
  void setVisible(bool v) => state = state.copyWith(visible: v);
}

final gamepadSettingsProvider = NotifierProvider<GamepadSettingsNotifier, GamepadSettings>(
  () => GamepadSettingsNotifier(),
);

// ─── Move directions ──────────────────────────────────────────────────────────
enum MoveDir { forward, backward, strafeLeft, strafeRight, altUp, altDown }
