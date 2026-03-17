// =============================================================================
// FALCON EYE V49.9 — NATIVE RENDERER FFI BRIDGE  (9-fix edition)
// =============================================================================
// FIX #1  VBO ping-pong         nativeGetRingBuffer always returns write side
// FIX #3  True ring buffer      nativeFlushRing advances head index in C++
// FIX #5  Tier-sized malloc      nativeSetPointBudget must be called BEFORE init
// FIX #8  LOD cull              nativeUploadBatch applies distance cull in C++
// FIX #9  Choreographer thread  nativeStartRenderThread / Stop / Pause / Resume
//         Dart MethodChannel "falcon_eye/renderer" for pause/resume from Dart
// =============================================================================
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart' as ffiPkg;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ── FFI typedefs ─────────────────────────────────────────────────────────────
typedef _InitC    = ffi.Int32 Function(ffi.Int32 w, ffi.Int32 h);
typedef _InitD    = int      Function(int w, int h);
typedef _ResizeC  = ffi.Void Function(ffi.Int32 w, ffi.Int32 h);
typedef _ResizeD  = void    Function(int w, int h);
typedef _CamC     = ffi.Void Function(ffi.Float yaw, ffi.Float pitch, ffi.Float roll, ffi.Float fov, ffi.Float zoom);
typedef _CamD     = void   Function(double yaw, double pitch, double roll, double fov, double zoom);
typedef _BudgetC  = ffi.Void Function(ffi.Int32 max);
typedef _BudgetD  = void   Function(int max);

// FIX #1 + #3: zero-copy ring buffer
typedef _RingBufC  = ffi.Pointer<ffi.Float> Function(ffi.Int32 capacity);
typedef _RingBufD  = ffi.Pointer<ffi.Float> Function(int capacity);
typedef _FlushC    = ffi.Int32 Function(ffi.Int32 count);
typedef _FlushD    = int      Function(int count);

// Batch upload (fallback path, applies LOD cull in C++)
typedef _BatchC   = ffi.Int32 Function(ffi.Pointer<ffi.Float> data, ffi.Int32 count);
typedef _BatchD   = int      Function(ffi.Pointer<ffi.Float> data, int count);

// Frustum cull
typedef _CullC    = ffi.Int32 Function(ffi.Pointer<ffi.Float> pts, ffi.Int32 count, ffi.Pointer<ffi.Float> out);
typedef _CullD    = int      Function(ffi.Pointer<ffi.Float> pts, int count, ffi.Pointer<ffi.Float> out);

typedef _VoidC    = ffi.Void Function();
typedef _VoidD    = void   Function();
typedef _Int32C   = ffi.Int32 Function();
typedef _Int32D   = int      Function();

// FIX #9: Choreographer thread — start takes nativeWindow ptr as int64
typedef _StartThreadC = ffi.Void Function(ffi.Int64 nativeWindow, ffi.Int32 w, ffi.Int32 h);
typedef _StartThreadD = void   Function(int nativeWindow, int w, int h);

// ── Point layout ─────────────────────────────────────────────────────────────
// [x, y, z, r, g, b, a, size]  — 8 floats = 32 bytes per point
const int kPointStride = 8;

/// GPU tier — point budget and FPS target.
enum GpuTier {
  tier1(label: 'Adreno 7xx+ / Mali-G720+', maxPoints: 2000000, targetFps: 120),
  tier2(label: 'Adreno 6xx / Mali-G710',   maxPoints: 1000000, targetFps: 60),
  tier3(label: 'Web / Low-end / Fallback',  maxPoints: 200000,  targetFps: 30);

  const GpuTier({required this.label, required this.maxPoints, required this.targetFps});
  final String label;
  final int    maxPoints;
  final int    targetFps;
}

/// Native renderer FFI bridge — V49.9 all-9-fixes edition.
class NativeRendererBridge {
  static NativeRendererBridge? _instance;
  static NativeRendererBridge get instance => _instance ??= NativeRendererBridge._();

  bool     _available = false;
  bool     get isAvailable => _available;
  GpuTier  _gpuTier = GpuTier.tier3;
  GpuTier  get gpuTier => _gpuTier;

  // FFI function pointers
  _InitD?         _init;
  _ResizeD?       _resize;
  _CamD?          _setCamera;
  _BudgetD?       _setBudget;
  _RingBufD?      _getRingBuffer;
  _FlushD?        _flushRing;
  _BatchD?        _uploadBatch;
  _CullD?         _frustumCull;
  _VoidD?         _render;
  _VoidD?         _destroy;
  _Int32D?        _getCount;
  _Int32D?        _isInit;
  // FIX #9
  _StartThreadD?  _startThread;
  _VoidD?         _stopThread;
  _VoidD?         _pauseRender;
  _VoidD?         _resumeRender;

  // FIX #1 + #3: persistent ring buffer pointer (zero-copy path)
  ffi.Pointer<ffi.Float>? _ringBuffer;
  int _ringBufCapacity = 0;

  // Fallback calloc buffer (batch path)
  ffi.Pointer<ffi.Float>? _batchBuffer;
  int _batchBufCapacity = 0;

  // FIX #9: MethodChannel for pause/resume when Dart doesn't have raw FFI access
  // to the ANativeWindow pointer (that lives on the Kotlin side).
  static const _rendererChannel = MethodChannel('falcon_eye/renderer');

  NativeRendererBridge._() { _tryLoad(); }

  void _tryLoad() {
    if (kIsWeb) { _available = false; return; }
    try {
      if (!Platform.isAndroid) { _available = false; return; }
      final lib = ffi.DynamicLibrary.open('libfalcon_renderer.so');

      _init         = lib.lookupFunction<_InitC,    _InitD>   ('nativeInit');
      _resize       = lib.lookupFunction<_ResizeC,  _ResizeD> ('nativeResize');
      _setCamera    = lib.lookupFunction<_CamC,     _CamD>    ('nativeSetCamera');
      _setBudget    = lib.lookupFunction<_BudgetC,  _BudgetD> ('nativeSetPointBudget');
      _getRingBuffer= lib.lookupFunction<_RingBufC, _RingBufD>('nativeGetRingBuffer');
      _flushRing    = lib.lookupFunction<_FlushC,   _FlushD>  ('nativeFlushRing');
      _uploadBatch  = lib.lookupFunction<_BatchC,   _BatchD>  ('nativeUploadBatch');
      _render       = lib.lookupFunction<_VoidC,    _VoidD>   ('nativeRender');
      _destroy      = lib.lookupFunction<_VoidC,    _VoidD>   ('nativeDestroy');
      _getCount     = lib.lookupFunction<_Int32C,   _Int32D>  ('nativeGetPointCount');
      _isInit       = lib.lookupFunction<_Int32C,   _Int32D>  ('nativeIsInitialized');

      // FIX #9: optional advanced exports
      try {
        _startThread  = lib.lookupFunction<_StartThreadC, _StartThreadD>('nativeStartRenderThread');
        _stopThread   = lib.lookupFunction<_VoidC,  _VoidD>('nativeStopRenderThread');
        _pauseRender  = lib.lookupFunction<_VoidC,  _VoidD>('nativePauseRender');
        _resumeRender = lib.lookupFunction<_VoidC,  _VoidD>('nativeResumeRender');
        _frustumCull  = lib.lookupFunction<_CullC,  _CullD>('nativeFrustumCull');
        if (kDebugMode) debugPrint('[NativeRenderer] Choreographer + cull functions loaded');
      } catch (_) {
        if (kDebugMode) debugPrint('[NativeRenderer] Choreographer exports not found — polling fallback');
      }

      _available = true;
      if (kDebugMode) debugPrint('[NativeRenderer] Loaded — V49.9 9-fix');
    } catch (e) {
      _available = false;
      if (kDebugMode) debugPrint('[NativeRenderer] Fallback to CustomPainter: $e');
    }
  }

  void detectGpuTier(String chipset) {
    final s = chipset.toLowerCase();
    if (s.contains(RegExp(r'sm8[4-9]|snapdragon 8 gen [2-9]|adreno 7[3-5]'))) {
      _gpuTier = GpuTier.tier1;
    } else if (s.contains(RegExp(r'sm8[12]|sm7|adreno 6[3-9]|mali-g7[1-9]|dimensity'))) {
      _gpuTier = GpuTier.tier2;
    } else {
      _gpuTier = GpuTier.tier3;
    }
    // FIX #5: set budget BEFORE init so C++ malloc is correctly sized
    _setBudget?.call(_gpuTier.maxPoints);
    if (kDebugMode) debugPrint('[NativeRenderer] Tier: ${_gpuTier.label} | budget: ${_gpuTier.maxPoints}');
  }

  int initialize(int width, int height) {
    if (!_available) return 0;
    return _init?.call(width, height) ?? 0;
  }

  void resize(int width, int height) => _resize?.call(width, height);

  void setCamera(double yaw, double pitch, double roll, double fov, double zoom) =>
      _setCamera?.call(yaw, pitch, roll, fov, zoom);

  /// Upload point cloud — zero-copy ring buffer path preferred.
  /// FIX #1: writes into C++'s write-side buffer; C++ swaps ping-pong on render.
  /// FIX #3: nativeFlushRing advances ring head; no memmove ever.
  /// FIX #8: nativeUploadBatch applies LOD distance cull inside C++.
  int uploadPoints(Float32List data, int pointCount) {
    if (!_available || pointCount <= 0) return 0;
    final floatCount = pointCount * kPointStride;

    // ── Path A: Zero-copy ring buffer ────────────────────────────────────────
    if (_getRingBuffer != null && _flushRing != null) {
      if (_ringBuffer == null || _ringBufCapacity < floatCount) {
        // C++ owns this memory; we just keep the pointer
        _ringBuffer = _getRingBuffer!.call(floatCount);
        _ringBufCapacity = floatCount;
      }
      if (_ringBuffer != null && _ringBuffer! != ffi.nullptr) {
        _ringBuffer!.asTypedList(floatCount).setAll(0, data.sublist(0, floatCount));
        return _flushRing!.call(pointCount);
      }
    }

    // ── Path B: Calloc batch (LOD cull happens in C++) ────────────────────────
    if (_uploadBatch == null) return 0;
    if (_batchBuffer == null || _batchBufCapacity < floatCount) {
      if (_batchBuffer != null) ffiPkg.calloc.free(_batchBuffer!);
      _batchBuffer = ffiPkg.calloc<ffi.Float>(floatCount);
      _batchBufCapacity = floatCount;
    }
    _batchBuffer!.asTypedList(floatCount).setAll(0, data.sublist(0, floatCount));
    return _uploadBatch!.call(_batchBuffer!, pointCount);
  }

  // FIX #9: Dart-side pause/resume — calls MethodChannel which Kotlin forwards
  // to nativePauseRender / nativeResumeRender on the render thread.
  Future<void> pauseRender() async {
    if (_pauseRender != null) {
      _pauseRender!.call();
    } else {
      await _rendererChannel.invokeMethod('pauseRender');
    }
  }

  Future<void> resumeRender() async {
    if (_resumeRender != null) {
      _resumeRender!.call();
    } else {
      await _rendererChannel.invokeMethod('resumeRender');
    }
  }

  void render()         => _render?.call();
  int  getPointCount()  => _getCount?.call() ?? 0;
  bool isInitialized()  => (_isInit?.call() ?? 0) != 0;

  void destroy() {
    if (_batchBuffer != null) {
      ffiPkg.calloc.free(_batchBuffer!);
      _batchBuffer = null;
      _batchBufCapacity = 0;
    }
    // Ring buffer is C++-owned — just null the pointer
    _ringBuffer = null;
    _ringBufCapacity = 0;
    _destroy?.call();
  }
}
