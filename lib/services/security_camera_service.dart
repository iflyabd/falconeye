import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'wifi_csi_service.dart';
import 'multi_signal_fusion_service.dart';
import 'recording_replay_service.dart';

/// Security event types
enum SecurityEventType {
  motion,
  humanPresence,
  anomaly,
  intrusion,
  environmentChange,
}

/// Security event
class SecurityEvent {
  final SecurityEventType type;
  final DateTime timestamp;
  final double confidence;
  final String description;
  final Map<String, dynamic> data;
  
  const SecurityEvent({
    required this.type,
    required this.timestamp,
    required this.confidence,
    required this.description,
    required this.data,
  });
}

/// Security camera configuration
class SecurityCameraConfig {
  final bool isEnabled;
  final bool motionDetection;
  final bool humanDetection;
  final bool anomalyDetection;
  final double sensitivity;
  final bool recordOnEvent;
  final bool notifyOnEvent;
  final bool silentNotifications;
  final int eventRetentionDays;
  
  const SecurityCameraConfig({
    required this.isEnabled,
    required this.motionDetection,
    required this.humanDetection,
    required this.anomalyDetection,
    required this.sensitivity,
    required this.recordOnEvent,
    required this.notifyOnEvent,
    required this.silentNotifications,
    required this.eventRetentionDays,
  });
  
  SecurityCameraConfig copyWith({
    bool? isEnabled,
    bool? motionDetection,
    bool? humanDetection,
    bool? anomalyDetection,
    double? sensitivity,
    bool? recordOnEvent,
    bool? notifyOnEvent,
    bool? silentNotifications,
    int? eventRetentionDays,
  }) {
    return SecurityCameraConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      motionDetection: motionDetection ?? this.motionDetection,
      humanDetection: humanDetection ?? this.humanDetection,
      anomalyDetection: anomalyDetection ?? this.anomalyDetection,
      sensitivity: sensitivity ?? this.sensitivity,
      recordOnEvent: recordOnEvent ?? this.recordOnEvent,
      notifyOnEvent: notifyOnEvent ?? this.notifyOnEvent,
      silentNotifications: silentNotifications ?? this.silentNotifications,
      eventRetentionDays: eventRetentionDays ?? this.eventRetentionDays,
    );
  }
  
  static SecurityCameraConfig initial() => const SecurityCameraConfig(
    isEnabled: false,
    motionDetection: true,
    humanDetection: true,
    anomalyDetection: true,
    sensitivity: 0.7,
    recordOnEvent: true,
    notifyOnEvent: true,
    silentNotifications: false,
    eventRetentionDays: 7,
  );
}

/// Security camera state
class SecurityCameraState {
  final SecurityCameraConfig config;
  final bool isMonitoring;
  final List<SecurityEvent> events;
  final DateTime? lastEventTime;
  final int totalEvents;
  
  const SecurityCameraState({
    required this.config,
    required this.isMonitoring,
    required this.events,
    this.lastEventTime,
    required this.totalEvents,
  });
  
  SecurityCameraState copyWith({
    SecurityCameraConfig? config,
    bool? isMonitoring,
    List<SecurityEvent>? events,
    DateTime? lastEventTime,
    int? totalEvents,
  }) {
    return SecurityCameraState(
      config: config ?? this.config,
      isMonitoring: isMonitoring ?? this.isMonitoring,
      events: events ?? this.events,
      lastEventTime: lastEventTime ?? this.lastEventTime,
      totalEvents: totalEvents ?? this.totalEvents,
    );
  }
  
  static SecurityCameraState initial() => SecurityCameraState(
    config: SecurityCameraConfig.initial(),
    isMonitoring: false,
    events: [],
    totalEvents: 0,
  );
}

/// Invisible Radio Security Camera - detects motion, presence, anomalies using only radio waves
class SecurityCameraService extends Notifier<SecurityCameraState> {
  Timer? _monitoringTimer;
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  // Baseline signal state for anomaly detection
  List<double> _baselineCSI = [];
  List<Fused3DPoint> _baselineEnvironment = [];
  
  @override
  SecurityCameraState build() {
    _loadSettings();
    _initializeNotifications();
    ref.onDispose(() {
      stopMonitoring();
    });
    return SecurityCameraState.initial();
  }
  
  /// Initialize local notifications
  Future<void> _initializeNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _notifications.initialize(settings: initSettings);
    } catch (e) {
      debugPrint('Failed to initialize security camera notifications: $e');
    }
  }
  
  /// Load settings from storage
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('security_camera_enabled') ?? false;
      final motion = prefs.getBool('security_camera_motion') ?? true;
      final human = prefs.getBool('security_camera_human') ?? true;
      final anomaly = prefs.getBool('security_camera_anomaly') ?? true;
      final sensitivity = prefs.getDouble('security_camera_sensitivity') ?? 0.7;
      final recordOnEvent = prefs.getBool('security_camera_record') ?? true;
      final notifyOnEvent = prefs.getBool('security_camera_notify') ?? true;
      final silent = prefs.getBool('security_camera_silent') ?? false;
      final retention = prefs.getInt('security_camera_retention') ?? 7;
      final total = prefs.getInt('security_camera_total') ?? 0;
      
      final config = SecurityCameraConfig(
        isEnabled: enabled,
        motionDetection: motion,
        humanDetection: human,
        anomalyDetection: anomaly,
        sensitivity: sensitivity,
        recordOnEvent: recordOnEvent,
        notifyOnEvent: notifyOnEvent,
        silentNotifications: silent,
        eventRetentionDays: retention,
      );
      
      state = state.copyWith(config: config, totalEvents: total);
      
      if (enabled) {
        await startMonitoring();
      }
    } catch (e) {
      debugPrint('Failed to load security camera settings: $e');
    }
  }
  
  /// Enable/disable security camera
  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('security_camera_enabled', enabled);
      
      state = state.copyWith(config: state.config.copyWith(isEnabled: enabled));
      
      if (enabled) {
        await startMonitoring();
        _showNotification('Security Camera Enabled', 'Radio-wave monitoring started. No visual camera used.');
      } else {
        await stopMonitoring();
        _showNotification('Security Camera Disabled', 'Radio-wave monitoring stopped.');
      }
    } catch (e) {
      debugPrint('Failed to set security camera enabled: $e');
    }
  }
  
  /// Set detection types
  Future<void> setMotionDetection(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('security_camera_motion', enabled);
      state = state.copyWith(config: state.config.copyWith(motionDetection: enabled));
    } catch (e) {
      debugPrint('Failed to set motion detection: $e');
    }
  }
  
  Future<void> setHumanDetection(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('security_camera_human', enabled);
      state = state.copyWith(config: state.config.copyWith(humanDetection: enabled));
    } catch (e) {
      debugPrint('Failed to set human detection: $e');
    }
  }
  
  Future<void> setAnomalyDetection(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('security_camera_anomaly', enabled);
      state = state.copyWith(config: state.config.copyWith(anomalyDetection: enabled));
    } catch (e) {
      debugPrint('Failed to set anomaly detection: $e');
    }
  }
  
  /// Set sensitivity (0.0 to 1.0)
  Future<void> setSensitivity(double sensitivity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('security_camera_sensitivity', sensitivity);
      state = state.copyWith(config: state.config.copyWith(sensitivity: sensitivity));
    } catch (e) {
      debugPrint('Failed to set sensitivity: $e');
    }
  }
  
  /// Set event handling
  Future<void> setRecordOnEvent(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('security_camera_record', enabled);
      state = state.copyWith(config: state.config.copyWith(recordOnEvent: enabled));
    } catch (e) {
      debugPrint('Failed to set record on event: $e');
    }
  }
  
  Future<void> setNotifyOnEvent(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('security_camera_notify', enabled);
      state = state.copyWith(config: state.config.copyWith(notifyOnEvent: enabled));
    } catch (e) {
      debugPrint('Failed to set notify on event: $e');
    }
  }
  
  Future<void> setSilentNotifications(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('security_camera_silent', enabled);
      state = state.copyWith(config: state.config.copyWith(silentNotifications: enabled));
    } catch (e) {
      debugPrint('Failed to set silent notifications: $e');
    }
  }
  
  Future<void> setEventRetention(int days) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('security_camera_retention', days);
      state = state.copyWith(config: state.config.copyWith(eventRetentionDays: days));
    } catch (e) {
      debugPrint('Failed to set event retention: $e');
    }
  }
  
  /// Start monitoring
  Future<void> startMonitoring() async {
    if (state.isMonitoring) return;
    
    try {
      // Capture baseline signal state
      await _captureBaseline();
      
      // Start periodic monitoring
      _monitoringTimer = Timer.periodic(const Duration(seconds: 2), (_) => _analyzeSignals());
      
      state = state.copyWith(isMonitoring: true);
      debugPrint('Security camera monitoring started');
    } catch (e) {
      debugPrint('Failed to start monitoring: $e');
    }
  }
  
  /// Stop monitoring
  Future<void> stopMonitoring() async {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    state = state.copyWith(isMonitoring: false);
    debugPrint('Security camera monitoring stopped');
  }
  
  /// Capture baseline signal state
  Future<void> _captureBaseline() async {
    try {
      final csiState = ref.read(wifiCSIProvider);
      final fusionState = ref.read(multiSignalFusionProvider);
      
      _baselineCSI = csiState.rawData.map((d) => d.amplitude).toList();
      _baselineEnvironment = List.from(fusionState.fused3DEnvironment);
      
      debugPrint('Baseline captured: CSI=${_baselineCSI.length} points, 3D=${_baselineEnvironment.length} objects');
    } catch (e) {
      debugPrint('Failed to capture baseline: $e');
    }
  }
  
  /// Analyze signals for events
  Future<void> _analyzeSignals() async {
    try {
      final csiState = ref.read(wifiCSIProvider);
      final fusionState = ref.read(multiSignalFusionProvider);
      
      // Motion detection via CSI variance
      if (state.config.motionDetection) {
        final motionDetected = _detectMotion(csiState);
        if (motionDetected) {
          await _handleEvent(SecurityEvent(
            type: SecurityEventType.motion,
            timestamp: DateTime.now(),
            confidence: 0.85,
            description: 'Motion detected via CSI variance',
            data: {'csi_variance': _calculateVariance(csiState.rawData.map((d) => d.amplitude).toList())},
          ));
        }
      }
      
      // Human presence detection via Doppler shifts
      if (state.config.humanDetection) {
        final humanDetected = _detectHumanPresence(fusionState);
        if (humanDetected) {
          await _handleEvent(SecurityEvent(
            type: SecurityEventType.humanPresence,
            timestamp: DateTime.now(),
            confidence: 0.78,
            description: 'Human presence detected via Doppler analysis',
            data: {'doppler_shift': 'positive'},
          ));
        }
      }
      
      // Anomaly detection via environment changes
      if (state.config.anomalyDetection) {
        final anomalyDetected = _detectAnomaly(fusionState);
        if (anomalyDetected) {
          await _handleEvent(SecurityEvent(
            type: SecurityEventType.anomaly,
            timestamp: DateTime.now(),
            confidence: 0.72,
            description: 'Environment anomaly detected via 3D reconstruction',
            data: {'object_count_change': fusionState.fused3DEnvironment.length - _baselineEnvironment.length},
          ));
        }
      }
    } catch (e) {
      debugPrint('Signal analysis failed: $e');
    }
  }
  
  /// Detect motion via CSI variance
  bool _detectMotion(WiFiCSIState csiState) {
    if (_baselineCSI.isEmpty || csiState.rawData.isEmpty) return false;
    
    final variance = _calculateVariance(csiState.rawData.map((d) => d.amplitude).toList());
    final baselineVariance = _calculateVariance(_baselineCSI);
    
    final threshold = 0.15 * (1.0 - state.config.sensitivity);
    return (variance - baselineVariance).abs() > threshold;
  }
  
  /// Detect human presence via Doppler shifts
  bool _detectHumanPresence(MultiSignalFusionState fusionState) {
    if (fusionState.fused3DEnvironment.isEmpty) return false;
    
    // Count objects with human-like velocity patterns (0.5-2 m/s)
    final humanLikeMovement = fusionState.fused3DEnvironment.where(
      (point) => point.velocity.abs() > 0.5 && point.velocity.abs() < 2.0,
    ).length;
    
    final threshold = (5 * state.config.sensitivity).toInt();
    return humanLikeMovement > threshold;
  }
  
  /// Detect anomalies via environment changes
  bool _detectAnomaly(MultiSignalFusionState fusionState) {
    if (_baselineEnvironment.isEmpty) return false;
    
    final objectCountChange = (fusionState.fused3DEnvironment.length - _baselineEnvironment.length).abs();
    final threshold = (10 * state.config.sensitivity).toInt();
    
    return objectCountChange > threshold;
  }
  
  /// Calculate variance
  double _calculateVariance(List<double> data) {
    if (data.isEmpty) return 0.0;
    
    final mean = data.reduce((a, b) => a + b) / data.length;
    final squaredDiffs = data.map((x) => math.pow(x - mean, 2));
    return squaredDiffs.reduce((a, b) => a + b) / data.length;
  }
  
  /// Handle security event
  Future<void> _handleEvent(SecurityEvent event) async {
    try {
      // Add to event list
      final updatedEvents = List<SecurityEvent>.from(state.events)..add(event);
      final total = state.totalEvents + 1;
      
      state = state.copyWith(
        events: updatedEvents,
        lastEventTime: event.timestamp,
        totalEvents: total,
      );
      
      // Save total count
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('security_camera_total', total);
      
      // Start recording if enabled
      if (state.config.recordOnEvent) {
        await ref.read(recordingReplayProvider.notifier).startRecording();
        await Future.delayed(const Duration(seconds: 30));
        await ref.read(recordingReplayProvider.notifier).stopRecording();
      }
      
      // Send notification
      if (state.config.notifyOnEvent) {
        await _showEventNotification(event);
      }
      
      debugPrint('Security event: ${event.type.name} (confidence=${event.confidence.toStringAsFixed(2)})');
    } catch (e) {
      debugPrint('Failed to handle event: $e');
    }
  }
  
  /// Show event notification
  Future<void> _showEventNotification(SecurityEvent event) async {
    try {
      final importance = state.config.silentNotifications ? Importance.low : Importance.high;
      final priority = state.config.silentNotifications ? Priority.low : Priority.high;
      
      final androidDetails = AndroidNotificationDetails(
        'falcon_eye_security',
        'Security Camera',
        channelDescription: 'Notifications for security camera events',
        importance: importance,
        priority: priority,
        showWhen: true,
        enableVibration: !state.config.silentNotifications,
        playSound: !state.config.silentNotifications,
      );
      
      final details = NotificationDetails(android: androidDetails);
      
      await _notifications.show(
        id: event.timestamp.millisecondsSinceEpoch % 10000,
        title: _getEventTitle(event.type),
        body: '${event.description} (${(event.confidence * 100).toStringAsFixed(0)}% confidence)',
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('Failed to show event notification: $e');
    }
  }
  
  /// Show regular notification
  Future<void> _showNotification(String title, String body) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'falcon_eye_security',
        'Security Camera',
        importance: Importance.low,
        priority: Priority.low,
      );
      const details = NotificationDetails(android: androidDetails);
      await _notifications.show(id: 0, title: title, body: body, notificationDetails: details);
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }
  
  /// Get event title
  String _getEventTitle(SecurityEventType type) {
    switch (type) {
      case SecurityEventType.motion:
        return '⚠️ Motion Detected';
      case SecurityEventType.humanPresence:
        return '👤 Human Presence';
      case SecurityEventType.anomaly:
        return '🔍 Anomaly Detected';
      case SecurityEventType.intrusion:
        return '🚨 Intrusion Alert';
      case SecurityEventType.environmentChange:
        return '📊 Environment Change';
    }
  }
  
  /// Clear old events
  Future<void> clearOldEvents() async {
    final cutoff = DateTime.now().subtract(Duration(days: state.config.eventRetentionDays));
    final updatedEvents = state.events.where((e) => e.timestamp.isAfter(cutoff)).toList();
    state = state.copyWith(events: updatedEvents);
  }
  
  /// Clear all events
  Future<void> clearAllEvents() async {
    state = state.copyWith(events: []);
  }
}

final securityCameraProvider = NotifierProvider<SecurityCameraService, SecurityCameraState>(
  () => SecurityCameraService(),
);
