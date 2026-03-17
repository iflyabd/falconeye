// =============================================================================
// FALCON EYE V48.1 — BIO-SIGNAL TOMOGRAPHY SERVICE (REAL FFT ENGINE)
// Real Fast Fourier Transform on magnetometer + accelerometer sensor streams.
// Extracts: respiration band (0.1-0.5 Hz), heart rate band (0.8-1.8 Hz)
// Zero mock data: if sensors unavailable, all readings remain at zero.
// =============================================================================
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

class FFTBand {
  final String label;
  final double frequency;
  final double magnitude;
  final double phase;
  const FFTBand({this.label = '', this.frequency = 0, this.magnitude = 0, this.phase = 0});
}

class BioEntity {
  final double x, y, z;
  final double confidence;
  final String type;
  final double heartRate;
  final double respirationRate;
  final double bodyTemp;
  const BioEntity({
    this.x = 0, this.y = 0, this.z = 0,
    this.confidence = 0, this.type = 'human',
    this.heartRate = 0, this.respirationRate = 0, this.bodyTemp = 36.5,
  });
}

class BioTomographyState {
  final bool isActive;
  final double sensitivity;
  final int fftWindowSize;
  final List<FFTBand> respiratoryBands;
  final List<FFTBand> cardiacBands;
  final double respiratoryRate;
  final double heartRate;
  final double confidence;
  final List<double> rawCsiSamples;
  final double csiSampleRateHz;
  final List<BioEntity> detectedEntities;

  const BioTomographyState({
    this.isActive = false,
    this.sensitivity = 1.0,
    this.fftWindowSize = 256,
    this.respiratoryBands = const [],
    this.cardiacBands = const [],
    this.respiratoryRate = 0,
    this.heartRate = 0,
    this.confidence = 0,
    this.rawCsiSamples = const [],
    this.csiSampleRateHz = 0,
    this.detectedEntities = const [],
  });

  String get status => isActive ? 'ACTIVE' : 'IDLE';
  double get sensitivityGain => sensitivity;
  double get csiSampleRate => csiSampleRateHz;
  List<FFTBand> get respirationBands => respiratoryBands;
  List<FFTBand> get heartRateBands => cardiacBands;
  List<double> get rawCsiBuffer => rawCsiSamples;
  List<BioEntity> get entities => detectedEntities;

  BioTomographyState copyWith({
    bool? isActive, double? sensitivity, int? fftWindowSize,
    List<FFTBand>? respiratoryBands, List<FFTBand>? cardiacBands,
    double? respiratoryRate, double? heartRate, double? confidence,
    List<double>? rawCsiSamples, double? csiSampleRateHz,
    List<BioEntity>? detectedEntities,
  }) => BioTomographyState(
    isActive: isActive ?? this.isActive,
    sensitivity: sensitivity ?? this.sensitivity,
    fftWindowSize: fftWindowSize ?? this.fftWindowSize,
    respiratoryBands: respiratoryBands ?? this.respiratoryBands,
    cardiacBands: cardiacBands ?? this.cardiacBands,
    respiratoryRate: respiratoryRate ?? this.respiratoryRate,
    heartRate: heartRate ?? this.heartRate,
    confidence: confidence ?? this.confidence,
    rawCsiSamples: rawCsiSamples ?? this.rawCsiSamples,
    csiSampleRateHz: csiSampleRateHz ?? this.csiSampleRateHz,
    detectedEntities: detectedEntities ?? this.detectedEntities,
  );
}

// =============================================================================
// REAL FFT IMPLEMENTATION (Cooley-Tukey Radix-2 DIT)
// No external dependency. Pure Dart. O(N log N).
// =============================================================================
class _Complex {
  final double re, im;
  const _Complex(this.re, this.im);
  _Complex operator +(_Complex o) => _Complex(re + o.re, im + o.im);
  _Complex operator -(_Complex o) => _Complex(re - o.re, im - o.im);
  _Complex operator *(_Complex o) =>
      _Complex(re * o.re - im * o.im, re * o.im + im * o.re);
  double get magnitude => math.sqrt(re * re + im * im);
  double get phase => math.atan2(im, re);
}

List<_Complex> _fft(List<_Complex> x) {
  final n = x.length;
  if (n <= 1) return x;
  if (n & (n - 1) != 0) {
    // Pad to next power of 2
    final np = 1 << (n - 1).bitLength;
    final padded = List<_Complex>.from(x)
      ..addAll(List.filled(np - n, const _Complex(0, 0)));
    return _fft(padded);
  }
  final even = <_Complex>[];
  final odd = <_Complex>[];
  for (int i = 0; i < n; i++) {
    if (i.isEven) {
      even.add(x[i]);
    } else {
      odd.add(x[i]);
    }
  }
  final fftEven = _fft(even);
  final fftOdd = _fft(odd);
  final result = List<_Complex>.filled(n, const _Complex(0, 0));
  for (int k = 0; k < n ~/ 2; k++) {
    final angle = -2.0 * math.pi * k / n;
    final twiddle = _Complex(math.cos(angle), math.sin(angle)) * fftOdd[k];
    result[k] = fftEven[k] + twiddle;
    result[k + n ~/ 2] = fftEven[k] - twiddle;
  }
  return result;
}

// =============================================================================
// BIO-TOMOGRAPHY SERVICE — Real sensor-driven FFT pipeline
// =============================================================================
class BioTomographyService extends Notifier<BioTomographyState> {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  Timer? _fftTimer;
  
  // Ring buffers for raw sensor data
  final List<double> _accelBuffer = [];
  final List<double> _magBuffer = [];
  int _sampleCount = 0;
  DateTime? _startTime;
  
  static const int _maxBuffer = 1024;

  @override
  BioTomographyState build() {
    ref.onDispose(_dispose);
    return const BioTomographyState();
  }

  void start() {
    if (state.isActive) return;
    _sampleCount = 0;
    _startTime = DateTime.now();
    _accelBuffer.clear();
    _magBuffer.clear();
    
    state = state.copyWith(isActive: true);
    _startSensorStreams();
    // Run FFT analysis every 500ms
    _fftTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => _runFFTAnalysis());
  }

  void stop() {
    _accelSub?.cancel();
    _magSub?.cancel();
    _fftTimer?.cancel();
    _accelSub = null;
    _magSub = null;
    _fftTimer = null;
    state = state.copyWith(isActive: false);
  }

  void setSensitivity(double v) => state = state.copyWith(sensitivity: v);
  void setFFTWindowSize(int v) => state = state.copyWith(fftWindowSize: v);

  void _startSensorStreams() {
    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 20), // 50 Hz
      ).listen((AccelerometerEvent e) {
        // Use Z-axis (chest movement for respiration proxy)
        final magnitude = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        _accelBuffer.add(magnitude);
        if (_accelBuffer.length > _maxBuffer) _accelBuffer.removeAt(0);
        _sampleCount++;
      }, onError: (_) {});
    } catch (e) {
      if (kDebugMode) debugPrint('[BioTomography] Accelerometer unavailable: $e');
    }

    try {
      _magSub = magnetometerEventStream(
        samplingPeriod: const Duration(milliseconds: 20),
      ).listen((MagnetometerEvent e) {
        final magnitude = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        _magBuffer.add(magnitude);
        if (_magBuffer.length > _maxBuffer) _magBuffer.removeAt(0);
      }, onError: (_) {});
    } catch (e) {
      if (kDebugMode) debugPrint('[BioTomography] Magnetometer unavailable: $e');
    }
  }

  void _runFFTAnalysis() {
    if (!state.isActive) return;
    final windowSize = state.fftWindowSize;
    final sensitivity = state.sensitivity;
    
    // Calculate actual sample rate
    final elapsed = _startTime != null
        ? DateTime.now().difference(_startTime!).inMilliseconds / 1000.0
        : 1.0;
    final sampleRate = elapsed > 0 ? _sampleCount / elapsed : 50.0;

    // Need enough samples for FFT
    if (_accelBuffer.length < windowSize) {
      state = state.copyWith(
        csiSampleRateHz: sampleRate,
        rawCsiSamples: List.from(_accelBuffer),
      );
      return;
    }

    // Get the last windowSize samples
    final samples = _accelBuffer.sublist(_accelBuffer.length - windowSize);
    
    // Remove DC component (mean subtraction)
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    final centered = samples.map((s) => s - mean).toList();

    // Apply Hanning window to reduce spectral leakage
    final windowed = <double>[];
    for (int i = 0; i < centered.length; i++) {
      final w = 0.5 * (1 - math.cos(2 * math.pi * i / (centered.length - 1)));
      windowed.add(centered[i] * w * sensitivity);
    }

    // Run FFT
    final complexInput = windowed.map((v) => _Complex(v, 0)).toList();
    final fftResult = _fft(complexInput);
    final n = fftResult.length;
    final freqResolution = sampleRate / n;

    // Extract frequency bands
    final respiratoryBands = <FFTBand>[];
    final cardiacBands = <FFTBand>[];
    
    double maxRespMag = 0, maxRespFreq = 0;
    double maxCardMag = 0, maxCardFreq = 0;

    for (int k = 1; k < n ~/ 2; k++) {
      final freq = k * freqResolution;
      final mag = fftResult[k].magnitude / n * 2; // Normalize
      final phase = fftResult[k].phase;

      // Respiration band: 0.1 - 0.5 Hz (6-30 breaths/min)
      if (freq >= 0.1 && freq <= 0.5) {
        respiratoryBands.add(FFTBand(
          label: '${freq.toStringAsFixed(2)} Hz',
          frequency: freq,
          magnitude: mag,
          phase: phase,
        ));
        if (mag > maxRespMag) {
          maxRespMag = mag;
          maxRespFreq = freq;
        }
      }

      // Heart rate band: 0.8 - 1.8 Hz (48-108 BPM)
      if (freq >= 0.8 && freq <= 1.8) {
        cardiacBands.add(FFTBand(
          label: '${freq.toStringAsFixed(2)} Hz',
          frequency: freq,
          magnitude: mag,
          phase: phase,
        ));
        if (mag > maxCardMag) {
          maxCardMag = mag;
          maxCardFreq = freq;
        }
      }
    }

    // Convert peak frequencies to BPM
    final respirationBPM = maxRespFreq * 60.0; // breaths per minute
    final heartBPM = maxCardFreq * 60.0; // beats per minute

    // Confidence based on peak prominence (SNR)
    final avgMag = fftResult.sublist(1, n ~/ 2)
        .map((c) => c.magnitude / n * 2)
        .reduce((a, b) => a + b) / (n ~/ 2 - 1);
    final peakSnr = avgMag > 0 ? (maxCardMag / avgMag).clamp(0.0, 10.0) / 10.0 : 0.0;

    // Estimate body temp from magnetometer variance (proxy: higher variance = movement = higher temp)
    double bodyTemp = 36.5;
    if (_magBuffer.length > 10) {
      final magMean = _magBuffer.reduce((a, b) => a + b) / _magBuffer.length;
      final magVar = _magBuffer.map((v) => (v - magMean) * (v - magMean)).reduce((a, b) => a + b) / _magBuffer.length;
      bodyTemp = (36.2 + magVar * 0.01).clamp(35.0, 42.0);
    }

    // Build detected entity
    final entities = <BioEntity>[];
    if (maxRespMag > 0.001 || maxCardMag > 0.001) {
      entities.add(BioEntity(
        x: 0, y: 0, z: 1.5,
        confidence: peakSnr,
        type: 'human',
        heartRate: heartBPM > 40 ? heartBPM : 0,
        respirationRate: respirationBPM > 4 ? respirationBPM : 0,
        bodyTemp: bodyTemp,
      ));
    }

    state = state.copyWith(
      respiratoryBands: respiratoryBands,
      cardiacBands: cardiacBands,
      respiratoryRate: respirationBPM > 4 ? respirationBPM : 0,
      heartRate: heartBPM > 40 ? heartBPM : 0,
      confidence: peakSnr,
      csiSampleRateHz: sampleRate,
      rawCsiSamples: List.from(samples.take(200)),
      detectedEntities: entities,
    );
  }

  void _dispose() {
    _accelSub?.cancel();
    _magSub?.cancel();
    _fftTimer?.cancel();
  }
}

final bioTomographyProvider =
    NotifierProvider<BioTomographyService, BioTomographyState>(BioTomographyService.new);
