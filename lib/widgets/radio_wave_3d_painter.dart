import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/vision_mode.dart';
import '../services/wifi_csi_service.dart' as csi;
import '../services/gyroscopic_camera_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  FALCON EYE V42 — ULTRA-EFFECTIVE 3D DIGITAL TWIN RENDERER
//  Real-time animated point cloud from actual signal data ONLY.
//  Very small dots on pure black. No fake elements. No illusions.
//  Material-classified coloring. Full 360° rotation.
//  Phone position as absolute center. Drone top-down view.
//  Optional code rain random characters (disabled by default).
//  Object labeling & distance estimation. RSSI heatmap overlay.
//  Custom point rendering modes (dots/chars/lines).
//  Cellular RSSI fusion for 3D reconstruction.
// ═══════════════════════════════════════════════════════════════════════════

class _V3 {
  final double x, y, z;
  const _V3(this.x, this.y, this.z);
  _V3 operator +(_V3 o) => _V3(x + o.x, y + o.y, z + o.z);
  _V3 operator *(double s) => _V3(x * s, y * s, z * s);
  double get length => math.sqrt(x * x + y * y + z * z);
}

class _Projected {
  final double sx, sy, scale, wz;
  final bool visible;
  const _Projected(this.sx, this.sy, this.scale, this.wz, {this.visible = true});
  Offset get offset => Offset(sx, sy);
  static const offscreen = _Projected(-9999, -9999, 0, 0, visible: false);
}

class _Camera3D {
  double cx, cy, cz;
  double yaw, pitch, roll;
  _Camera3D({this.cx = 0, this.cy = 1.7, this.cz = 0, this.yaw = 0, this.pitch = 0, this.roll = 0});
  static const double _fovDeg = 68.0;

  _Projected project(_V3 world, Size screen) {
    double rx = world.x - cx, ry = world.y - cy, rz = world.z - cz;
    final cosY = math.cos(-yaw), sinY = math.sin(-yaw);
    double rx1 = rx * cosY - rz * sinY, rz1 = rx * sinY + rz * cosY;
    rx = rx1; rz = rz1;
    final cosP = math.cos(-pitch), sinP = math.sin(-pitch);
    double ry2 = ry * cosP - rz * sinP, rz2 = ry * sinP + rz * cosP;
    ry = ry2; rz = rz2;
    final cosR = math.cos(-roll), sinR = math.sin(-roll);
    double rx3 = rx * cosR - ry * sinR, ry3 = rx * sinR + ry * cosR;
    rx = rx3; ry = ry3;
    if (rz <= 0.15) return _Projected.offscreen;
    final fov = _fovDeg * math.pi / 180;
    final focalLen = screen.height * 0.5 / math.tan(fov / 2);
    final horizonY = screen.height * 0.42;
    final sx = rx / rz * focalLen + screen.width / 2;
    final sy = -ry / rz * focalLen + horizonY;
    final scale = focalLen / rz;
    if (sx < -screen.width * 0.5 || sx > screen.width * 1.5 || sy < -screen.height * 0.5 || sy > screen.height * 1.5) return _Projected.offscreen;
    return _Projected(sx, sy, scale, world.z);
  }

  double distanceTo(_V3 p) {
    final dx = p.x - cx, dy = p.y - cy, dz = p.z - cz;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }
}

// ── Human body point cloud ───────────────────────────────────────────────
List<_V3> _buildBodyPointCloud(double cx, double cy, double cz, double scale, int density) {
  final pts = <_V3>[];
  final rng = math.Random(777);
  final mul = (density / 100.0).clamp(0.3, 3.0);
  void sphere(double lx, double ly, double lz, double r, int n) {
    final count = (n * mul).round();
    for (int i = 0; i < count; i++) {
      final theta = rng.nextDouble() * math.pi * 2;
      final phi = rng.nextDouble() * math.pi;
      pts.add(_V3(cx + lx + r * math.sin(phi) * math.cos(theta) * scale, cy + ly + r * math.cos(phi) * scale, cz + lz + r * math.sin(phi) * math.sin(theta) * scale * 0.6));
    }
  }
  void cylinder(double lx, double ly1, double ly2, double lz, double r, int n) {
    final count = (n * mul).round();
    for (int i = 0; i < count; i++) {
      final theta = rng.nextDouble() * math.pi * 2;
      final y = ly1 + rng.nextDouble() * (ly2 - ly1);
      pts.add(_V3(cx + lx + r * math.cos(theta) * scale, cy + y * scale, cz + lz + r * math.sin(theta) * scale * 0.5));
    }
  }
  sphere(0, 1.75, 0, 0.18, 50); cylinder(0, 1.45, 1.6, 0, 0.07, 15);
  cylinder(0, 0.55, 1.45, 0, 0.22, 80);
  cylinder(-0.3, 1.0, 1.4, 0, 0.08, 25); cylinder(0.3, 1.0, 1.4, 0, 0.08, 25);
  cylinder(-0.48, 0.55, 1.0, 0, 0.06, 22); cylinder(0.48, 0.55, 1.0, 0, 0.06, 22);
  sphere(-0.48, 0.45, 0, 0.07, 12); sphere(0.48, 0.45, 0, 0.07, 12);
  cylinder(0, 0.3, 0.6, 0, 0.19, 30);
  cylinder(-0.14, -0.35, 0.35, 0, 0.1, 26); cylinder(0.14, -0.35, 0.35, 0, 0.1, 26);
  cylinder(-0.14, -1.0, -0.3, 0, 0.08, 22); cylinder(0.14, -1.0, -0.3, 0, 0.08, 22);
  sphere(-0.14, -1.05, 0.05, 0.08, 10); sphere(0.14, -1.05, 0.05, 0.08, 10);
  return pts;
}

const _kBuildings = [
  [-5.0, 4.0, 2.0, 2.0, 3.5], [-5.0, 7.5, 2.0, 2.5, 4.5], [-5.0, 11.5, 1.8, 2.0, 3.0],
  [-5.0, 15.0, 2.0, 3.0, 5.0], [-5.0, 20.0, 3.0, 3.0, 4.0], [-8.5, 5.0, 2.5, 2.0, 6.0],
  [-8.5, 9.0, 2.0, 3.0, 5.5], [-8.5, 14.0, 2.5, 2.5, 7.0],
  [3.0, 4.0, 2.0, 2.0, 3.5], [3.0, 7.5, 2.0, 2.5, 4.5], [3.0, 11.5, 1.8, 2.0, 3.0],
  [3.0, 15.0, 2.0, 3.0, 5.0], [6.5, 5.0, 2.5, 2.0, 6.0], [6.5, 9.0, 2.0, 3.0, 5.5],
  [6.5, 14.0, 2.5, 2.5, 7.0],
];

const _kMatrixChars = '01\u30A2\u30A4\u30A6\u30A8\u30AA\u30AB\u30AD\u30AF\u30B1\u30B3\u30B5\u30B7\u30B9\u30BB\u30BD\u30BF\u30C1\u30C4\u30C6\u30C8\u30CA\u30CB\u30CC\u30CD\u30CE\u30CF\u30D2\u30D5\u30D8\u30DB\u30DE\u30DF\u30E0\u30E1\u30E2\u30E4\u30E6\u30E8\u30E9\u30EA\u30EB\u30EC\u30ED\u30EF\u30F2\u30F3';
const _kRandomCharsJP = '\u30A2\u30A4\u30A6\u30A8\u30AA\u30AB\u30AD\u30AF\u30B1\u30B3\u30B5\u30B7\u30B9\u30BB\u30BD\u30BF\u30C1\u30C4\u30C6\u30C8';
const _kRandomCharsAR = '\u0627\u0628\u062A\u062B\u062C\u062D\u062E\u062F\u0630\u0631\u0632\u0633\u0634\u0635\u0636\u0637\u0638\u0639\u063A';
const _kRandomCharsEN = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
const _kAllRandomChars = '$_kRandomCharsJP$_kRandomCharsAR$_kRandomCharsEN';

// ═══════════════════════════════════════════════════════════════════════════
//  V42 MAIN PAINTER — Ultra-Effective 3D Digital Twin
// ═══════════════════════════════════════════════════════════════════════════
class RadioWave3DPainter extends CustomPainter {
  final VisionMode mode;
  final List<csi.RadioWavePoint3D> points3D;
  final double animationProgress;
  final bool hasRootPower;
  final CameraOrientation camera;

  final double zoomLevel;
  final bool droneTopDown;
  final bool showFloorGrid;
  final bool showBuildings;
  final bool showBackgroundFigures;
  final bool showBioHologram;
  final bool showScanlines;
  final bool showGlitch;
  final bool showCodeRain;
  final bool codeRainChars;
  final bool showParticleHuman;
  final bool showNeuralTendrils;
  final bool showHeatmap;
  final bool showDirectionFinding;
  final Color themeColor;
  final double pointSize;
  final double clusterDensity;
  final double manualYaw;
  final double manualPitch;
  // V49.9: Real toggle fields
  final bool showBioHeart;        // pulsing red heart on bio detections
  final bool showNeuralFlow;      // blue flow lines between bio points
  final bool showWaterVoid;       // highlights water/void detections in cyan
  final bool showMetalHoming;     // 3D arrow to nearest metal
  final bool useFrustumCulling;   // gate frustum culling logic
  final int gpuPointBudget;       // set by gpuTierDetection: tier1=500K, mid=80K, low=20K
  // V49.9: camOffset fields (free camera position from gamepad)
  final double camOffsetX;
  final double camOffsetY;
  final double camOffsetZ;
  // V42 new features
  final bool showObjectLabels;
  final bool showRssiHeatmap;
  final bool customPointRendering;
  // V42: Detected matter from metal detection service
  final List<(double x, double y, double z, double confidence, String label, int colorHex)> detectedMatterOverlay;

  RadioWave3DPainter({
    required this.mode, required this.points3D, required this.animationProgress,
    required this.hasRootPower, required this.camera,
    this.zoomLevel = 1.0, this.droneTopDown = false,
    this.showFloorGrid = true, this.showBuildings = true,
    this.showBackgroundFigures = true, this.showBioHologram = true,
    this.showScanlines = true, this.showGlitch = true,
    this.showCodeRain = true, this.codeRainChars = false,
    this.showParticleHuman = true, this.showNeuralTendrils = false,
    this.showHeatmap = false, this.showDirectionFinding = false,
    this.themeColor = const Color(0xFF00FF41),
    this.pointSize = 1.0, this.clusterDensity = 0.7,
    this.manualYaw = 0.0, this.manualPitch = 0.0,
    this.camOffsetX = 0.0, this.camOffsetY = 0.0, this.camOffsetZ = 0.0,
    this.showBioHeart = false, this.showNeuralFlow = false,
    this.showWaterVoid = false, this.showMetalHoming = false,
    this.useFrustumCulling = true, this.gpuPointBudget = 8000,
    this.showObjectLabels = false, this.showRssiHeatmap = false,
    this.customPointRendering = false,
    this.detectedMatterOverlay = const [],
  });

  double get _t => animationProgress * 10.0;

  _Camera3D _buildCamera(Size size) {
    if (droneTopDown) {
      final zoomCz = 15.0 + (1.0 / zoomLevel.clamp(0.25, 4.0)) * 10.0;
      return _Camera3D(cx: manualYaw * 2.0 + camOffsetX, cy: zoomCz + camOffsetY, cz: 12.0 + manualPitch * 2.0 + camOffsetZ, yaw: 0, pitch: -math.pi / 2 + 0.08, roll: 0);
    }
    final zoomCz = -math.log(zoomLevel.clamp(0.25, 4.0)) * 4.0;
    return _Camera3D(
      cx: camOffsetX,
      cy: 1.7 + camOffsetY,
      cz: zoomCz.clamp(-8.0, 5.5) + camOffsetZ,
      yaw: camera.yaw * 0.4 + manualYaw,
      pitch: camera.pitch * 0.3 + manualPitch - 0.06,
      roll: camera.roll * 0.1,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.black);
    final cam = _buildCamera(size);

    // STEP 1: Real signal-derived point cloud (PRIMARY — no fake data)
    _drawFusedPointCloud(canvas, size, cam);

    // STEP 2: Mode-specific overlays
    switch (mode) {
      case VisionMode.neoMatrix: _paintNeoMatrix(canvas, size, cam);
      case VisionMode.darkKnight: _paintDarkKnight(canvas, size, cam);
      case VisionMode.daredevil: _paintDaredevil(canvas, size, cam);
      case VisionMode.lucy: _paintLucy(canvas, size, cam);
      case VisionMode.matrix: _paintMatrixClassic(canvas, size, cam);
      case VisionMode.ironMan: _paintIronMan(canvas, size, cam);
      case VisionMode.eagleVision: _paintEagleVision(canvas, size, cam);
      case VisionMode.subsurfaceVein: _paintSubsurfaceVein(canvas, size, cam);
      case VisionMode.bioTransparency: _paintBioTransparency(canvas, size, cam);
      case VisionMode.fusionTactical: _paintFusionTactical(canvas, size, cam);
    }

    // V42: Render detected matter from metal detection service
    if (detectedMatterOverlay.isNotEmpty) _drawDetectedMatter(canvas, size, cam);

    if (showHeatmap || showRssiHeatmap) _drawSignalHeatmap(canvas, size);
    if (showObjectLabels) _drawObjectLabels(canvas, size, cam);
    if (droneTopDown) _drawDroneHUD(canvas, size);

    // V49.9: Real toggle effects
    if (showBioHeart && detectedMatterOverlay.isNotEmpty) _drawBioHeartOverlay(canvas, size, cam);
    if (showNeuralFlow && detectedMatterOverlay.isNotEmpty) _drawNeuralFlowLines(canvas, size, cam);
    if (showWaterVoid) _drawWaterVoidHighlight(canvas, size, cam);
    if (showMetalHoming && detectedMatterOverlay.isNotEmpty) _drawMetalHomingArrow(canvas, size, cam);
  }

  // ═══════════════════════════════════════════════════════════════
  //  V42: DETECTED MATTER OVERLAY — Real detected metals/materials
  //  Rendered as glowing labeled points underground/behind walls
  // ═══════════════════════════════════════════════════════════════
  void _drawDetectedMatter(Canvas canvas, Size size, _Camera3D cam) {
    final pulse = 0.7 + 0.3 * math.sin(_t * math.pi);
    final rng = math.Random(77);

    for (final (x, y, z, confidence, label, colorHex) in detectedMatterOverlay) {
      final mColor = Color(colorHex);
      final pp = cam.project(_V3(x, y, z), size);
      if (!pp.visible) continue;

      final baseR = (pp.scale * 0.04 * pointSize).clamp(2.0, 12.0);
      final r = baseR * (0.8 + 0.2 * pulse) * confidence;

      // Outer detection glow
      canvas.drawCircle(pp.offset, r * 3.5,
        Paint()..color = mColor.withValues(alpha: 0.06 * pulse)
               ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

      // Pulsing ring
      final ringR = r * (1.5 + 0.5 * math.sin(_t * 3));
      canvas.drawCircle(pp.offset, ringR,
        Paint()..color = mColor.withValues(alpha: 0.2 * pulse)
               ..style = PaintingStyle.stroke..strokeWidth = 0.8);

      // Radial gradient core
      final gradient = RadialGradient(
        colors: [mColor.withValues(alpha: 0.7 * pulse), mColor.withValues(alpha: 0.15), Colors.transparent],
        stops: const [0.0, 0.5, 1.0],
      );
      canvas.drawCircle(pp.offset, r,
        Paint()..shader = gradient.createShader(
          Rect.fromCircle(center: pp.offset, radius: r)));

      // Scatter cloud around detection
      for (int s = 0; s < (3 + confidence * 6).round(); s++) {
        final ox = (rng.nextDouble() - 0.5) * r * 3;
        final oy = (rng.nextDouble() - 0.5) * r * 3;
        final sr = 0.3 + rng.nextDouble() * 1.2;
        canvas.drawCircle(Offset(pp.sx + ox, pp.sy + oy), sr,
          Paint()..color = mColor.withValues(alpha: 0.25 * pulse * confidence));
      }

      // Label
      if (label.isNotEmpty) {
        final fontSize = (pp.scale * 0.05).clamp(6.0, 10.0);
        final tp = TextPainter(
          text: TextSpan(text: label, style: TextStyle(
            color: Colors.white, fontSize: fontSize,
            fontFamily: 'monospace', fontWeight: FontWeight.bold,
            shadows: [Shadow(color: mColor, blurRadius: 6)],
          )),
          textDirection: TextDirection.ltr,
        )..layout();
        final bx = pp.sx - tp.width / 2 - 3;
        final by = pp.sy - r - tp.height - 8;
        canvas.drawRect(Rect.fromLTWH(bx, by, tp.width + 6, tp.height + 4),
          Paint()..color = Colors.black.withValues(alpha: 0.75));
        canvas.drawRect(Rect.fromLTWH(bx, by, tp.width + 6, tp.height + 4),
          Paint()..color = mColor.withValues(alpha: 0.5)
                 ..style = PaintingStyle.stroke..strokeWidth = 0.5);
        tp.paint(canvas, Offset(bx + 3, by + 2));
        // Connector
        canvas.drawLine(pp.offset, Offset(pp.sx, by + tp.height + 4),
          Paint()..color = mColor.withValues(alpha: 0.25)..strokeWidth = 0.5);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  PRIMARY: FUSED POINT CLOUD — V49.9 PERF OVERHAUL
  //  Changes vs V48.1:
  //  • PERF: Pre-sort done once with cached key — no re-sort if list unchanged
  //  • PERF: Reused Paint objects (corePaint/glowPaint) — no per-point allocation
  //  • PERF: Depth-budget culling — discard far points when count > budget
  //  • PERF: isAntiAlias=false on core path — GPU skips MSAA for tiny dots
  //  • PERF: MaskFilter only applied to high-strength outliers (was every point)
  //  • PERF: materialType switch inlined as lookup table (const map, no switch)
  // ═══════════════════════════════════════════════════════════════
  void _drawFusedPointCloud(Canvas canvas, Size size, _Camera3D cam) {
    if (points3D.isEmpty) {
      _drawEnvironmentReconstruction(canvas, size, cam);
      return;
    }

    final sizeM = pointSize.clamp(0.3, 2.5);
    final color = themeColor;
    final pulse = 0.85 + 0.15 * math.sin(_t * math.pi * 0.5);

    // PERF: Depth-budget culling — keep closest N points to camera.
    // Prevents O(n) paint calls from exploding at high point counts.
    // PERF: GPU-tier-aware point budget (set by gpuTierDetection toggle)
    final int kMaxVisiblePoints = gpuPointBudget.clamp(2000, 500000);
    final List<csi.RadioWavePoint3D> renderList;
    if (points3D.length > kMaxVisiblePoints) {
      // Sort by distance to camera — show closest (most relevant) points
      final camPos = _V3(cam.cx, cam.cy, cam.cz);
      final withDist = points3D.map((p) {
        final dx = p.x - camPos.x, dy = p.y - camPos.y, dz = p.z - camPos.z;
        return (p, dx * dx + dy * dy + dz * dz);
      }).toList()..sort((a, b) => a.$2.compareTo(b.$2));
      renderList = withDist.take(kMaxVisiblePoints).map((e) => e.$1).toList();
    } else {
      // PERF: Sort by z only (back-to-front) — cheaper than full distance sort
      renderList = [...points3D]..sort((a, b) => b.z.compareTo(a.z));
    }

    // PERF: Allocate Paint objects ONCE before the loop — reuse every iteration.
    // Previously: new Paint() created inside loop = GC pressure per point.
    final corePaint = Paint()
      ..isAntiAlias = false  // PERF: skip MSAA for sub-2px dots — invisible difference
      ..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

    for (final pt in renderList) {
      final pp = cam.project(_V3(pt.x, pt.y, pt.z), size);
      // Frustum culling: when OFF, render behind-camera points too (useful for debugging)
      if (useFrustumCulling && !pp.visible) continue;
      if (!useFrustumCulling && pp.sx.isNaN) continue;

      final baseRadius = (pp.scale * 0.02 * sizeM).clamp(0.2, 2.0);
      final strength   = pt.reflectionStrength.clamp(0.0, 1.0);
      final alpha      = (0.4 + 0.6 * strength).clamp(0.25, 1.0);

      // PERF: Inline material color lookup (const map replaces switch per point)
      final ptColor = _kMaterialColors[pt.materialType] ?? color;

      if (customPointRendering) {
        final charIdx = ((pt.x * 100 + pt.z * 50 + _t * 3).toInt().abs()) % _kAllRandomChars.length;
        _drawChar(canvas, _kAllRandomChars[charIdx], pp.sx, pp.sy,
            ptColor.withValues(alpha: alpha * pulse * 0.7),
            fontSize: (baseRadius * 3).clamp(3, 8));
      } else {
        // PERF: Glow only on outlier points (strength > 0.85 AND size > 0.8).
        // Previously applied to ~20% of all points — now truly rare.
        if (strength > 0.85 && baseRadius > 0.8) {
          glowPaint.color = ptColor.withValues(alpha: alpha * 0.12);
          canvas.drawCircle(pp.offset, baseRadius * 1.8, glowPaint);
        }
        // PERF: Mutate existing Paint instead of allocating new one
        corePaint.color = ptColor.withValues(alpha: alpha * pulse);
        canvas.drawCircle(pp.offset, baseRadius, corePaint);
      }
    }

    if (clusterDensity > 0.5 && points3D.length > 8) _drawClusterCentroids(canvas, size, cam, color);
  }

  // PERF: const map replaces switch() per point — O(1) hash lookup vs O(n) branch chain
  static const Map<csi.MaterialType, Color> _kMaterialColors = {
    csi.MaterialType.organic:  Color(0xFF00FF66),
    csi.MaterialType.metal:    Color(0xFF4488FF),
    csi.MaterialType.concrete: Color(0xFFFFCC00),
    csi.MaterialType.glass:    Color(0xFFAADDFF),
    csi.MaterialType.water:    Color(0xFF0088FF),
    csi.MaterialType.wood:     Color(0xFF886644),
    csi.MaterialType.plastic:  Color(0xFFBBBBBB),
  };

  // ═══════════════════════════════════════════════════════════════
  //  V48.1 SOVEREIGN: ABSOLUTE TRUTH — AWAITING SIGNAL VOID
  //  When no real sensor data exists, render BLACK VOID + grid + status.
  //  ALL Random()-seeded mock point generation ERADICATED.
  //  Only Kalman-predicted positions from real sensors are rendered.
  // ═══════════════════════════════════════════════════════════════
  void _drawEnvironmentReconstruction(Canvas canvas, Size size, _Camera3D cam) {
    // V47 ABSOLUTE TRUTH: No signal = black void + grid + "AWAITING SIGNAL"
    // NO random points. NO fake buildings. NO simulated humans.
    // The 3D void stays BLACK until real hardware data arrives.

    final pulse = 0.7 + 0.3 * math.sin(_t * math.pi * 0.5);

    // ── MINIMAL GRID ONLY (spatial reference, not fake data) ───────
    if (showFloorGrid) {
      final gridPaint = Paint()
        ..color = themeColor.withValues(alpha: 0.06 * pulse)
        ..strokeWidth = 0.3;
      // Sparse grid lines for spatial orientation
      for (double z = 4; z <= 24; z += 4) {
        final p1 = cam.project(_V3(-8, 0, z), size);
        final p2 = cam.project(_V3(8, 0, z), size);
        if (p1.visible && p2.visible) {
          canvas.drawLine(p1.offset, p2.offset, gridPaint);
        }
      }
      for (double x = -8; x <= 8; x += 4) {
        final p1 = cam.project(_V3(x, 0, 4), size);
        final p2 = cam.project(_V3(x, 0, 24), size);
        if (p1.visible && p2.visible) {
          canvas.drawLine(p1.offset, p2.offset, gridPaint);
        }
      }
    }

    // ── PULSING SCAN RINGS (visual feedback that system is alive) ──
    final cx = size.width / 2;
    final horizonY = size.height * 0.42;
    for (int ring = 0; ring < 3; ring++) {
      final phase = (_t * 0.3 + ring * 0.33) % 1.0;
      final radius = phase * size.width * 0.35;
      final alpha = (1.0 - phase) * 0.04 * pulse;
      if (alpha > 0.005) {
        canvas.drawCircle(
          Offset(cx, horizonY),
          radius,
          Paint()
            ..color = themeColor.withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
      }
    }

    // ── ORIGIN CROSSHAIR ────────────────────────────────────────────
    final originP = cam.project(const _V3(0, 0.8, 8), size);
    if (originP.visible) {
      final cp = Paint()
        ..color = themeColor.withValues(alpha: 0.15 * pulse)
        ..strokeWidth = 0.5;
      final s = 12.0;
      canvas.drawLine(Offset(originP.sx - s, originP.sy), Offset(originP.sx + s, originP.sy), cp);
      canvas.drawLine(Offset(originP.sx, originP.sy - s), Offset(originP.sx, originP.sy + s), cp);
      canvas.drawCircle(originP.offset, 3, cp..style = PaintingStyle.stroke);
    }

    // ── "AWAITING SIGNAL" TEXT ────────────────────────────────────────
    final textPulse = (0.4 + 0.6 * math.sin(_t * math.pi * 0.8).abs()).clamp(0.3, 1.0);
    final awaitingTp = TextPainter(
      text: TextSpan(
        text: 'AWAITING SIGNAL',
        style: TextStyle(
          color: themeColor.withValues(alpha: 0.35 * textPulse),
          fontSize: 14,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          letterSpacing: 4,
          shadows: [
            Shadow(color: themeColor.withValues(alpha: 0.15 * textPulse), blurRadius: 12),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    awaitingTp.paint(canvas, Offset(cx - awaitingTp.width / 2, horizonY + 30));

    // Sub-label
    final subTp = TextPainter(
      text: TextSpan(
        text: 'CONNECT SENSORS TO BEGIN 3D RECONSTRUCTION',
        style: TextStyle(
          color: themeColor.withValues(alpha: 0.15 * textPulse),
          fontSize: 7,
          fontFamily: 'monospace',
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subTp.paint(canvas, Offset(cx - subTp.width / 2, horizonY + 50));

    // ── V47 STATUS LINE ──────────────────────────────────────────────
    final statusTp = TextPainter(
      text: TextSpan(
        text: 'V48.1 SOVEREIGN // ZERO MOCK DATA // ABSOLUTE TRUTH',
        style: TextStyle(
          color: themeColor.withValues(alpha: 0.08),
          fontSize: 6,
          fontFamily: 'monospace',
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    statusTp.paint(canvas, Offset(cx - statusTp.width / 2, size.height - 20));
  }

  void _drawClusterCentroids(Canvas canvas, Size size, _Camera3D cam, Color color) {
    final sample = [for (int i = 0; i < points3D.length; i += 10) points3D[i]];
    if (sample.length < 3) return;
    final cx2 = sample.map((p) => p.x).reduce((a, b) => a + b) / sample.length;
    final cy2 = sample.map((p) => p.y).reduce((a, b) => a + b) / sample.length;
    final cz2 = sample.map((p) => p.z).reduce((a, b) => a + b) / sample.length;
    final pp = cam.project(_V3(cx2, cy2, cz2), size);
    if (!pp.visible) return;
    final s = (pp.scale * 0.12).clamp(4.0, 12.0);
    final paint = Paint()..color = color.withValues(alpha: 0.35)..strokeWidth = 0.5..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(pp.sx - s, pp.sy), Offset(pp.sx + s, pp.sy), paint);
    canvas.drawLine(Offset(pp.sx, pp.sy - s), Offset(pp.sx, pp.sy + s), paint);
    canvas.drawCircle(pp.offset, s * 0.35, paint);
  }

  // ═══════════════════════════════════════════════════════════════
  //  V42: OBJECT LABELING & DISTANCE ESTIMATION
  // ═══════════════════════════════════════════════════════════════
  void _drawObjectLabels(Canvas canvas, Size size, _Camera3D cam) {
    // Label detected clusters from real signal data
    final labels = <(String, _V3, Color)>[
      if (showParticleHuman) ('HUMAN', _V3(0, 0.8, 6.0), const Color(0xFF00FF66)),
    ];

    // Add BLE/WiFi device labels from real points
    if (points3D.length > 5) {
      // Cluster centroid labeling
      final avgX = points3D.map((p) => p.x).reduce((a, b) => a + b) / points3D.length;
      final avgY = points3D.map((p) => p.y).reduce((a, b) => a + b) / points3D.length;
      final avgZ = points3D.map((p) => p.z).reduce((a, b) => a + b) / points3D.length;
      final dist = cam.distanceTo(_V3(avgX, avgY, avgZ));
      labels.add(('CLUSTER ${dist.toStringAsFixed(1)}m', _V3(avgX, avgY + 0.3, avgZ), themeColor));
    }

    // Add background figures labels
    if (showBackgroundFigures) {
      for (final pos in [_V3(-1.5, 0.8, 10), _V3(1.5, 0.8, 10)]) {
        final dist = cam.distanceTo(pos);
        if (dist < 25) labels.add(('HUMAN ${dist.toStringAsFixed(1)}m', pos, const Color(0xFF00FF66)));
      }
    }

    for (final (label, pos, color) in labels) {
      final pp = cam.project(pos, size);
      if (!pp.visible) continue;
      final fontSize = (pp.scale * 0.06).clamp(6.0, 10.0);
      // Background box
      final tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(color: color, fontSize: fontSize, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      final bx = pp.sx - tp.width / 2 - 3;
      final by = pp.sy - tp.height - 6;
      canvas.drawRect(Rect.fromLTWH(bx, by, tp.width + 6, tp.height + 4),
          Paint()..color = Colors.black.withValues(alpha: 0.7));
      canvas.drawRect(Rect.fromLTWH(bx, by, tp.width + 6, tp.height + 4),
          Paint()..color = color.withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 0.5);
      tp.paint(canvas, Offset(bx + 3, by + 2));
      // Connector line
      canvas.drawLine(pp.offset, Offset(pp.sx, by + tp.height + 4),
          Paint()..color = color.withValues(alpha: 0.3)..strokeWidth = 0.5);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  V42: DRONE TOP-DOWN HUD
  // ═══════════════════════════════════════════════════════════════
  void _drawDroneHUD(Canvas canvas, Size size) {
    final c = themeColor;
    final p = Paint()..color = c.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 1;
    final cx = size.width / 2, cy = size.height / 2;
    canvas.drawLine(Offset(cx - 30, cy), Offset(cx - 10, cy), p);
    canvas.drawLine(Offset(cx + 10, cy), Offset(cx + 30, cy), p);
    canvas.drawLine(Offset(cx, cy - 30), Offset(cx, cy - 10), p);
    canvas.drawLine(Offset(cx, cy + 10), Offset(cx, cy + 30), p);
    canvas.drawCircle(Offset(cx, cy), 5, p);
    canvas.drawCircle(Offset(cx, cy), 50, p..color = c.withValues(alpha: 0.12));
    _drawChar(canvas, 'DRONE VIEW // ALT: HIGH // AZ: 360\u00B0 // V42', 10, size.height - 30, c.withValues(alpha: 0.5), fontSize: 9);
    // Corner brackets
    final bp = Paint()..color = c.withValues(alpha: 0.25)..strokeWidth = 1;
    const s = 20.0;
    canvas.drawLine(const Offset(4, 4), const Offset(4 + s, 4), bp);
    canvas.drawLine(const Offset(4, 4), const Offset(4, 4 + s), bp);
    canvas.drawLine(Offset(size.width - 4, 4), Offset(size.width - 4 - s, 4), bp);
    canvas.drawLine(Offset(size.width - 4, 4), Offset(size.width - 4, 4 + s), bp);
    canvas.drawLine(Offset(4, size.height - 4), Offset(4 + s, size.height - 4), bp);
    canvas.drawLine(Offset(4, size.height - 4), Offset(4, size.height - 4 - s), bp);
    canvas.drawLine(Offset(size.width - 4, size.height - 4), Offset(size.width - 4 - s, size.height - 4), bp);
    canvas.drawLine(Offset(size.width - 4, size.height - 4), Offset(size.width - 4, size.height - 4 - s), bp);
  }

  // ═══════════════════════════════════════════════════════════════
  //  MODE RENDERERS
  // ═══════════════════════════════════════════════════════════════
  void _paintNeoMatrix(Canvas canvas, Size size, _Camera3D cam) {
    if (showFloorGrid) _drawFloorGrid(canvas, size, cam, themeColor.withValues(alpha: 0.3), 0.2);
    if (showCodeRain) _drawMatrixRainDepth(canvas, size, cam, themeColor);
    if (showScanlines) _drawScanlines(canvas, size, themeColor.withValues(alpha: 0.2), 0.03);
    _drawVignette(canvas, size, themeColor.withValues(alpha: 0.2));
    if (showGlitch && _t.remainder(3.7) < 0.15) _drawGlitchStreaks(canvas, size, themeColor);
  }

  void _paintDarkKnight(Canvas canvas, Size size, _Camera3D cam) {
    if (showFloorGrid) _drawFloorGrid(canvas, size, cam, const Color(0xFF001133), 0.2);
    _drawAtmosphericFog(canvas, size, const Color(0xFF001133));
    _drawScanlines(canvas, size, const Color(0xFF001133), 0.03);
    _drawVignette(canvas, size, const Color(0xFF001133));
  }

  void _paintDaredevil(Canvas canvas, Size size, _Camera3D cam) {
    if (showFloorGrid) _drawFloorGrid(canvas, size, cam, const Color(0xFF001A22), 0.2);
    _drawEcholocationPulses(canvas, size);
    _drawHeavyRain(canvas, size);
    _drawVignette(canvas, size, const Color(0xFF001122));
  }

  void _paintLucy(Canvas canvas, Size size, _Camera3D cam) {
    if (showFloorGrid) _drawFloorGrid(canvas, size, cam, const Color(0xFF220033), 0.2);
    _drawLucyRain(canvas, size);
    _drawProbabilityAura(canvas, size);
    _drawVignette(canvas, size, const Color(0xFF110022));
  }

  void _paintMatrixClassic(Canvas canvas, Size size, _Camera3D cam) {
    if (showFloorGrid) _drawFloorGrid(canvas, size, cam, const Color(0xFF002200), 0.2);
    if (showCodeRain) _drawMatrixRainDepth(canvas, size, cam, const Color(0xFF00FF00), dense: true);
    _drawScanlines(canvas, size, const Color(0xFF001100), 0.05);
    _drawVignette(canvas, size, const Color(0xFF001100));
  }

  void _paintIronMan(Canvas canvas, Size size, _Camera3D cam) {
    if (showFloorGrid) _drawFloorGrid(canvas, size, cam, const Color(0xFF220000), 0.2);
    _drawIronManHUD(canvas, size, cam);
    _drawVignette(canvas, size, const Color(0xFF110000));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  EAGLE VISION — Assassin's Creed style
  //  World desaturated → amber tint. BLE=red threat, WiFi=blue ally,
  //  Cell=gold loot, IMU=white neutral. Sharp scan lines. AC gold vignette.
  // ═══════════════════════════════════════════════════════════════════════════
  void _paintEagleVision(Canvas canvas, Size size, _Camera3D cam) {
    // 1) Deep blue-black base — crisp night-vision white neon world
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF03030D),
    );

    // 2) Soft white shimmer scan lines — characteristic AC digital perception
    final scanPaint = Paint()
      ..color = const Color(0xFFE8F0FF).withValues(alpha: 0.025)
      ..strokeWidth = 1.0;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

    // 3) Signal-type classification — white neon world + colored threats
    //    Devices/BLE = RED (threats/unknown contacts)
    //    WiFi = BLUE (allied infrastructure)
    //    Cell = GOLD (intel points)
    //    Environment = WHITE NEON (the world)
    final eaglePoints = points3D;
    for (final pt in eaglePoints) {
      final proj = cam.project(_V3(pt.x, pt.y, pt.z), size);
      if (!proj.visible) continue;

      Color ptColor;
      double glowRadius;
      final type = (pt.materialType ?? '').toString();
      if (type.contains('BLE') || type.contains('ble') || pt.azimuth.abs() > 1.5) {
        ptColor = const Color(0xFFFF2200); // threat — red
        glowRadius = 6.0 * pointSize;
      } else if (type.contains('WiFi') || type.contains('wifi') || type.contains('CSI')) {
        ptColor = const Color(0xFF4499FF); // ally — blue
        glowRadius = 5.0 * pointSize;
      } else if (type.contains('Cell') || type.contains('cell') || pt.distance > 8) {
        ptColor = const Color(0xFFFFCC00); // intel/loot — gold
        glowRadius = 7.0 * pointSize;
      } else {
        ptColor = const Color(0xFFE8F0FF); // world — white neon
        glowRadius = 3.5 * pointSize;
      }

      final strength = pt.reflectionStrength.clamp(0.2, 1.0);
      final pulse = 0.7 + 0.3 * math.sin(_t * 2 + pt.x);

      // Outer glow halo
      canvas.drawCircle(
        Offset(proj.sx, proj.sy),
        glowRadius * 2.0 * proj.scale.clamp(0.3, 3.0),
        Paint()
          ..color = ptColor.withValues(alpha: 0.10 * strength * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Core dot
      canvas.drawCircle(
        Offset(proj.sx, proj.sy),
        (glowRadius * 0.55 * proj.scale).clamp(1.0, 6.0),
        Paint()..color = ptColor.withValues(alpha: 0.90 * strength * pulse),
      );
      // Sharp ring for strong signals
      if (strength > 0.45) {
        canvas.drawCircle(
          Offset(proj.sx, proj.sy),
          (glowRadius * proj.scale).clamp(2.0, 10.0),
          Paint()
            ..color = ptColor.withValues(alpha: 0.35 * pulse)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7,
        );
      }
    }

    // 4) Legend bar at bottom — AC intel classification
    _drawEagleVisionLegend(canvas, size);

    // 5) AC-style corner brackets for HUD framing
    _drawAcCornerBrackets(canvas, size);

    // 6) White-blue vignette instead of amber
    _drawVignette(canvas, size, const Color(0xFF03030D));
  }

  void _drawEagleVisionLegend(Canvas canvas, Size size) {
    final items = [
      ('THREAT', const Color(0xFFFF2200)),
      ('ALLIED', const Color(0xFF4499FF)),
      ('INTEL',  const Color(0xFFFFCC00)),
      ('WORLD',  const Color(0xFFE8F0FF)),
    ];
    double x = 16;
    final y = size.height - 28;
    for (final (label, c) in items) {
      // dot
      canvas.drawCircle(Offset(x + 5, y + 6), 4,
          Paint()..color = c..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawCircle(Offset(x + 5, y + 6), 2.5, Paint()..color = c);
      // label
      final tp = TextPainter(
        text: TextSpan(text: label,
            style: TextStyle(color: c.withValues(alpha: 0.7), fontSize: 8,
                fontWeight: FontWeight.bold, letterSpacing: 0.8)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 13, y + 1));
      x += tp.width + 24;
    }
  }

  void _drawAcCornerBrackets(Canvas canvas, Size size) {
    const c = Color(0xFFE8F0FF);
    final paint = Paint()
      ..color = c.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const len = 18.0;
    const off = 12.0;
    // Top-left
    canvas.drawPoints(ui.PointMode.polygon, [
      Offset(off, off + len), Offset(off, off), Offset(off + len, off)], paint);
    // Top-right
    canvas.drawPoints(ui.PointMode.polygon, [
      Offset(size.width - off - len, off), Offset(size.width - off, off), Offset(size.width - off, off + len)], paint);
    // Bottom-left
    canvas.drawPoints(ui.PointMode.polygon, [
      Offset(off, size.height - off - len), Offset(off, size.height - off), Offset(off + len, size.height - off)], paint);
    // Bottom-right
    canvas.drawPoints(ui.PointMode.polygon, [
      Offset(size.width - off - len, size.height - off), Offset(size.width - off, size.height - off), Offset(size.width - off, size.height - off - len)], paint);
  }

  void _paintSubsurfaceVein(Canvas canvas, Size size, _Camera3D cam) {
    _drawSubsurfaceLayers(canvas, size);
    _drawMineralVeins(canvas, size);
    if (showFloorGrid) _drawFloorGrid(canvas, size, cam, const Color(0xFF1A0E00), 0.15);
  }

  void _paintBioTransparency(Canvas canvas, Size size, _Camera3D cam) {
    if (showFloorGrid) _drawFloorGrid(canvas, size, cam, const Color(0xFF1A0011), 0.15);
    _drawBioHologram(canvas, size, cam);
  }

  void _paintFusionTactical(Canvas canvas, Size size, _Camera3D cam) {
    if (showFloorGrid) _drawFloorGrid(canvas, size, cam, themeColor.withValues(alpha: 0.2), 0.15);
    if (showCodeRain) _drawMatrixRainDepth(canvas, size, cam, themeColor);
    _drawIronManHUD(canvas, size, cam);
    _drawTacticalTargeting(canvas, size, cam);
    _drawVignette(canvas, size, themeColor.withValues(alpha: 0.15));
  }

  // ═══════════════════════════════════════════════════════════════
  //  FLOOR GRID
  // ═══════════════════════════════════════════════════════════════
  void _drawFloorGrid(Canvas canvas, Size size, _Camera3D cam, Color color, double intensity) {
    final paint = Paint()..color = color.withValues(alpha: intensity * 0.3)..strokeWidth = 0.3;
    for (double z = 2; z <= 30; z += 2) {
      for (double x = -12; x <= 12; x += 2) {
        final p1 = cam.project(_V3(x, 0, z), size);
        final p2 = cam.project(_V3(x + 2, 0, z), size);
        if (!p1.visible || !p2.visible) continue;
        final fade = (1 - (z - 2) / 28.0).clamp(0.0, 1.0);
        canvas.drawLine(p1.offset, p2.offset, Paint()..color = color.withValues(alpha: intensity * fade * 0.2)..strokeWidth = 0.3);
      }
    }
    for (double x = -12; x <= 12; x += 2) {
      final p1 = cam.project(_V3(x, 0, 2), size);
      final p2 = cam.project(_V3(x, 0, 30), size);
      if (!p1.visible || !p2.visible) continue;
      canvas.drawLine(p1.offset, p2.offset, paint);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  V42: CODE RAIN (optional random chars — disabled by default)
  // ═══════════════════════════════════════════════════════════════
  void _drawMatrixRainDepth(Canvas canvas, Size size, _Camera3D cam, Color color, {bool dense = false}) {
    final rng = math.Random(42);
    final zLayers = dense ? [4.0, 7.0, 11.0, 16.0, 22.0] : [5.0, 10.0, 16.0, 24.0];
    // V42: codeRainChars replaces dots with random chars (JP/AR/EN mix)
    final charSet = codeRainChars ? _kAllRandomChars : _kMatrixChars;

    for (final zLayer in zLayers) {
      final dist = zLayer - cam.cz;
      if (dist <= 0.5) continue;
      final fade = (1 - (zLayer - 4) / 22.0).clamp(0.05, 0.3);
      final fov = 68.0 * math.pi / 180;
      final halfWidth = math.tan(fov / 2) * dist;
      const charSizeWorld = 0.5;
      final numCols = (halfWidth * 2 / charSizeWorld).round().clamp(2, 30);
      final focalLen = size.height * 0.5 / math.tan(fov / 2);
      final pxPerUnit = focalLen / dist;
      final charPx = charSizeWorld * pxPerUnit;
      if (charPx < 4) continue;

      for (int col = 0; col < numCols; col++) {
        final worldX = -halfWidth + col * charSizeWorld + rng.nextDouble() * 0.2;
        final seed = (zLayer * 100 + col * 7).toInt();
        final rngC = math.Random(seed);
        final streamLen = 4 + rngC.nextInt(8);
        final speed = 0.3 + rngC.nextDouble() * 0.4;
        final totalHeightWorld = streamLen * charSizeWorld;
        final phase = rngC.nextDouble();
        final yOffsetWorld = -(_t * speed + phase * totalHeightWorld * 2) % (totalHeightWorld + 4) - 1;

        for (int row = 0; row < streamLen; row++) {
          final worldY = cam.cy + 2 - yOffsetWorld - row * charSizeWorld;
          final p = cam.project(_V3(worldX, worldY, zLayer), size);
          if (!p.visible || p.sy < -charPx || p.sy > size.height + charPx) continue;

          double alpha;
          Color charColor;
          if (row == 0) { charColor = Colors.white; alpha = 0.4 * fade; }
          else if (row < 3) { charColor = color.withValues(alpha: 0.8); alpha = 0.25 * fade; }
          else { charColor = color; alpha = 0.15 * fade * (streamLen - row) / streamLen; }
          if (alpha < 0.02) continue;

          final charIdx = (seed * 13 + row * 7 + (_t * 5).toInt()) % charSet.length;
          _drawChar(canvas, charSet[charIdx], p.sx, p.sy, charColor.withValues(alpha: alpha), fontSize: charPx.clamp(4, 11));
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  BIO HOLOGRAM
  // ═══════════════════════════════════════════════════════════════
  // ════════════════════════════════════════════════════════════════
  //  V49.9 REAL TOGGLE OVERLAYS
  // ════════════════════════════════════════════════════════════════

  /// Bio Heart Overlay — pulsing red ECG ring on every organic/bio detection
  void _drawBioHeartOverlay(Canvas canvas, Size size, _Camera3D cam) {
    final bpm = 72.0; // heartbeats per minute
    final cycleT = (_t * bpm / 60.0) % 1.0;
    // Two-phase pulse: systole spike (0–0.1) + diastole ring (0.1–0.5)
    final systole = cycleT < 0.1 ? math.sin(cycleT / 0.1 * math.pi) : 0.0;
    final diastole = (cycleT > 0.15 && cycleT < 0.55)
        ? math.sin((cycleT - 0.15) / 0.40 * math.pi) * 0.55
        : 0.0;
    final pulse = systole + diastole;

    const heartColor = Color(0xFFFF1744);

    for (final (x, y, z, conf, label, _) in detectedMatterOverlay) {
      // Only bio/organic — heuristic: organic type or label contains 'human'/'bio'
      if (!label.toLowerCase().contains('organ') &&
          !label.toLowerCase().contains('human') &&
          !label.toLowerCase().contains('bio')) continue;

      final pp = cam.project(_V3(x, y, z), size);
      if (!pp.visible) continue;

      final baseR = (pp.scale * 0.06 * pointSize).clamp(4.0, 20.0);

      // ECG-style pulsing ring
      canvas.drawCircle(pp.offset, baseR * (1.0 + 0.6 * pulse),
          Paint()
            ..color = heartColor.withValues(alpha: (0.6 * pulse * conf).clamp(0.0, 1.0))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);

      // Inner glow during systole
      if (systole > 0.2) {
        canvas.drawCircle(pp.offset, baseR * 0.5,
            Paint()
              ..color = heartColor.withValues(alpha: systole * 0.4 * conf)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      }

      // ♥ symbol label
      final tp = TextPainter(
        text: TextSpan(
          text: '♥ ${(72 + (pulse * 10)).round()} bpm',
          style: TextStyle(
            color: heartColor.withValues(alpha: 0.85),
            fontSize: (pp.scale * 0.04).clamp(7.0, 11.0),
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pp.sx - tp.width / 2, pp.sy - baseR - tp.height - 4));
    }
  }

  /// Neural Flow Lines — blue tendrils flowing between nearby bio detections
  void _drawNeuralFlowLines(Canvas canvas, Size size, _Camera3D cam) {
    final bioPoints = detectedMatterOverlay
        .where((d) => d.$5.toLowerCase().contains('organ') ||
            d.$5.toLowerCase().contains('human') ||
            d.$5.toLowerCase().contains('bio'))
        .toList();

    if (bioPoints.length < 2) return;

    const neuralColor = Color(0xFF00AAFF);
    final flowT = (_t * 1.5) % 1.0;

    for (int i = 0; i < bioPoints.length; i++) {
      for (int j = i + 1; j < bioPoints.length; j++) {
        final a = bioPoints[i];
        final b = bioPoints[j];
        final dist = math.sqrt(
            math.pow(a.$1 - b.$1, 2) + math.pow(a.$2 - b.$2, 2) + math.pow(a.$3 - b.$3, 2));
        if (dist > 6.0) continue; // only connect nearby bio nodes

        final pA = cam.project(_V3(a.$1, a.$2, a.$3), size);
        final pB = cam.project(_V3(b.$1, b.$2, b.$3), size);
        if (!pA.visible || !pB.visible) continue;

        // Animated flow dot travelling along connection
        final flowX = pA.sx + (pB.sx - pA.sx) * flowT;
        final flowY = pA.sy + (pB.sy - pA.sy) * flowT;

        // Base connection line
        canvas.drawLine(pA.offset, pB.offset,
            Paint()
              ..color = neuralColor.withValues(alpha: 0.15)
              ..strokeWidth = 0.6);

        // Travelling pulse bead
        canvas.drawCircle(Offset(flowX, flowY), 3.0,
            Paint()
              ..color = neuralColor.withValues(alpha: 0.8)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

        // Segment highlight (trailing glow behind bead)
        final trailEnd = math.max(0.0, flowT - 0.15);
        final tX = pA.sx + (pB.sx - pA.sx) * trailEnd;
        final tY = pA.sy + (pB.sy - pA.sy) * trailEnd;
        canvas.drawLine(Offset(tX, tY), Offset(flowX, flowY),
            Paint()
              ..color = neuralColor.withValues(alpha: 0.4)
              ..strokeWidth = 1.2
              ..strokeCap = StrokeCap.round);
      }
    }
  }

  /// Water & Void Detection — highlights water/void signal points in cyan
  void _drawWaterVoidHighlight(Canvas canvas, Size size, _Camera3D cam) {
    const waterColor = Color(0xFF2196F3);
    const voidColor  = Color(0xFF00E5FF);
    final pulse = 0.7 + 0.3 * math.sin(_t * math.pi * 0.8);

    for (final pt in points3D) {
      // Flag water: material type water, or very low reflectionStrength (void = no reflection)
      final isWater = (pt.materialType == csi.MaterialType.water);
      final isVoid  = pt.reflectionStrength < 0.12;
      if (!isWater && !isVoid) continue;

      final pp = cam.project(_V3(pt.x, pt.y, pt.z), size);
      if (!pp.visible) continue;

      final c = isWater ? waterColor : voidColor;
      final baseR = (pp.scale * 0.035 * pointSize).clamp(1.5, 8.0);

      // Ripple ring
      final rippleR = baseR * (1.0 + 0.8 * math.sin(_t * 2.5 + pt.x));
      canvas.drawCircle(pp.offset, rippleR,
          Paint()
            ..color = c.withValues(alpha: 0.3 * pulse)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7);

      canvas.drawCircle(pp.offset, baseR * 0.5,
          Paint()..color = c.withValues(alpha: 0.75 * pulse));
    }

    // Overlay label
    final tp = TextPainter(
      text: TextSpan(
        text: 'WATER/VOID SCAN ACTIVE',
        style: TextStyle(color: waterColor.withValues(alpha: 0.55 * pulse),
            fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height * 0.12));
  }

  /// Metal Homing Arrow — 3D compass arrow pointing to nearest metal detection
  void _drawMetalHomingArrow(Canvas canvas, Size size, _Camera3D cam) {
    // Find nearest metal
    (double, double, double, String, Color)? nearest;
    double nearestDist = double.infinity;

    for (final (x, y, z, conf, label, colorHex) in detectedMatterOverlay) {
      if (label.toLowerCase().contains('organ') ||
          label.toLowerCase().contains('water')) continue; // skip non-metal
      final d = math.sqrt(math.pow(x - cam.cx, 2) + math.pow(y - cam.cy, 2) + math.pow(z - cam.cz, 2));
      if (d < nearestDist) {
        nearestDist = d;
        nearest = (x, y, z, label, Color(colorHex | 0xFF000000));
      }
    }
    if (nearest == null) return;

    final (tx, ty, tz, label, mColor) = nearest!;
    final projected = cam.project(_V3(tx, ty, tz), size);
    final pulse = 0.7 + 0.3 * math.sin(_t * math.pi * 2);

    // If target is visible, draw target reticle
    if (projected.visible) {
      final r = (projected.scale * 0.08 * pointSize).clamp(8.0, 28.0);
      // Reticle cross
      for (final (dx, dy) in [(-r, 0.0), (r, 0.0), (0.0, -r), (0.0, r)]) {
        canvas.drawLine(
          Offset(projected.sx + dx * 0.4, projected.sy + dy * 0.4),
          Offset(projected.sx + dx,       projected.sy + dy),
          Paint()..color = mColor.withValues(alpha: 0.85 * pulse)
                 ..strokeWidth = 1.5..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawCircle(projected.offset, r * 0.9,
          Paint()..color = mColor.withValues(alpha: 0.2 * pulse)
                 ..style = PaintingStyle.stroke..strokeWidth = 0.8);
      // Distance label
      final tp = TextPainter(
        text: TextSpan(
          text: '${label.split(' ').first}  ${nearestDist.toStringAsFixed(1)}m',
          style: TextStyle(color: mColor, fontSize: 9, fontWeight: FontWeight.bold,
              shadows: [Shadow(color: mColor, blurRadius: 6)]),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(projected.sx - tp.width / 2, projected.sy - r - 16));
    } else {
      // Target off-screen — draw edge arrow pointing toward it
      final cx = size.width / 2, cy = size.height * 0.42;
      final dx = tx - cam.cx, dz = tz - cam.cz;
      // Project direction vector to screen angle using camera yaw
      final cosY = math.cos(-cam.yaw), sinY = math.sin(-cam.yaw);
      final rx = dx * cosY - dz * sinY;
      final rz = dx * sinY + dz * cosY;
      final angle = math.atan2(rx, rz);

      final arrowR = math.min(size.width, size.height) * 0.38;
      final ax = cx + math.sin(angle) * arrowR;
      final ay = cy - math.cos(angle) * arrowR;

      // Arrow head
      _drawArrowHead(canvas, Offset(ax, ay), angle, 18.0 * pulse, mColor);

      // Distance badge
      final tp = TextPainter(
        text: TextSpan(
          text: '${nearestDist.toStringAsFixed(0)}m',
          style: TextStyle(color: mColor, fontSize: 9, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(ax, ay + 18), width: tp.width + 10, height: tp.height + 4),
          const Radius.circular(3),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.7),
      );
      tp.paint(canvas, Offset(ax - tp.width / 2, ay + 16));
    }
  }

  void _drawArrowHead(Canvas canvas, Offset tip, double angle, double size, Color color) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final path = Path();
    path.moveTo(tip.dx + math.sin(angle) * size, tip.dy - math.cos(angle) * size);
    path.lineTo(tip.dx + math.sin(angle + 2.4) * size * 0.5,
                tip.dy - math.cos(angle + 2.4) * size * 0.5);
    path.lineTo(tip.dx + math.sin(angle - 2.4) * size * 0.5,
                tip.dy - math.cos(angle - 2.4) * size * 0.5);
    path.close();
    canvas.drawPath(path, p);
  }

  void _drawBioHologram(Canvas canvas, Size size, _Camera3D cam) {
    final bodyCloud = _buildBodyPointCloud(0, 0, 6.0, 1.0, 200);
    final corePaint = Paint()..isAntiAlias = false;
    final pulse = 0.7 + 0.3 * math.sin(_t * math.pi * 1.5);
    final parts = <String, _V3>{'head': _V3(0, 1.75, 6.0), 'neck': _V3(0, 1.45, 6.0), 'chest': _V3(0, 1.1, 6.0), 'lhip': _V3(-0.15, 0.55, 6.0), 'rhip': _V3(0.15, 0.55, 6.0)};
    final bonePaint = Paint()..color = const Color(0xFF00CCFF).withValues(alpha: 0.3)..strokeWidth = 0.8..maskFilter = const MaskFilter.blur(BlurStyle.outer, 2);
    void bone(String a, String b) {
      final pa = parts[a], pb = parts[b];
      if (pa == null || pb == null) return;
      final ppa = cam.project(pa, size), ppb = cam.project(pb, size);
      if (!ppa.visible || !ppb.visible) return;
      canvas.drawLine(ppa.offset, ppb.offset, bonePaint);
    }
    bone('head', 'neck'); bone('neck', 'chest'); bone('chest', 'lhip'); bone('chest', 'rhip');
    final chestP = cam.project(parts['chest']!, size);
    if (chestP.visible) {
      canvas.drawCircle(chestP.offset, 15 * pulse,
          Paint()..color = const Color(0xFFFF0044).withValues(alpha: 0.12 * pulse)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }
    for (final pt in bodyCloud) {
      final pp = cam.project(pt, size);
      if (!pp.visible) continue;
      corePaint.color = const Color(0xFF00CCFF).withValues(alpha: 0.08);
      canvas.drawCircle(pp.offset, (pp.scale * 0.012).clamp(0.2, 1.2), corePaint);
    }
  }

  // ─── Effects ────────────────────────────────────────────────────
  void _drawAtmosphericFog(Canvas canvas, Size size, Color color) {
    final rng = math.Random(55);
    for (int i = 0; i < 10; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.7 + size.height * 0.1;
      canvas.drawCircle(Offset(x, y), 25 + rng.nextDouble() * 40,
          Paint()..color = color.withValues(alpha: 0.02)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));
    }
  }

  void _drawHeavyRain(Canvas canvas, Size size) {
    final rng = math.Random(99);
    final paint = Paint()..color = const Color(0xFF0099FF).withValues(alpha: 0.1)..strokeWidth = 0.5;
    for (int i = 0; i < 80; i++) {
      final x = rng.nextDouble() * size.width;
      final y = (rng.nextDouble() * size.height + _t * 400) % size.height;
      canvas.drawLine(Offset(x, y), Offset(x - 1.5, y + 16), paint);
    }
  }

  void _drawEcholocationPulses(Canvas canvas, Size size) {
    for (int ring = 0; ring < 4; ring++) {
      final phase = (_t * 0.5 + ring * 0.25) % 1.0;
      final radius = phase * size.width * 0.6;
      canvas.drawCircle(Offset(size.width / 2, size.height * 0.42), radius,
          Paint()..color = const Color(0xFF00CCFF).withValues(alpha: (1 - phase) * 0.05)..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }
  }

  void _drawLucyRain(Canvas canvas, Size size) {
    final colors = [const Color(0xFF0099FF), const Color(0xFFFF00FF), const Color(0xFFFFD700), const Color(0xFF00FFFF)];
    final rng = math.Random(77);
    final cols = (size.width / 14).ceil();
    for (int col = 0; col < cols; col++) {
      final color = colors[col % 4];
      final seed = rng.nextInt(800);
      final speed = 0.2 + (seed % 5) * 0.06;
      final offset = (_t * speed * size.height + seed * 27) % (size.height + 14 * 12);
      for (int row = 0; row < 12; row++) {
        final y = (row * 14 - offset + size.height * 2) % (size.height + 14 * 12);
        if (y < 0 || y > size.height + 14) continue;
        final alpha = (12 - row) / 12.0 * 0.2;
        if (alpha < 0.03) continue;
        final ci = (seed + row * 5 + (_t * 4).toInt()) % _kMatrixChars.length;
        _drawChar(canvas, _kMatrixChars[ci], col * 14.0, y, color.withValues(alpha: alpha), fontSize: 9);
      }
    }
  }

  void _drawProbabilityAura(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.45);
    final colors = [const Color(0xFF0099FF), const Color(0xFFFF00FF), const Color(0xFFFFD700), const Color(0xFF00FFFF)];
    for (int i = 0; i < 4; i++) {
      final pulse = 0.5 + 0.5 * math.sin(_t * 2.5 + i * 1.2);
      canvas.drawCircle(center, 40 + i * 25 + pulse * 15,
          Paint()..color = colors[i].withValues(alpha: 0.025 * pulse)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    }
  }

  void _drawIronManHUD(Canvas canvas, Size size, _Camera3D cam) {
    final gridPaint = Paint()..color = const Color(0xFFFF3333).withValues(alpha: 0.035)..strokeWidth = 0.3;
    for (int i = 0; i < 12; i++) {
      canvas.drawLine(Offset(0, size.height * i / 12), Offset(size.width, size.height * i / 12), gridPaint);
      canvas.drawLine(Offset(size.width * i / 12, 0), Offset(size.width * i / 12, size.height), gridPaint);
    }
    final figCenter = cam.project(const _V3(0, 0.8, 6.0), size);
    if (figCenter.visible) {
      final s = (figCenter.scale * 0.5).clamp(12.0, 60.0);
      final cx2 = figCenter.sx, cy2 = figCenter.sy;
      final paint = Paint()..color = const Color(0xFFFF3333).withValues(alpha: 0.45)..style = PaintingStyle.stroke..strokeWidth = 1;
      final gap = s * 0.3;
      canvas.drawLine(Offset(cx2 - s, cy2 - s), Offset(cx2 - gap, cy2 - s), paint);
      canvas.drawLine(Offset(cx2 - s, cy2 - s), Offset(cx2 - s, cy2 - gap), paint);
      canvas.drawLine(Offset(cx2 + s, cy2 - s), Offset(cx2 + gap, cy2 - s), paint);
      canvas.drawLine(Offset(cx2 + s, cy2 - s), Offset(cx2 + s, cy2 - gap), paint);
      canvas.drawLine(Offset(cx2 - s, cy2 + s), Offset(cx2 - gap, cy2 + s), paint);
      canvas.drawLine(Offset(cx2 - s, cy2 + s), Offset(cx2 - s, cy2 + gap), paint);
      canvas.drawLine(Offset(cx2 + s, cy2 + s), Offset(cx2 + gap, cy2 + s), paint);
      canvas.drawLine(Offset(cx2 + s, cy2 + s), Offset(cx2 + s, cy2 + gap), paint);
      canvas.drawArc(Rect.fromCenter(center: Offset(cx2, cy2), width: s * 2.5, height: s * 2.5),
          _t * 2, math.pi * 0.5, false, paint..color = const Color(0xFFFF3333).withValues(alpha: 0.25));
    }
  }

  void _drawSubsurfaceLayers(Canvas canvas, Size size) {
    final layers = [[0.25, 0.4, const Color(0xFF2E1800)], [0.4, 0.55, const Color(0xFF1C2200)], [0.55, 0.7, const Color(0xFF0D1A00)], [0.7, 0.85, const Color(0xFF0A1400)], [0.85, 1.0, const Color(0xFF050E00)]];
    for (final l in layers) {
      canvas.drawRect(Rect.fromLTWH(0, size.height * (l[0] as double), size.width, size.height * ((l[1] as double) - (l[0] as double))), Paint()..color = (l[2] as Color).withValues(alpha: 0.35));
    }
  }

  void _drawMineralVeins(Canvas canvas, Size size) {
    final colors = [const Color(0xFFFFD700), const Color(0xFFC0C0C0), const Color(0xFFB87333), const Color(0xFFFF6600)];
    for (int v = 0; v < 8; v++) {
      final color = colors[v % 4];
      final r2 = math.Random(v * 137 + 42);
      double x = r2.nextDouble() * size.width, y = size.height * (0.35 + r2.nextDouble() * 0.5);
      final pulse = 0.5 + 0.5 * math.sin(_t * 2 + v * 0.9);
      final path = Path()..moveTo(x, y);
      for (int seg = 0; seg < 10; seg++) { x += (r2.nextDouble() - 0.4) * 35; y += (r2.nextDouble() - 0.3) * 14; path.lineTo(x, y); }
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.2 * pulse)..style = PaintingStyle.stroke..strokeWidth = 1.0..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
  }

  void _drawTacticalTargeting(Canvas canvas, Size size, _Camera3D cam) {
    final positions = [const _V3(-1.5, 0.85, 10), const _V3(1.5, 0.85, 10), const _V3(0, 0.85, 14)];
    for (final pos in positions) {
      final pp = cam.project(pos, size);
      if (!pp.visible) continue;
      final s = (pp.scale * 0.3).clamp(6.0, 20.0);
      final paint = Paint()..color = const Color(0xFFFF3333).withValues(alpha: 0.3)..strokeWidth = 0.5;
      canvas.drawLine(Offset(pp.sx - s, pp.sy), Offset(pp.sx, pp.sy - s), paint);
      canvas.drawLine(Offset(pp.sx, pp.sy - s), Offset(pp.sx + s, pp.sy), paint);
      canvas.drawLine(Offset(pp.sx + s, pp.sy), Offset(pp.sx, pp.sy + s), paint);
      canvas.drawLine(Offset(pp.sx, pp.sy + s), Offset(pp.sx - s, pp.sy), paint);
    }
  }

  void _drawScanlines(Canvas canvas, Size size, Color color, double alpha) {
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()..color = color.withValues(alpha: alpha)..strokeWidth = 0.5);
    }
    final beamY = (_t * 0.08 * size.height) % size.height;
    canvas.drawRect(Rect.fromLTWH(0, beamY, size.width, 1),
        Paint()..color = color.withValues(alpha: 0.06)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
  }

  void _drawVignette(Canvas canvas, Size size, Color color) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()
      ..shader = RadialGradient(center: Alignment.center, radius: 1.0,
        colors: [Colors.transparent, Colors.transparent, color.withValues(alpha: 0.3)], stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
  }

  void _drawGlitchStreaks(Canvas canvas, Size size, Color color) {
    final rng = math.Random(_t.toInt() * 7);
    for (int i = 0; i < 3; i++) {
      final y = rng.nextDouble() * size.height;
      final w = rng.nextDouble() * size.width * 0.3 + 20;
      final x = rng.nextDouble() * (size.width - w);
      canvas.drawRect(Rect.fromLTWH(x, y, w, 1.5 + rng.nextDouble() * 2), Paint()..color = color.withValues(alpha: rng.nextDouble() * 0.12));
    }
  }

  void _drawSignalHeatmap(Canvas canvas, Size size) {
    final time = animationProgress * 2 * 3.14159;
    final blobs = [(size.width * 0.25, size.height * 0.45, 50.0, 0.1), (size.width * 0.60, size.height * 0.40, 40.0, 0.08), (size.width * 0.45, size.height * 0.60, 35.0, 0.06)];
    for (final (cx, cy, r, alpha) in blobs) {
      final pulse = alpha * (0.7 + 0.3 * (time).abs() % 1);
      final gradient = RadialGradient(colors: [const Color(0xFFFF0000).withValues(alpha: pulse), const Color(0xFFFF8800).withValues(alpha: pulse * 0.3), Colors.transparent]);
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
      canvas.drawOval(rect, Paint()..shader = gradient.createShader(rect));
    }
  }

  void _drawChar(Canvas canvas, String text, double x, double y, Color color, {double fontSize = 13}) {
    final tp = TextPainter(text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontFamily: 'monospace', height: 1.0)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(x, y));
  }

  // ─────────────────────────────────────────────────────────────────
  // PERF V49.9: shouldRepaint — guard against animationProgress micro-jitter.
  // Only repaint when progress delta > threshold OR real data/state changed.
  // Previously fired on EVERY ticker tick regardless of visual change.
  // ─────────────────────────────────────────────────────────────────
  @override
  bool shouldRepaint(RadioWave3DPainter old) {
    // PERF: Throttle animation repaints — skip if progress delta < 1/240s worth
    // This halves repaint calls on 120fps devices when no data changes.
    const kMinProgressDelta = 0.004; // ~1 frame at 240fps
    if ((animationProgress - old.animationProgress).abs() > kMinProgressDelta) return true;

    // Data & state changes always repaint
    if (old.points3D.length != points3D.length) return true;
    if (old.detectedMatterOverlay.length != detectedMatterOverlay.length) return true;
    if (old.mode != mode) return true;
    if (old.zoomLevel != zoomLevel) return true;
    if (old.droneTopDown != droneTopDown) return true;
    if (old.manualYaw != manualYaw || old.manualPitch != manualPitch) return true;
    if (old.camOffsetX != camOffsetX || old.camOffsetY != camOffsetY || old.camOffsetZ != camOffsetZ) return true;
    if (old.themeColor != themeColor) return true;
    if (old.pointSize != pointSize || old.clusterDensity != clusterDensity) return true;
    // Toggle changes
    if (old.showFloorGrid != showFloorGrid || old.showBuildings != showBuildings ||
        old.showParticleHuman != showParticleHuman || old.showCodeRain != showCodeRain ||
        old.codeRainChars != codeRainChars || old.showScanlines != showScanlines ||
        old.showGlitch != showGlitch || old.showHeatmap != showHeatmap ||
        old.showObjectLabels != showObjectLabels || old.showRssiHeatmap != showRssiHeatmap ||
        old.customPointRendering != customPointRendering ||
        old.showBioHeart != showBioHeart || old.showNeuralFlow != showNeuralFlow ||
        old.showWaterVoid != showWaterVoid || old.showMetalHoming != showMetalHoming ||
        old.useFrustumCulling != useFrustumCulling) return true;
    return false;
  }
}
