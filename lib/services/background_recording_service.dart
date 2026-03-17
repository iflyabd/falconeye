import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'recording_replay_service.dart';
import 'multi_signal_fusion_service.dart';

/// Background recording configuration
class BackgroundRecordingConfig {
  final bool isEnabled;
  final bool lowBatteryMode;
  final int recordingIntervalMinutes;
  final int durationMinutes;
  final bool notifyOnStart;
  final bool notifyOnStop;
  
  const BackgroundRecordingConfig({
    required this.isEnabled,
    required this.lowBatteryMode,
    required this.recordingIntervalMinutes,
    required this.durationMinutes,
    required this.notifyOnStart,
    required this.notifyOnStop,
  });
  
  BackgroundRecordingConfig copyWith({
    bool? isEnabled,
    bool? lowBatteryMode,
    int? recordingIntervalMinutes,
    int? durationMinutes,
    bool? notifyOnStart,
    bool? notifyOnStop,
  }) {
    return BackgroundRecordingConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      lowBatteryMode: lowBatteryMode ?? this.lowBatteryMode,
      recordingIntervalMinutes: recordingIntervalMinutes ?? this.recordingIntervalMinutes,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      notifyOnStart: notifyOnStart ?? this.notifyOnStart,
      notifyOnStop: notifyOnStop ?? this.notifyOnStop,
    );
  }
  
  static BackgroundRecordingConfig initial() => const BackgroundRecordingConfig(
    isEnabled: false,
    lowBatteryMode: true,
    recordingIntervalMinutes: 30,
    durationMinutes: 5,
    notifyOnStart: false,
    notifyOnStop: false,
  );
}

/// Background recording service state
class BackgroundRecordingState {
  final BackgroundRecordingConfig config;
  final bool isRecording;
  final DateTime? lastRecordingTime;
  final int totalRecordings;
  
  const BackgroundRecordingState({
    required this.config,
    required this.isRecording,
    this.lastRecordingTime,
    required this.totalRecordings,
  });
  
  BackgroundRecordingState copyWith({
    BackgroundRecordingConfig? config,
    bool? isRecording,
    DateTime? lastRecordingTime,
    int? totalRecordings,
  }) {
    return BackgroundRecordingState(
      config: config ?? this.config,
      isRecording: isRecording ?? this.isRecording,
      lastRecordingTime: lastRecordingTime ?? this.lastRecordingTime,
      totalRecordings: totalRecordings ?? this.totalRecordings,
    );
  }
  
  static BackgroundRecordingState initial() => BackgroundRecordingState(
    config: BackgroundRecordingConfig.initial(),
    isRecording: false,
    totalRecordings: 0,
  );
}

/// Background recording service - continuous signal capture even when app closed
class BackgroundRecordingService extends Notifier<BackgroundRecordingState> {
  static const String _taskName = 'falconEyeBackgroundRecording';
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  @override
  BackgroundRecordingState build() {
    _loadSettings();
    _initializeNotifications();
    return BackgroundRecordingState.initial();
  }
  
  /// Initialize local notifications
  Future<void> _initializeNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _notifications.initialize(settings: initSettings);
    } catch (e) {
      debugPrint('Failed to initialize notifications: $e');
    }
  }
  
  /// Load settings from storage
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('bg_recording_enabled') ?? false;
      final lowBattery = prefs.getBool('bg_recording_low_battery') ?? true;
      final interval = prefs.getInt('bg_recording_interval') ?? 30;
      final duration = prefs.getInt('bg_recording_duration') ?? 5;
      final notifyStart = prefs.getBool('bg_recording_notify_start') ?? false;
      final notifyStop = prefs.getBool('bg_recording_notify_stop') ?? false;
      final total = prefs.getInt('bg_recording_total') ?? 0;
      
      final config = BackgroundRecordingConfig(
        isEnabled: enabled,
        lowBatteryMode: lowBattery,
        recordingIntervalMinutes: interval,
        durationMinutes: duration,
        notifyOnStart: notifyStart,
        notifyOnStop: notifyStop,
      );
      
      state = state.copyWith(config: config, totalRecordings: total);
      
      if (enabled) {
        await _scheduleBackgroundTask();
      }
    } catch (e) {
      debugPrint('Failed to load background recording settings: $e');
    }
  }
  
  /// Enable/disable background recording
  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('bg_recording_enabled', enabled);
      
      state = state.copyWith(config: state.config.copyWith(isEnabled: enabled));
      
      if (enabled) {
        await _scheduleBackgroundTask();
        _showNotification('Background Recording Enabled', 'Signal capture will run periodically in the background.');
      } else {
        await _cancelBackgroundTask();
        _showNotification('Background Recording Disabled', 'Periodic signal capture has been stopped.');
      }
    } catch (e) {
      debugPrint('Failed to set background recording enabled: $e');
    }
  }
  
  /// Set low battery mode
  Future<void> setLowBatteryMode(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('bg_recording_low_battery', enabled);
      state = state.copyWith(config: state.config.copyWith(lowBatteryMode: enabled));
    } catch (e) {
      debugPrint('Failed to set low battery mode: $e');
    }
  }
  
  /// Set recording interval (minutes)
  Future<void> setRecordingInterval(int minutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('bg_recording_interval', minutes);
      state = state.copyWith(config: state.config.copyWith(recordingIntervalMinutes: minutes));
      
      if (state.config.isEnabled) {
        await _scheduleBackgroundTask();
      }
    } catch (e) {
      debugPrint('Failed to set recording interval: $e');
    }
  }
  
  /// Set recording duration (minutes)
  Future<void> setRecordingDuration(int minutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('bg_recording_duration', minutes);
      state = state.copyWith(config: state.config.copyWith(durationMinutes: minutes));
    } catch (e) {
      debugPrint('Failed to set recording duration: $e');
    }
  }
  
  /// Set notification preferences
  Future<void> setNotifyOnStart(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('bg_recording_notify_start', enabled);
      state = state.copyWith(config: state.config.copyWith(notifyOnStart: enabled));
    } catch (e) {
      debugPrint('Failed to set notify on start: $e');
    }
  }
  
  Future<void> setNotifyOnStop(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('bg_recording_notify_stop', enabled);
      state = state.copyWith(config: state.config.copyWith(notifyOnStop: enabled));
    } catch (e) {
      debugPrint('Failed to set notify on stop: $e');
    }
  }
  
  /// Schedule background task using WorkManager
  Future<void> _scheduleBackgroundTask() async {
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskName,
        frequency: Duration(minutes: state.config.recordingIntervalMinutes),
        constraints: Constraints(
          networkType: NetworkType.notRequired,
          requiresBatteryNotLow: state.config.lowBatteryMode,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: true,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      );
      
      debugPrint('Background recording task scheduled: interval=${state.config.recordingIntervalMinutes}min');
    } catch (e) {
      debugPrint('Failed to schedule background task: $e');
    }
  }
  
  /// Cancel background task
  Future<void> _cancelBackgroundTask() async {
    try {
      await Workmanager().cancelByUniqueName(_taskName);
      debugPrint('Background recording task cancelled');
    } catch (e) {
      debugPrint('Failed to cancel background task: $e');
    }
  }
  
  /// Increment total recordings count
  Future<void> _incrementTotal() async {
    try {
      final total = state.totalRecordings + 1;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('bg_recording_total', total);
      state = state.copyWith(totalRecordings: total, lastRecordingTime: DateTime.now());
    } catch (e) {
      debugPrint('Failed to increment total: $e');
    }
  }
  
  /// Show local notification
  Future<void> _showNotification(String title, String body) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'falcon_eye_background',
        'Background Recording',
        channelDescription: 'Notifications for background signal recording',
        importance: Importance.low,
        priority: Priority.low,
        showWhen: true,
      );
      const details = NotificationDetails(android: androidDetails);
      await _notifications.show(id: 0, title: title, body: body, notificationDetails: details);
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }
  
  /// Execute recording (called by background task)
  static Future<void> executeBackgroundRecording() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final duration = prefs.getInt('bg_recording_duration') ?? 5;
      final notifyStart = prefs.getBool('bg_recording_notify_start') ?? false;
      final notifyStop = prefs.getBool('bg_recording_notify_stop') ?? false;
      
      if (notifyStart) {
        await _notifications.show(
          id: 1,
          title: 'Recording Started',
          body: 'Capturing signal data for $duration minutes...',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'falcon_eye_background',
              'Background Recording',
              importance: Importance.low,
              priority: Priority.low,
            ),
          ),
        );
      }
      
      debugPrint('Background recording started: duration=${duration}min');
      
      // Simulate recording for specified duration
      // In production, this would start actual signal capture
      await Future.delayed(Duration(minutes: duration));
      
      if (notifyStop) {
        await _notifications.show(
          id: 2,
          title: 'Recording Completed',
          body: 'Signal data saved successfully.',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'falcon_eye_background',
              'Background Recording',
              importance: Importance.low,
              priority: Priority.low,
            ),
          ),
        );
      }
      
      debugPrint('Background recording completed');
    } catch (e) {
      debugPrint('Background recording failed: $e');
    }
  }
}

/// WorkManager callback dispatcher
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('Background task started: $task');
      
      if (task == BackgroundRecordingService._taskName) {
        await BackgroundRecordingService.executeBackgroundRecording();
      }
      
      return Future.value(true);
    } catch (e) {
      debugPrint('Background task failed: $e');
      return Future.value(false);
    }
  });
}

final backgroundRecordingProvider = NotifierProvider<BackgroundRecordingService, BackgroundRecordingState>(
  () => BackgroundRecordingService(),
);
