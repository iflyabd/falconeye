import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'imu_fusion_service.dart';

/// Camera orientation for 3D rendering
class CameraOrientation {
  final double yaw;   // Rotation around vertical axis (left-right look)
  final double pitch; // Rotation around horizontal axis (up-down look)
  final double roll;  // Rotation around forward axis (tilt)
  
  const CameraOrientation({
    required this.yaw,
    required this.pitch,
    required this.roll,
  });
  
  CameraOrientation copyWith({double? yaw, double? pitch, double? roll}) {
    return CameraOrientation(
      yaw: yaw ?? this.yaw,
      pitch: pitch ?? this.pitch,
      roll: roll ?? this.roll,
    );
  }
  
  static CameraOrientation zero() => const CameraOrientation(yaw: 0, pitch: 0, roll: 0);
}

/// Gyroscopic camera control state
class GyroscopicCameraState {
  final bool isEnabled;
  final bool isCalibrated;
  final CameraOrientation camera;
  final CameraOrientation calibrationOffset;
  final bool includeRoll;
  final double sensitivity;
  final bool touchControlEnabled;
  
  const GyroscopicCameraState({
    required this.isEnabled,
    required this.isCalibrated,
    required this.camera,
    required this.calibrationOffset,
    required this.includeRoll,
    required this.sensitivity,
    required this.touchControlEnabled,
  });
  
  GyroscopicCameraState copyWith({
    bool? isEnabled,
    bool? isCalibrated,
    CameraOrientation? camera,
    CameraOrientation? calibrationOffset,
    bool? includeRoll,
    double? sensitivity,
    bool? touchControlEnabled,
  }) {
    return GyroscopicCameraState(
      isEnabled: isEnabled ?? this.isEnabled,
      isCalibrated: isCalibrated ?? this.isCalibrated,
      camera: camera ?? this.camera,
      calibrationOffset: calibrationOffset ?? this.calibrationOffset,
      includeRoll: includeRoll ?? this.includeRoll,
      sensitivity: sensitivity ?? this.sensitivity,
      touchControlEnabled: touchControlEnabled ?? this.touchControlEnabled,
    );
  }
  
  static GyroscopicCameraState initial() => GyroscopicCameraState(
    isEnabled: false,
    isCalibrated: false,
    camera: CameraOrientation.zero(),
    calibrationOffset: CameraOrientation.zero(),
    includeRoll: false,
    sensitivity: 1.0,
    touchControlEnabled: true,
  );
}

/// Gyroscopic camera controller - natural device motion tracking for 3D vision
/// Exactly like 360 photo/VR mode in Facebook/Instagram/Google Street View
class GyroscopicCameraService extends Notifier<GyroscopicCameraState> {
  Timer? _pollTimer;
  
  // Touch control state (fallback when gyro disabled)
  CameraOrientation _touchCamera = CameraOrientation.zero();
  
  @override
  GyroscopicCameraState build() {
    _loadSettings();
    ref.onDispose(() {
      _stopTracking();
    });
    return GyroscopicCameraState.initial();
  }
  
  /// Load settings from storage
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('gyro_camera_enabled') ?? false;
      final includeRoll = prefs.getBool('gyro_camera_roll') ?? false;
      final sensitivity = prefs.getDouble('gyro_camera_sensitivity') ?? 1.0;
      final touchEnabled = prefs.getBool('gyro_camera_touch') ?? true;
      
      state = state.copyWith(
        isEnabled: enabled,
        includeRoll: includeRoll,
        sensitivity: sensitivity,
        touchControlEnabled: touchEnabled,
      );
      
      if (enabled) {
        _startTracking();
      }
    } catch (e) {
      debugPrint('Failed to load gyroscopic camera settings: $e');
    }
  }
  
  /// Enable/disable gyroscopic motion control
  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('gyro_camera_enabled', enabled);
      
      state = state.copyWith(isEnabled: enabled);
      
      if (enabled) {
        _startTracking();
      } else {
        _stopTracking();
      }
    } catch (e) {
      debugPrint('Failed to set gyroscopic camera enabled: $e');
    }
  }
  
  /// Toggle roll tracking
  Future<void> setIncludeRoll(bool includeRoll) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('gyro_camera_roll', includeRoll);
      state = state.copyWith(includeRoll: includeRoll);
    } catch (e) {
      debugPrint('Failed to set roll tracking: $e');
    }
  }
  
  /// Set sensitivity (0.1 to 2.0)
  Future<void> setSensitivity(double sensitivity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('gyro_camera_sensitivity', sensitivity);
      state = state.copyWith(sensitivity: sensitivity);
    } catch (e) {
      debugPrint('Failed to set sensitivity: $e');
    }
  }
  
  /// Enable/disable touch control fallback
  Future<void> setTouchControlEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('gyro_camera_touch', enabled);
      state = state.copyWith(touchControlEnabled: enabled);
    } catch (e) {
      debugPrint('Failed to set touch control: $e');
    }
  }
  
  /// Calibrate - set current orientation as zero
  void calibrate() {
    final current = state.camera;
    state = state.copyWith(
      calibrationOffset: current,
      isCalibrated: true,
    );
    debugPrint('Gyroscopic camera calibrated: yaw=${current.yaw.toStringAsFixed(2)}, pitch=${current.pitch.toStringAsFixed(2)}, roll=${current.roll.toStringAsFixed(2)}');
  }
  
  /// Reset calibration
  void resetCalibration() {
    state = state.copyWith(
      calibrationOffset: CameraOrientation.zero(),
      isCalibrated: false,
    );
  }
  
  /// Start tracking device orientation
  void _startTracking() {
    _stopTracking();
    
    try {
      // Poll IMU fusion service at 60Hz for smooth orientation tracking
      _pollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (!state.isEnabled) return;
        
        final orientation = ref.read(imuFusionProvider);
        
        // Apply calibration offset
        final yaw = _wrapPi(orientation.yaw - state.calibrationOffset.yaw);
        final pitch = _wrapPi(orientation.pitch - state.calibrationOffset.pitch);
        final roll = state.includeRoll 
            ? _wrapPi(orientation.roll - state.calibrationOffset.roll)
            : 0.0;
        
        // Apply sensitivity
        final sens = state.sensitivity;
        final camera = CameraOrientation(
          yaw: yaw * sens,
          pitch: pitch * sens,
          roll: roll * sens,
        );
        
        state = state.copyWith(camera: camera);
      });
    } catch (e) {
      debugPrint('Failed to start gyroscopic tracking: $e');
    }
  }
  
  /// Stop tracking
  void _stopTracking() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
  
  /// Touch control - manual camera adjustment (fallback)
  void updateTouchControl(double deltaYaw, double deltaPitch) {
    if (!state.touchControlEnabled) return;
    
    _touchCamera = CameraOrientation(
      yaw: _wrapPi(_touchCamera.yaw + deltaYaw),
      pitch: math.max(-math.pi / 2, math.min(math.pi / 2, _touchCamera.pitch + deltaPitch)),
      roll: _touchCamera.roll,
    );
    
    // If gyro disabled, use touch camera directly
    if (!state.isEnabled) {
      state = state.copyWith(camera: _touchCamera);
    }
  }
  
  /// Reset camera to origin
  void resetCamera() {
    _touchCamera = CameraOrientation.zero();
    if (!state.isEnabled) {
      state = state.copyWith(camera: CameraOrientation.zero());
    }
  }
  
  /// Wrap angle to [-π, π]
  double _wrapPi(double angle) {
    double a = angle;
    while (a > math.pi) a -= 2 * math.pi;
    while (a < -math.pi) a += 2 * math.pi;
    return a;
  }
}

final gyroscopicCameraProvider = NotifierProvider<GyroscopicCameraService, GyroscopicCameraState>(
  () => GyroscopicCameraService(),
);
