import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'multi_signal_fusion_service.dart';
import 'encrypted_vault_service.dart';

/// Recording metadata
class RecordingMetadata {
  final String id;
  final String name;
  final DateTime recordedAt;
  final Duration duration;
  final int frameCount;
  final Map<String, bool> signalsRecorded;
  final String filePath;
  
  const RecordingMetadata({
    required this.id,
    required this.name,
    required this.recordedAt,
    required this.duration,
    required this.frameCount,
    required this.signalsRecorded,
    required this.filePath,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'recordedAt': recordedAt.toIso8601String(),
    'duration': duration.inMilliseconds,
    'frameCount': frameCount,
    'signalsRecorded': signalsRecorded,
    'filePath': filePath,
  };
  
  factory RecordingMetadata.fromJson(Map<String, dynamic> json) => RecordingMetadata(
    id: json['id'],
    name: json['name'],
    recordedAt: DateTime.parse(json['recordedAt']),
    duration: Duration(milliseconds: json['duration']),
    frameCount: json['frameCount'],
    signalsRecorded: Map<String, bool>.from(json['signalsRecorded']),
    filePath: json['filePath'],
  );
}

/// Replay state
class ReplayState {
  final bool isPlaying;
  final bool isPaused;
  final double playbackSpeed; // 0.25x, 0.5x, 1.0x, 2.0x, 4.0x
  final int currentFrameIndex;
  final int totalFrames;
  final bool loopEnabled;
  final Duration currentTime;
  final Duration totalDuration;
  
  const ReplayState({
    this.isPlaying = false,
    this.isPaused = false,
    this.playbackSpeed = 1.0,
    this.currentFrameIndex = 0,
    this.totalFrames = 0,
    this.loopEnabled = false,
    this.currentTime = Duration.zero,
    this.totalDuration = Duration.zero,
  });
  
  ReplayState copyWith({
    bool? isPlaying,
    bool? isPaused,
    double? playbackSpeed,
    int? currentFrameIndex,
    int? totalFrames,
    bool? loopEnabled,
    Duration? currentTime,
    Duration? totalDuration,
  }) => ReplayState(
    isPlaying: isPlaying ?? this.isPlaying,
    isPaused: isPaused ?? this.isPaused,
    playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    currentFrameIndex: currentFrameIndex ?? this.currentFrameIndex,
    totalFrames: totalFrames ?? this.totalFrames,
    loopEnabled: loopEnabled ?? this.loopEnabled,
    currentTime: currentTime ?? this.currentTime,
    totalDuration: totalDuration ?? this.totalDuration,
  );
}

/// Recording & Replay Service - Save and playback signal data
class RecordingReplayService extends Notifier<ReplayState> {
  // Recording state
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  final List<FusionDataPoint> _recordBuffer = [];
  
  // Replay state
  List<FusionDataPoint>? _loadedRecording;
  Timer? _playbackTimer;
  
  @override
  ReplayState build() => const ReplayState();
  
  /// Start recording raw signal data
  Future<void> startRecording() async {
    if (_isRecording) return;
    
    debugPrint('[Recording V15] Starting recording...');
    
    _isRecording = true;
    _recordingStartTime = DateTime.now();
    _recordBuffer.clear();
    
    // Enable fusion to generate data
    ref.read(multiSignalFusionProvider.notifier).start();
    
    debugPrint('[Recording V15] Recording STARTED');
  }
  
  /// Stop recording and save to file
  Future<RecordingMetadata?> stopRecording({String? customName}) async {
    if (!_isRecording) return null;
    
    debugPrint('[Recording V15] Stopping recording...');
    
    _isRecording = false;
    final duration = DateTime.now().difference(_recordingStartTime!);
    
    // Capture final fusion buffer
    final fusionState = ref.read(multiSignalFusionProvider);
    _recordBuffer.addAll(fusionState.liveBuffer);
    
    if (_recordBuffer.isEmpty) {
      debugPrint('[Recording V15] No data recorded');
      return null;
    }
    
    // Generate metadata
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final name = customName ?? 'Recording_${DateTime.now().toIso8601String().split('T').first}';
    
    final metadata = RecordingMetadata(
      id: id,
      name: name,
      recordedAt: _recordingStartTime!,
      duration: duration,
      frameCount: _recordBuffer.length,
      signalsRecorded: fusionState.activeSignals,
      filePath: '', // Will be set after save
    );
    
    // Save to encrypted file
    final savedMetadata = await _saveRecording(metadata, _recordBuffer);
    
    _recordBuffer.clear();
    debugPrint('[Recording V15] Recording saved: ${savedMetadata.name}');
    
    return savedMetadata;
  }
  
  /// Save recording to encrypted file
  Future<RecordingMetadata> _saveRecording(
    RecordingMetadata metadata,
    List<FusionDataPoint> frames,
  ) async {
    try {
      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/falcon_recordings');
      
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }
      
      final filePath = '${recordingsDir.path}/${metadata.id}.json';
      
      // Create recording file structure
      final recordingData = {
        'metadata': metadata.toJson(),
        'frames': frames.map((f) => f.toJson()).toList(),
      };
      
      // Convert to JSON and save
      final jsonString = jsonEncode(recordingData);
      final file = File(filePath);
      await file.writeAsString(jsonString);

      // Encrypted Vault: if armed, encrypt recording immediately
      try {
        final vault = ref.read(encryptedVaultProvider.notifier);
        if (vault.isArmed) {
          final encPath = await vault.encryptFile(filePath);
          debugPrint('[Recording V15] Encrypted → $encPath');
        }
      } catch (e) {
        debugPrint('[Recording V15] Vault encrypt skipped: $e');
      }
      
      debugPrint('[Recording V15] Saved to: $filePath (${(jsonString.length / 1024).toStringAsFixed(2)} KB)');
      
      return RecordingMetadata(
        id: metadata.id,
        name: metadata.name,
        recordedAt: metadata.recordedAt,
        duration: metadata.duration,
        frameCount: metadata.frameCount,
        signalsRecorded: metadata.signalsRecorded,
        filePath: filePath,
      );
    } catch (e) {
      debugPrint('[Recording V15] Save error: $e');
      rethrow;
    }
  }
  
  /// Load all saved recordings
  Future<List<RecordingMetadata>> loadRecordingsList() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/falcon_recordings');
      
      if (!await recordingsDir.exists()) {
        return [];
      }
      
      final files = recordingsDir.listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      
      final recordings = <RecordingMetadata>[];
      
      for (final file in files) {
        try {
          final jsonString = await file.readAsString();
          final data = jsonDecode(jsonString);
          final metadata = RecordingMetadata.fromJson(data['metadata']);
          recordings.add(metadata);
        } catch (e) {
          debugPrint('[Recording V15] Failed to load recording: ${file.path}');
        }
      }
      
      // Sort by recorded date (newest first)
      recordings.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      
      return recordings;
    } catch (e) {
      debugPrint('[Recording V15] Load list error: $e');
      return [];
    }
  }
  
  /// Load a specific recording for replay
  Future<bool> loadRecording(RecordingMetadata metadata) async {
    try {
      debugPrint('[Replay V15] Loading recording: ${metadata.name}');
      
      final file = File(metadata.filePath);
      if (!await file.exists()) {
        debugPrint('[Replay V15] File not found: ${metadata.filePath}');
        return false;
      }
      
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString);
      
      _loadedRecording = (data['frames'] as List)
          .map((f) => FusionDataPoint.fromJson(f))
          .toList();
      
      state = state.copyWith(
        totalFrames: _loadedRecording!.length,
        currentFrameIndex: 0,
        totalDuration: metadata.duration,
        currentTime: Duration.zero,
      );
      
      debugPrint('[Replay V15] Loaded ${_loadedRecording!.length} frames');
      return true;
    } catch (e) {
      debugPrint('[Replay V15] Load error: $e');
      return false;
    }
  }
  
  /// Start playback
  void play() {
    if (_loadedRecording == null || _loadedRecording!.isEmpty) return;
    if (state.isPlaying && !state.isPaused) return;
    
    debugPrint('[Replay V15] Starting playback at ${state.playbackSpeed}x speed');
    
    state = state.copyWith(
      isPlaying: true,
      isPaused: false,
    );
    
    // Calculate frame interval based on playback speed
    final baseInterval = 50; // 20 FPS (50ms per frame)
    final interval = (baseInterval / state.playbackSpeed).round();
    
    _playbackTimer = Timer.periodic(Duration(milliseconds: interval), (_) {
      _advanceFrame();
    });
  }
  
  /// Pause playback
  void pause() {
    if (!state.isPlaying) return;
    
    _playbackTimer?.cancel();
    _playbackTimer = null;
    
    state = state.copyWith(
      isPaused: true,
    );
    
    debugPrint('[Replay V15] Paused at frame ${state.currentFrameIndex}');
  }
  
  /// Stop playback
  void stop() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    
    state = state.copyWith(
      isPlaying: false,
      isPaused: false,
      currentFrameIndex: 0,
      currentTime: Duration.zero,
    );
    
    debugPrint('[Replay V15] Stopped');
  }
  
  /// Seek to specific frame
  void seekToFrame(int frameIndex) {
    if (_loadedRecording == null) return;
    
    final clampedIndex = frameIndex.clamp(0, state.totalFrames - 1);
    
    state = state.copyWith(
      currentFrameIndex: clampedIndex,
      currentTime: _calculateTimeFromFrame(clampedIndex),
    );
    
    debugPrint('[Replay V15] Seeked to frame $clampedIndex');
  }
  
  /// Set playback speed
  void setPlaybackSpeed(double speed) {
    final wasPlaying = state.isPlaying && !state.isPaused;
    
    if (wasPlaying) {
      pause();
    }
    
    state = state.copyWith(
      playbackSpeed: speed,
    );
    
    if (wasPlaying) {
      play();
    }
    
    debugPrint('[Replay V15] Playback speed set to ${speed}x');
  }
  
  /// Toggle loop
  void toggleLoop() {
    state = state.copyWith(
      loopEnabled: !state.loopEnabled,
    );
    
    debugPrint('[Replay V15] Loop ${state.loopEnabled ? "enabled" : "disabled"}');
  }
  
  /// Advance to next frame
  void _advanceFrame() {
    if (_loadedRecording == null) return;
    
    int nextIndex = state.currentFrameIndex + 1;
    
    // Check if reached end
    if (nextIndex >= state.totalFrames) {
      if (state.loopEnabled) {
        nextIndex = 0; // Loop back to start
      } else {
        stop(); // Stop playback
        return;
      }
    }
    
    // Update fusion service with this frame's data
    _updateFusionWithFrame(_loadedRecording![nextIndex]);
    
    state = state.copyWith(
      currentFrameIndex: nextIndex,
      currentTime: _calculateTimeFromFrame(nextIndex),
    );
  }
  
  /// Calculate time from frame index
  Duration _calculateTimeFromFrame(int frameIndex) {
    if (state.totalFrames == 0) return Duration.zero;
    
    final progress = frameIndex / state.totalFrames;
    return Duration(
      milliseconds: (state.totalDuration.inMilliseconds * progress).round(),
    );
  }
  
  /// Update fusion service with replay frame data
  void _updateFusionWithFrame(FusionDataPoint frame) {
    // This will be used by the visualization to reconstruct the 3D scene
    // The fusion service will process this frame as if it's live data
    
    // Note: In real implementation, we would inject this into the fusion pipeline
    // For now, we'll store it in a provider that the UI can read
  }
  
  /// Get current frame data
  FusionDataPoint? getCurrentFrame() {
    if (_loadedRecording == null || state.currentFrameIndex >= _loadedRecording!.length) {
      return null;
    }
    return _loadedRecording![state.currentFrameIndex];
  }
  
  /// Delete a recording
  Future<bool> deleteRecording(RecordingMetadata metadata) async {
    try {
      final file = File(metadata.filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[Recording V15] Deleted: ${metadata.name}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Recording V15] Delete error: $e');
      return false;
    }
  }
  
  /// Check if currently recording
  bool get isRecording => _isRecording;
  
  /// Get recording duration (if recording)
  Duration? get recordingDuration {
    if (!_isRecording || _recordingStartTime == null) return null;
    return DateTime.now().difference(_recordingStartTime!);
  }
}

final recordingReplayProvider = NotifierProvider<RecordingReplayService, ReplayState>(() {
  return RecordingReplayService();
});
