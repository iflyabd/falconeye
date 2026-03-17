import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/foundation.dart';

class OrientationState {
  final double roll;  // rotation around X (phi)
  final double pitch; // rotation around Y (theta)
  final double yaw;   // rotation around Z (psi)
  final bool hasMag;  // whether magnetometer contributed to yaw

  const OrientationState({
    required this.roll,
    required this.pitch,
    required this.yaw,
    required this.hasMag,
  });

  OrientationState copyWith({double? roll, double? pitch, double? yaw, bool? hasMag}) {
    return OrientationState(
      roll: roll ?? this.roll,
      pitch: pitch ?? this.pitch,
      yaw: yaw ?? this.yaw,
      hasMag: hasMag ?? this.hasMag,
    );
  }

  static OrientationState zero() => const OrientationState(roll: 0, pitch: 0, yaw: 0, hasMag: false);
}

class ImuFusionService extends Notifier<OrientationState> {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  // Latest raw samples
  AccelerometerEvent? _accel;
  MagnetometerEvent? _mag;

  // Filter state
  double _roll = 0;  // radians
  double _pitch = 0; // radians
  double _yaw = 0;   // radians
  int? _lastGyroMicros;

  // Complementary filter gains
  static const double gyroTrust = 0.98; // 98% gyro, 2% accel/mag per update
  static const double accelTrust = 1.0 - gyroTrust;

  @override
  OrientationState build() {
    state = OrientationState.zero();
    _start();
    ref.onDispose(_disposeStreams);
    return state;
  }

  void _start() {
    // Guard against unsupported platforms (e.g., Web without motion permissions)
    try {
      _accelSub = accelerometerEventStream()
          .handleError((e, st) {
            if (kDebugMode) {
              // Silently degrade on unsupported contexts
              // print('Accelerometer error: $e');
            }
          })
          .listen((e) {
            _accel = e;
            _updateFromAccelMag();
          });
    } catch (e) {
      if (kDebugMode) {
        // print('Accelerometer subscription failed: $e');
      }
    }

    try {
      _magSub = magnetometerEventStream()
          .handleError((e, st) {
            if (kDebugMode) {
              // print('Magnetometer error: $e');
            }
          })
          .listen((m) {
            _mag = m;
            _updateFromAccelMag();
          });
    } catch (e) {
      if (kDebugMode) {
        // print('Magnetometer subscription failed: $e');
      }
    }

    try {
      _gyroSub = gyroscopeEventStream()
          .handleError((e, st) {
            if (kDebugMode) {
              // print('Gyroscope error: $e');
            }
          })
          .listen((g) {
            // g.x/y/z are in rad/s
            final nowMicros = DateTime.now().microsecondsSinceEpoch;
            double dt = 0.0;
            if (_lastGyroMicros != null) {
              dt = (nowMicros - _lastGyroMicros!) / 1e6; // seconds
              // Integrate gyro
              _roll += g.x * dt;
              _pitch += g.y * dt;
              _yaw += g.z * dt;
              _normalizeAngles();
              // Apply small drift correction from accel/mag snapshot
              final am = _estimateFromAccelMag();
              if (am != null) {
                _roll = gyroTrust * _roll + accelTrust * am[0];
                _pitch = gyroTrust * _pitch + accelTrust * am[1];
                // Blend yaw only if we have magnetometer
                if (am.length > 2) {
                  // Shortest-angle blend for yaw wrap-around
                  final double dy = _shortestAngleDiff(_yaw, am[2]);
                  _yaw = _yaw + accelTrust * dy;
                }
              }
              _emit();
            }
            _lastGyroMicros = nowMicros;
          });
    } catch (e) {
      if (kDebugMode) {
        // print('Gyroscope subscription failed: $e');
      }
    }
  }

  void _disposeStreams() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _magSub?.cancel();
  }

  /// Real magnetometer toggle — enables/disables the sensor stream.
  /// When disabled: _mag is cleared, yaw falls back to gyro-only integration.
  void enableMagnetometer(bool enabled) {
    if (enabled) {
      if (_magSub != null) return; // already running
      try {
        _magSub = magnetometerEventStream().listen((m) {
          _mag = m;
          _updateFromAccelMag();
        }, onError: (_) {});
      } catch (_) {}
    } else {
      _magSub?.cancel();
      _magSub = null;
      _mag = null; // clear stored reading — yaw now gyro-only
      _emit();
    }
  }

  // Use accelerometer (gravity) and magnetometer to create an absolute frame estimate
  // Returns [roll, pitch, yaw] in radians when both available; [roll, pitch] if magnetometer missing
  List<double>? _estimateFromAccelMag() {
    final a = _accel;
    if (a == null) return null;

    // Normalize gravity vector
    final double ax = a.x, ay = a.y, az = a.z;
    final double gNorm = math.sqrt(ax * ax + ay * ay + az * az);
    if (gNorm == 0) return null;
    final double nx = ax / gNorm, ny = ay / gNorm, nz = az / gNorm;

    // Derive roll and pitch from gravity
    // Assuming device coordinates: x-right, y-up, z-out of screen (approx)
    final double roll = math.atan2(ny, nz);
    final double pitch = math.atan2(-nx, math.sqrt(ny * ny + nz * nz));

    // If no magnetometer yet, return roll/pitch only
    final m = _mag;
    if (m == null) return [roll, pitch];

    // Tilt-compensated yaw using magnetometer
    // Normalize magnetic vector
    final double mx = m.x, my = m.y, mz = m.z;
    final double mNorm = math.sqrt(mx * mx + my * my + mz * mz);
    if (mNorm == 0) return [roll, pitch];
    final double mxn = mx / mNorm, myn = my / mNorm, mzn = mz / mNorm;

    // Tilt compensation
    // Ref: yaw = atan2(My * cos(roll) - Mz * sin(roll), Mx * cos(pitch) + My * sin(roll) * sin(pitch) + Mz * cos(roll) * sin(pitch))
    final double sinR = math.sin(roll), cosR = math.cos(roll);
    final double sinP = math.sin(pitch), cosP = math.cos(pitch);
    final double xh = mxn * cosP + myn * sinR * sinP + mzn * cosR * sinP;
    final double yh = myn * cosR - mzn * sinR;
    double yaw = math.atan2(-yh, xh); // negative to align with compass heading convention
    yaw = _wrapPi(yaw);

    return [roll, pitch, yaw];
  }

  void _updateFromAccelMag() {
    final am = _estimateFromAccelMag();
    if (am == null) return;

    // If gyro hasn't started, snap to accel/mag quickly
    if (_lastGyroMicros == null) {
      _roll = am[0];
      _pitch = am[1];
      if (am.length > 2) _yaw = am[2];
      _emit();
    }
  }

  void _emit() {
    state = state.copyWith(
      roll: _roll,
      pitch: _pitch,
      yaw: _yaw,
      hasMag: _mag != null,
    );
  }

  void _normalizeAngles() {
    _roll = _wrapPi(_roll);
    _pitch = _wrapPi(_pitch);
    _yaw = _wrapPi(_yaw);
  }

  double _wrapPi(double a) {
    while (a > math.pi) a -= 2 * math.pi;
    while (a < -math.pi) a += 2 * math.pi;
    return a;
  }

  double _shortestAngleDiff(double from, double to) {
    double diff = _wrapPi(to - from);
    return diff;
  }
}

final imuFusionProvider = NotifierProvider<ImuFusionService, OrientationState>(() => ImuFusionService());
