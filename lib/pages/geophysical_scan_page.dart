import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../theme.dart';
import '../widgets/falcon_side_panel.dart';
import '../services/metal_detection_service.dart';
import '../services/features_provider.dart';
import '../services/imu_fusion_service.dart';
import '../widgets/back_button_top_left.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  FALCON EYE V50.0 — GEOPHYSICAL SCAN / MATTER & METAL DETECTION
//  Real multi-signal fusion: WiFi CSI, Cellular RSSI, BLE, UWB, MAG
//  V50.0 FIXES:
//    • Header subtitle overflow fixed → maxLines(1) + ellipsis + compact labels
//    • AUTO badge no longer causes right-overflow (+13px bug eliminated)
//    • Scan history now records ALL completed scans (incl. 0-anomaly sessions)
//    • 3D Matter Twin empty state → inline START SCAN action button
//    • Analysis tab → live MAG baseline stats shown pre-scan
//    • Periodic table visibility improved: unsupported opacity 0.35→0.50
//    • Version bump V49.9 → V50.0
// ═══════════════════════════════════════════════════════════════════════════

// ─── Full 118-Element Data ──────────────────────────────────────────────────
class _Element {
  final int z;
  final String symbol;
  final String name;
  final String category;
  const _Element(this.z, this.symbol, this.name, this.category);
}

const _kElements = <_Element>[
  _Element(1,'H','Hydrogen','nonmetal'), _Element(2,'He','Helium','noble'),
  _Element(3,'Li','Lithium','alkali'), _Element(4,'Be','Beryllium','alkaline'),
  _Element(5,'B','Boron','metalloid'), _Element(6,'C','Carbon','nonmetal'),
  _Element(7,'N','Nitrogen','nonmetal'), _Element(8,'O','Oxygen','nonmetal'),
  _Element(9,'F','Fluorine','halogen'), _Element(10,'Ne','Neon','noble'),
  _Element(11,'Na','Sodium','alkali'), _Element(12,'Mg','Magnesium','alkaline'),
  _Element(13,'Al','Aluminum','post-transition'), _Element(14,'Si','Silicon','metalloid'),
  _Element(15,'P','Phosphorus','nonmetal'), _Element(16,'S','Sulfur','nonmetal'),
  _Element(17,'Cl','Chlorine','halogen'), _Element(18,'Ar','Argon','noble'),
  _Element(19,'K','Potassium','alkali'), _Element(20,'Ca','Calcium','alkaline'),
  _Element(21,'Sc','Scandium','transition'), _Element(22,'Ti','Titanium','transition'),
  _Element(23,'V','Vanadium','transition'), _Element(24,'Cr','Chromium','transition'),
  _Element(25,'Mn','Manganese','transition'), _Element(26,'Fe','Iron','transition'),
  _Element(27,'Co','Cobalt','transition'), _Element(28,'Ni','Nickel','transition'),
  _Element(29,'Cu','Copper','transition'), _Element(30,'Zn','Zinc','transition'),
  _Element(31,'Ga','Gallium','post-transition'), _Element(32,'Ge','Germanium','metalloid'),
  _Element(33,'As','Arsenic','metalloid'), _Element(34,'Se','Selenium','nonmetal'),
  _Element(35,'Br','Bromine','halogen'), _Element(36,'Kr','Krypton','noble'),
  _Element(37,'Rb','Rubidium','alkali'), _Element(38,'Sr','Strontium','alkaline'),
  _Element(39,'Y','Yttrium','transition'), _Element(40,'Zr','Zirconium','transition'),
  _Element(41,'Nb','Niobium','transition'), _Element(42,'Mo','Molybdenum','transition'),
  _Element(43,'Tc','Technetium','transition'), _Element(44,'Ru','Ruthenium','transition'),
  _Element(45,'Rh','Rhodium','transition'), _Element(46,'Pd','Palladium','transition'),
  _Element(47,'Ag','Silver','transition'), _Element(48,'Cd','Cadmium','transition'),
  _Element(49,'In','Indium','post-transition'), _Element(50,'Sn','Tin','post-transition'),
  _Element(51,'Sb','Antimony','metalloid'), _Element(52,'Te','Tellurium','metalloid'),
  _Element(53,'I','Iodine','halogen'), _Element(54,'Xe','Xenon','noble'),
  _Element(55,'Cs','Cesium','alkali'), _Element(56,'Ba','Barium','alkaline'),
  _Element(57,'La','Lanthanum','lanthanide'), _Element(58,'Ce','Cerium','lanthanide'),
  _Element(59,'Pr','Praseodymium','lanthanide'), _Element(60,'Nd','Neodymium','lanthanide'),
  _Element(61,'Pm','Promethium','lanthanide'), _Element(62,'Sm','Samarium','lanthanide'),
  _Element(63,'Eu','Europium','lanthanide'), _Element(64,'Gd','Gadolinium','lanthanide'),
  _Element(65,'Tb','Terbium','lanthanide'), _Element(66,'Dy','Dysprosium','lanthanide'),
  _Element(67,'Ho','Holmium','lanthanide'), _Element(68,'Er','Erbium','lanthanide'),
  _Element(69,'Tm','Thulium','lanthanide'), _Element(70,'Yb','Ytterbium','lanthanide'),
  _Element(71,'Lu','Lutetium','lanthanide'), _Element(72,'Hf','Hafnium','transition'),
  _Element(73,'Ta','Tantalum','transition'), _Element(74,'W','Tungsten','transition'),
  _Element(75,'Re','Rhenium','transition'), _Element(76,'Os','Osmium','transition'),
  _Element(77,'Ir','Iridium','transition'), _Element(78,'Pt','Platinum','transition'),
  _Element(79,'Au','Gold','transition'), _Element(80,'Hg','Mercury','transition'),
  _Element(81,'Tl','Thallium','post-transition'), _Element(82,'Pb','Lead','post-transition'),
  _Element(83,'Bi','Bismuth','post-transition'), _Element(84,'Po','Polonium','metalloid'),
  _Element(85,'At','Astatine','halogen'), _Element(86,'Rn','Radon','noble'),
  _Element(87,'Fr','Francium','alkali'), _Element(88,'Ra','Radium','alkaline'),
  _Element(89,'Ac','Actinium','actinide'), _Element(90,'Th','Thorium','actinide'),
  _Element(91,'Pa','Protactinium','actinide'), _Element(92,'U','Uranium','actinide'),
  _Element(93,'Np','Neptunium','actinide'), _Element(94,'Pu','Plutonium','actinide'),
  _Element(95,'Am','Americium','actinide'), _Element(96,'Cm','Curium','actinide'),
  _Element(97,'Bk','Berkelium','actinide'), _Element(98,'Cf','Californium','actinide'),
  _Element(99,'Es','Einsteinium','actinide'), _Element(100,'Fm','Fermium','actinide'),
  _Element(101,'Md','Mendelevium','actinide'), _Element(102,'No','Nobelium','actinide'),
  _Element(103,'Lr','Lawrencium','actinide'), _Element(104,'Rf','Rutherfordium','transition'),
  _Element(105,'Db','Dubnium','transition'), _Element(106,'Sg','Seaborgium','transition'),
  _Element(107,'Bh','Bohrium','transition'), _Element(108,'Hs','Hassium','transition'),
  _Element(109,'Mt','Meitnerium','transition'), _Element(110,'Ds','Darmstadtium','transition'),
  _Element(111,'Rg','Roentgenium','transition'), _Element(112,'Cn','Copernicium','transition'),
  _Element(113,'Nh','Nihonium','post-transition'), _Element(114,'Fl','Flerovium','post-transition'),
  _Element(115,'Mc','Moscovium','post-transition'), _Element(116,'Lv','Livermorium','post-transition'),
  _Element(117,'Ts','Tennessine','halogen'), _Element(118,'Og','Oganesson','noble'),
];

const _kDetectableZnumbers = {13, 22, 23, 24, 25, 26, 27, 28, 29, 30, 42, 46, 47, 50, 74, 78, 79, 82};

Color _categoryColor(String cat) {
  switch (cat) {
    case 'alkali':           return const Color(0xFFFF6B6B);
    case 'alkaline':         return const Color(0xFFFFB347);
    case 'transition':       return const Color(0xFF4FC3F7);
    case 'post-transition':  return const Color(0xFF81C784);
    case 'metalloid':        return const Color(0xFFB39DDB);
    case 'nonmetal':         return const Color(0xFF4DB6AC);
    case 'halogen':          return const Color(0xFFFF8A65);
    case 'noble':            return const Color(0xFF90CAF9);
    case 'lanthanide':       return const Color(0xFFCE93D8);
    case 'actinide':         return const Color(0xFFEF9A9A);
    default:                 return const Color(0xFF9E9E9E);
  }
}

Color _matterTypeColor(MatterType type) {
  switch (type) {
    case MatterType.ferrousMetal:    return const Color(0xFFE65100);
    case MatterType.nonFerrousMetal: return const Color(0xFFB87333);
    case MatterType.preciousMetal:   return const Color(0xFFFFD700);
    case MatterType.alloy:           return const Color(0xFF90A4AE);
    case MatterType.mineral:         return const Color(0xFF9C27B0);
    case MatterType.water:           return const Color(0xFF2196F3);
    case MatterType.organic:         return const Color(0xFF4CAF50);
    default:                         return const Color(0xFF757575);
  }
}

// ─── Auto-scan interval options ─────────────────────────────────────────────
const _kAutoScanIntervals = [5, 10, 15, 30, 60]; // seconds

enum _SortMode { depth, confidence, type }

// ─── 3D View modes ───────────────────────────────────────────────────────────
enum _ViewMode { isometric, crossSection, topDown }

// ─── Soil strata definitions ─────────────────────────────────────────────────
class _SoilStratum {
  final String name;
  final double fromCm;
  final double toCm;
  final Color color;
  final String composition;
  const _SoilStratum(this.name, this.fromCm, this.toCm, this.color, this.composition);
}

const _kStrata = [
  _SoilStratum('TOPSOIL',  0,   30,  Color(0xFF3E2723), 'Organic matter, roots'),
  _SoilStratum('CLAY',    30,   80,  Color(0xFF6D4C41), 'Clay minerals, silt'),
  _SoilStratum('SAND',    80,  160,  Color(0xFF8D6E63), 'Coarse sand, gravel'),
  _SoilStratum('GRAVEL', 160,  280,  Color(0xFF546E7A), 'Gravel, weathered rock'),
  _SoilStratum('BEDROCK',280, 9999,  Color(0xFF37474F), 'Consolidated rock'),
];

// ─── Detection cluster ───────────────────────────────────────────────────────
class _DetCluster {
  final List<DetectedMatter> members;
  final double cx, cy, cz;
  final double totalMassG;
  final double avgConfidence;
  final MatterType dominantType;
  const _DetCluster({
    required this.members, required this.cx, required this.cy, required this.cz,
    required this.totalMassG, required this.avgConfidence, required this.dominantType,
  });
}

// ─── Scan history entry ──────────────────────────────────────────────────────
class _ScanHistoryEntry {
  final DateTime timestamp;
  final List<DetectedMatter> detections;
  final double magnetometerReading;
  // Simulated GPS offset from device centre (real GPS would come from geolocator)
  final double latOffset;   // degrees offset from 0,0 stub
  final double lonOffset;
  _ScanHistoryEntry({
    required this.timestamp,
    required this.detections,
    required this.magnetometerReading,
    required this.latOffset,
    required this.lonOffset,
  });
  int get anomalyCount => detections.length;
  MatterType? get dominantType {
    if (detections.isEmpty) return null;
    final counts = <MatterType, int>{};
    for (final d in detections) counts[d.matterType] = (counts[d.matterType] ?? 0) + 1;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

List<_DetCluster> _clusterDetections(List<DetectedMatter> dets, double radiusM) {
  final used = List.filled(dets.length, false);
  final clusters = <_DetCluster>[];
  for (int i = 0; i < dets.length; i++) {
    if (used[i]) continue;
    final group = [dets[i]];
    used[i] = true;
    for (int j = i + 1; j < dets.length; j++) {
      if (used[j]) continue;
      final dx = dets[i].x - dets[j].x;
      final dy = dets[i].depthMetres - dets[j].depthMetres;
      final dz = dets[i].z - dets[j].z;
      if (math.sqrt(dx*dx + dy*dy + dz*dz) <= radiusM) {
        group.add(dets[j]);
        used[j] = true;
      }
    }
    final cx = group.fold(0.0, (s, d) => s + d.x) / group.length;
    final cy = group.fold(0.0, (s, d) => s + d.depthMetres) / group.length;
    final cz = group.fold(0.0, (s, d) => s + d.z) / group.length;
    final totalMass = group.fold(0.0, (s, d) => s + d.massEstimateG);
    final avgConf = group.fold(0.0, (s, d) => s + d.confidence) / group.length;
    // dominant type = most common
    final typeCounts = <MatterType, int>{};
    for (final d in group) typeCounts[d.matterType] = (typeCounts[d.matterType] ?? 0) + 1;
    final dominant = typeCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    clusters.add(_DetCluster(
      members: group, cx: cx, cy: cy, cz: cz,
      totalMassG: totalMass, avgConfidence: avgConf, dominantType: dominant,
    ));
  }
  return clusters;
}

// ═══════════════════════════════════════════════════════════════════════════
//  MAIN PAGE
// ═══════════════════════════════════════════════════════════════════════════
class GeophysicalScanPage extends ConsumerStatefulWidget {
  const GeophysicalScanPage({super.key});

  @override
  ConsumerState<GeophysicalScanPage> createState() => _GeophysicalScanPageState();
}

class _GeophysicalScanPageState extends ConsumerState<GeophysicalScanPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _voxelAnimController;
  late AnimationController _pulseAnimController;

  // V49.9 filtering / sorting
  final Set<int> _flagged = {};
  double _confidenceThreshold = 0.0;
  _SortMode _sortMode = _SortMode.confidence;
  int? _selectedDetectionIdx;

  // Periodic table pinch-to-zoom via InteractiveViewer
  late TransformationController _tableTransformCtrl;
  double _tableScale = 1.0;

  // Scan history (per-session log of every completed scan)
  final List<_ScanHistoryEntry> _scanHistory = [];

  // ── 3D TWIN VIEW STATE ───────────────────────────────────────────────────
  _ViewMode _viewMode = _ViewMode.isometric;
  double _orbitAngle = 0.3;           // radians, 0 = front-facing
  double _pitchAngle = 0.45;          // vertical tilt
  bool _showClusters = false;
  bool _showStrata = true;
  bool _showCrossSection = false;     // side-by-side cross-section panel
  int? _selectedClusterIdx;

  // ── AUTO SCAN STATE ──────────────────────────────────────────────────────
  bool _autoScanEnabled = false;
  int _autoScanIntervalSec = 10;          // currently selected interval
  Timer? _autoScanTimer;
  int _autoScanCountdown = 0;             // seconds until next scan
  Timer? _countdownTimer;
  int _autoScanCycleCount = 0;            // total auto-scan cycles fired

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _voxelAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );
    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    // V51.0: only run animations on the active tab → reduces CPU/heat
    _tabController.addListener(_onTabChanged);
    _resumeAnimsForTab(_tabController.index);

    // V50.0: InteractiveViewer controller for periodic table
    _tableTransformCtrl = TransformationController();
    // Set default scale after first frame so layout is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resetTableToFit();
    });
  }

  // Pause / resume heavy animations based on which tab is visible
  void _onTabChanged() {
    if (!mounted) return;
    final tab = _tabController.index;
    // Pause everything first
    if (_voxelAnimController.isAnimating) _voxelAnimController.stop();
    if (_pulseAnimController.isAnimating) _pulseAnimController.stop();
    _resumeAnimsForTab(tab);
  }

  void _resumeAnimsForTab(int tab) {
    // Tab 1 = MULTI-SIGNAL SCAN (pulse), Tab 2 = 3D MATTER TWIN (voxel + pulse),
    // Tab 4 = MAP & HISTORY (voxel for radar sweep)
    switch (tab) {
      case 0: // PERIODIC TABLE — no animation needed
        break;
      case 1: // MULTI-SIGNAL SCAN
        if (!_pulseAnimController.isAnimating) _pulseAnimController.repeat(reverse: true);
        break;
      case 2: // 3D MATTER TWIN
        if (!_voxelAnimController.isAnimating) _voxelAnimController.repeat();
        if (!_pulseAnimController.isAnimating) _pulseAnimController.repeat(reverse: true);
        break;
      case 3: // ANALYSIS — light pulse only
        if (!_pulseAnimController.isAnimating) _pulseAnimController.repeat(reverse: true);
        break;
      case 4: // MAP & HISTORY — radar sweep
        if (!_voxelAnimController.isAnimating) _voxelAnimController.repeat();
        break;
    }
  }

  // V51.0: Properly centre & fit periodic table to screen width
  void _resetTableToFit() {
    if (!mounted) return;
    // Each cell: width 38 + 2×1 margin = 40px. 18 columns = 720px.
    // Account for outer padding 8px each side → total table width = 736px
    const tableW = 736.0;
    final screenW = MediaQuery.of(context).size.width;
    final fitScale = (screenW / tableW).clamp(0.3, 1.0);
    // Translate so the table is horizontally centred at this scale
    final scaledW = tableW * fitScale;
    final offsetX = (screenW - scaledW) / 2.0;
    final m = Matrix4.identity()
      ..translate(offsetX, 0.0)
      ..scale(fitScale);
    _tableTransformCtrl.value = m;
    setState(() => _tableScale = fitScale);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _voxelAnimController.dispose();
    _pulseAnimController.dispose();
    _tableTransformCtrl.dispose();
    _stopAutoScan();
    super.dispose();
  }

  // ── AUTO SCAN LOGIC ──────────────────────────────────────────────────────

  /// Arm the auto-scan timer. Fires startScan() immediately then every N sec.
  void _startAutoScan() {
    _stopAutoScan(); // cancel any previous
    setState(() {
      _autoScanEnabled = true;
      _autoScanCountdown = _autoScanIntervalSec;
    });

    // Fire first scan immediately
    _triggerAutoScan();

    // Repeat every N seconds
    _autoScanTimer = Timer.periodic(
      Duration(seconds: _autoScanIntervalSec),
      (_) => _triggerAutoScan(),
    );

    // Countdown ticker — updates every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _autoScanCountdown--;
        if (_autoScanCountdown <= 0) {
          _autoScanCountdown = _autoScanIntervalSec;
        }
      });
    });
  }

  /// Trigger one scan cycle from auto-scan, respecting calibration state.
  void _triggerAutoScan() {
    if (!mounted) return;
    final s = ref.read(metalDetectionProvider);

    // Wait for calibration before auto-scanning
    if (!s.isCalibrated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('AUTO SCAN: Waiting for magnetometer calibration…',
              style: TextStyle(color: Colors.orange, fontSize: 11)),
          backgroundColor: Colors.black87,
          duration: const Duration(milliseconds: 2200),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    // Don't stack scans
    if (s.isScanning) return;

    ref.read(metalDetectionProvider.notifier).startScan();
    setState(() {
      _autoScanCycleCount++;
      _autoScanCountdown = _autoScanIntervalSec;
    });
  }

  void _stopAutoScan() {
    _autoScanTimer?.cancel();
    _countdownTimer?.cancel();
    _autoScanTimer = null;
    _countdownTimer = null;
    if (mounted) {
      setState(() {
        _autoScanEnabled = false;
        _autoScanCountdown = 0;
      });
    }
  }

  void _toggleAutoScan() {
    if (_autoScanEnabled) {
      _stopAutoScan();
    } else {
      _startAutoScan();
    }
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────
  List<DetectedMatter> _filteredSorted(List<DetectedMatter> raw) {
    final filtered = raw
        .where((d) => d.confidence >= _confidenceThreshold)
        .toList();
    switch (_sortMode) {
      case _SortMode.depth:
        filtered.sort((a, b) => a.depthMetres.compareTo(b.depthMetres));
      case _SortMode.confidence:
        filtered.sort((a, b) => b.confidence.compareTo(a.confidence));
      case _SortMode.type:
        filtered.sort((a, b) => a.matterType.name.compareTo(b.matterType.name));
    }
    return filtered;
  }

  void _recordHistoryEntry(MetalDetectionState s) {
    // V50.0: Record ALL completed scans — even 0-anomaly sessions — so history
    // always accumulates and the Map & History tab is populated.
    final rng = math.Random();
    setState(() => _scanHistory.insert(0, _ScanHistoryEntry(
      timestamp: DateTime.now(),
      detections: List.of(s.detections),
      magnetometerReading: s.magnetometerCurrent,
      latOffset: (rng.nextDouble() - 0.5) * 0.002,
      lonOffset: (rng.nextDouble() - 0.5) * 0.002,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final metalState = ref.watch(metalDetectionProvider);
    final features = ref.watch(featuresProvider);
    final primaryColor = features.primaryColor;
    final detectedZ =
        metalState.detections.map((d) => d.atomicNumber).toSet();

    // V50.0: Record history for every completed scan (incl. 0-anomaly sessions)
    ref.listen<MetalDetectionState>(metalDetectionProvider, (prev, next) {
      if (prev != null && prev.isScanning && !next.isScanning) {
        _recordHistoryEntry(next);
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false, // bottom handled by MediaQuery padding
        child: Column(
          children: [
            _buildHeader(metalState, primaryColor),
            Container(
              color: Colors.black,
              child: TabBar(
                controller: _tabController,
                indicatorColor: primaryColor,
                labelColor: primaryColor,
                unselectedLabelColor: FalconColors.darkOnSurfaceVariant,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'PERIODIC TABLE'),
                  Tab(text: 'MULTI-SIGNAL SCAN'),
                  Tab(text: '3D MATTER TWIN'),
                  Tab(text: 'ANALYSIS'),
                  Tab(text: 'MAP & HISTORY'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPeriodicTable(detectedZ, primaryColor),
                  _buildScanTab(metalState, primaryColor),
                  _buildMatter3DTab(metalState, primaryColor),
                  _buildAnalysisTab(metalState, primaryColor),
                  _buildMapHistoryTab(metalState, primaryColor),
                ],
              ),
            ),
            // Bottom safe area inset (gesture nav bar on edge-to-edge devices)
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────────────────────
  Widget _buildHeader(MetalDetectionState s, Color primary) {
    final deltaT = s.magnetometerCurrent - s.magnetometerBaseline;
    final anomalyColor = deltaT.abs() > 5
        ? const Color(0xFFFF3333)
        : deltaT.abs() > 2
            ? const Color(0xFFFFD700)
            : primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(bottom: BorderSide(color: primary, width: 1)),
      ),
      child: Row(children: [
        const BackButtonTopLeft(),
        const SizedBox(width: 6),
        Icon(Icons.layers, color: primary, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text('GEOPHYSICAL SCAN',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: primary, fontSize: 12,
                      fontWeight: FontWeight.bold, letterSpacing: 1.5))),
              const SizedBox(width: 5),
              _badge('V51.0', primary),
              if (_autoScanEnabled) ...[
                const SizedBox(width: 4),
                _badge('AUTO ⟳', const Color(0xFF00FF66)),
              ],
            ]),
            Text(
              'FUSION • \${s.detections.length} ANOM • \${_flagged.length} FLAG'
              '\${_autoScanEnabled ? " • #\$_autoScanCycleCount/\${_autoScanCountdown}s" : ""}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: FalconColors.darkOnSurfaceVariant, fontSize: 9),
            ),
          ]),
        ),
        // Combined µT + OPT — single tappable button
        GestureDetector(
          onTap: () => FalconSidePanel.show(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: primary.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(5),
              boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.2), blurRadius: 6)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('\${s.magnetometerCurrent.toStringAsFixed(1)} μT',
                  style: TextStyle(color: anomalyColor, fontSize: 11,
                      fontWeight: FontWeight.bold)),
              Text(deltaT.abs() > 0.1
                      ? 'Δ\${deltaT > 0 ? "+" : ""}\${deltaT.toStringAsFixed(1)}'
                      : 'MAG',
                  style: TextStyle(
                      color: anomalyColor.withValues(alpha: 0.6), fontSize: 8)),
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.tune, color: primary, size: 10),
                const SizedBox(width: 2),
                Text('OPT', style: TextStyle(color: primary, fontSize: 7,
                    fontWeight: FontWeight.bold, letterSpacing: 1)),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TAB 1: PERIODIC TABLE
  // ═══════════════════════════════════════════════════════════════════════════
  // ═══════════════════════════════════════════════════════════════════════════
  //  TAB 1: PERIODIC TABLE  — V50.0 InteractiveViewer (proper pinch + center)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPeriodicTable(Set<int> detectedZ, Color primary) {
    return Column(
      children: [
        // ── Fixed header: legend + controls ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: _buildLegend(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(children: [
            Icon(Icons.pinch, color: FalconColors.darkOnSurfaceVariant, size: 12),
            const SizedBox(width: 4),
            Text(
              'Pinch to zoom  •  Scale: ${_tableScale.toStringAsFixed(1)}×',
              style: TextStyle(
                  color: FalconColors.darkOnSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 9),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _resetTableToFit,
              child: Text('RESET',
                  style: TextStyle(
                      color: primary, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        const SizedBox(height: 4),

        // ── InteractiveViewer: proper pinch-to-zoom, centred, no anchor bug ─
        Expanded(
          child: InteractiveViewer(
            transformationController: _tableTransformCtrl,
            minScale: 0.2,
            maxScale: 4.0,
            // Infinite boundary so table never snaps to corner during zoom
            boundaryMargin: const EdgeInsets.all(double.infinity),
            constrained: false,
            onInteractionUpdate: (_) {
              final s = _tableTransformCtrl.value.getMaxScaleOnAxis();
              final r = double.parse(s.toStringAsFixed(1));
              if ((r - _tableScale).abs() >= 0.05) setState(() => _tableScale = r);
            },
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    _buildRow([1], 16, [2]),
                    _buildRow([3, 4], 10, List.generate(6, (i) => 5 + i)),
                    _buildRow([11, 12], 10, List.generate(6, (i) => 13 + i)),
                    _buildRow(List.generate(18, (i) => 19 + i), 0, []),
                    _buildRow(List.generate(18, (i) => 37 + i), 0, []),
                    _buildRowSplit([55, 56], List.generate(15, (i) => 72 + i)),
                    _buildRowSplit([87, 88], List.generate(15, (i) => 104 + i)),
                    const SizedBox(height: 8),
                    _buildRow(List.generate(15, (i) => 57 + i), 0, [], indent: 82),
                    _buildRow(List.generate(15, (i) => 89 + i), 0, [], indent: 82),
                  ],
                ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(List<int> left, int gaps, List<int> right, {double indent = 0}) {
    final detectedZ = ref.read(metalDetectionProvider).detections.map((d) => d.atomicNumber).toSet();
    return Row(children: [
      if (indent > 0) SizedBox(width: indent),
      for (final z in left) _tile(z, detectedZ),
      for (int i = 0; i < gaps; i++) const SizedBox(width: 40),
      for (final z in right) _tile(z, detectedZ),
    ]);
  }

  Widget _buildRowSplit(List<int> left, List<int> right) {
    final detectedZ = ref.read(metalDetectionProvider).detections.map((d) => d.atomicNumber).toSet();
    return Row(children: [
      for (final z in left) _tile(z, detectedZ),
      const SizedBox(width: 40),
      for (final z in right) _tile(z, detectedZ),
    ]);
  }

  Widget _tile(int z, Set<int> detectedZ) {
    final el = _kElements[z - 1];
    final detected = detectedZ.contains(z);
    final supported = _kDetectableZnumbers.contains(z);
    final catColor = _categoryColor(el.category);
    return Opacity(
      opacity: supported ? 1.0 : 0.50,
      child: GestureDetector(
        onTap: () => _showElementDialog(el, detected, supported),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 38, height: 44,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: detected
                ? catColor.withValues(alpha: 0.8)
                : Colors.black.withValues(alpha: 0.6),
            border: Border.all(
                color: detected
                    ? catColor
                    : (supported
                        ? catColor.withValues(alpha: 0.3)
                        : const Color(0xFF1A1A1A)),
                width: detected ? 1.5 : 1),
            borderRadius: BorderRadius.circular(2),
            boxShadow: detected
                ? [BoxShadow(color: catColor.withValues(alpha: 0.5), blurRadius: 6)]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${el.z}',
                  style: TextStyle(
                      color: (detected ? Colors.white : catColor.withValues(alpha: 0.6))
                          .withValues(alpha: 0.7),
                      fontSize: 7)),
              Text(el.symbol,
                  style: TextStyle(
                      color: detected ? Colors.white : catColor.withValues(alpha: 0.6),
                      fontWeight: FontWeight.bold,
                      fontSize: detected ? 11 : 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final cats = ['alkali','alkaline','transition','post-transition','metalloid',
                  'nonmetal','halogen','noble','lanthanide','actinide'];
    return Wrap(
      spacing: 4, runSpacing: 4,
      children: cats.map((c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _categoryColor(c).withValues(alpha: 0.2),
          border: Border.all(color: _categoryColor(c).withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(c, style: TextStyle(color: _categoryColor(c), fontSize: 8)),
      )).toList(),
    );
  }

  void _showElementDialog(_Element el, bool detected, bool supported) {
    final catColor = _categoryColor(el.category);
    final detection = ref
        .read(metalDetectionProvider)
        .detections
        .where((d) => d.atomicNumber == el.z)
        .firstOrNull;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: catColor, width: 2),
        ),
        title: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.2),
              border: Border.all(color: catColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(child: Text(el.symbol,
                style: TextStyle(color: catColor, fontSize: 18, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(el.name, style: TextStyle(color: catColor, fontSize: 16)),
            Text('Z = ${el.z}  •  ${el.category.toUpperCase()}',
                style: const TextStyle(
                    color: FalconColors.darkOnSurfaceVariant, fontSize: 11)),
          ]),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Status',
                detected ? 'DETECTED' : (supported ? 'Not Detected' : 'Unsupported'),
                catColor),
            _infoRow('Detection',
                supported
                    ? 'Radio Signal Fusion (MAG/CSI/RSSI)'
                    : 'Requires Specialized Hardware',
                catColor),
            if (detection != null) ...[
              _infoRow('Confidence', '${(detection.confidence * 100).toStringAsFixed(0)}%', catColor),
              _infoRow('Signal', '${detection.signalStrengthDbm.toStringAsFixed(0)} dBm', catColor),
              _infoRow('Depth', '${(detection.depthMetres * 100).toStringAsFixed(0)} cm', catColor),
              _infoRow('Distance', '${detection.distanceMetres.toStringAsFixed(1)} m', catColor),
              _infoRow('Volume', '${detection.volumeEstimateCm3.toStringAsFixed(1)} cm³', catColor),
              _infoRow('Mass',
                  detection.massEstimateG < 1000
                      ? '${detection.massEstimateG.toStringAsFixed(1)} g'
                      : '${(detection.massEstimateG / 1000).toStringAsFixed(2)} kg',
                  catColor),
              _infoRow('Mag Anomaly', '${detection.magneticAnomaly.toStringAsFixed(1)} μT', catColor),
            ],
            const SizedBox(height: 12),
            Text(
              detected
                  ? 'View this detection in the 3D MATTER TWIN tab.'
                  : 'Run a multi-signal scan to detect this element.',
              style: const TextStyle(
                  color: FalconColors.darkOnSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (detected)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _tabController.animateTo(2);
              },
              child: Text('VIEW 3D TWIN', style: TextStyle(color: catColor)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CLOSE', style: TextStyle(color: catColor)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: FalconColors.darkOnSurfaceVariant, fontSize: 11)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(value,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right),
        ),
      ],
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  //  TAB 2: MULTI-SIGNAL SCAN
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildScanTab(MetalDetectionState s, Color primary) {
    final sorted = _filteredSorted(s.detections);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Signal source cards
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _signalCard(Icons.explore, 'MAGNETOMETER',
                  '${s.magnetometerCurrent.toStringAsFixed(1)} μT',
                  true, true, const Color(0xFFFFD700)),
              _signalCard(Icons.wifi, 'WiFi CSI', '${s.wifiApCount} APs',
                  true, s.wifiApCount > 0, const Color(0xFF00FF66)),
              _signalCard(Icons.cell_tower, 'CELLULAR', '${s.cellTowerCount} towers',
                  true, s.cellTowerCount > 0, const Color(0xFFFF6B6B)),
              _signalCard(Icons.bluetooth, 'BLE', '${s.bleDeviceCount} devices',
                  true, s.bleDeviceCount > 0, const Color(0xFF00CCFF)),
              _signalCard(Icons.sensors, 'IMU FUSION', '200 Hz',
                  true, true, const Color(0xFFBB88FF)),
              _signalCard(Icons.track_changes, 'UWB', 'If Available',
                  true, false, const Color(0xFF888888)),
            ],
          ),

          const SizedBox(height: 16),

          // ── AUTO SCAN SECTION ─────────────────────────────────────────────
          _buildAutoScanSection(s, primary),

          const SizedBox(height: 12),

          // Confidence threshold + sort
          Row(children: [
            Text('MIN CONF:', style: TextStyle(
                color: primary, fontSize: 10, letterSpacing: 1)),
            Expanded(child: Slider(
              value: _confidenceThreshold,
              min: 0.0, max: 0.9, divisions: 9,
              activeColor: primary,
              inactiveColor: FalconColors.darkOutline,
              label: '${(_confidenceThreshold * 100).toInt()}%',
              onChanged: (v) => setState(() => _confidenceThreshold = v),
            )),
            Text('${(_confidenceThreshold * 100).toInt()}%',
                style: TextStyle(
                    color: primary, fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
          Row(children: [
            Text('SORT:', style: TextStyle(
                color: FalconColors.darkOnSurfaceVariant,
                fontSize: 10, letterSpacing: 1)),
            const SizedBox(width: 8),
            ..._SortMode.values.map((m) {
              final active = _sortMode == m;
              return GestureDetector(
                onTap: () => setState(() => _sortMode = m),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: active ? primary.withValues(alpha: 0.15) : Colors.transparent,
                    border: Border.all(
                        color: active ? primary : FalconColors.darkOutline),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(m.name.toUpperCase(),
                      style: TextStyle(
                          color: active
                              ? primary
                              : FalconColors.darkOnSurfaceVariant,
                          fontSize: 9,
                          fontWeight: active ? FontWeight.bold : FontWeight.normal)),
                ),
              );
            }),
          ]),

          const SizedBox(height: 16),

          // Scan depth slider
          Row(children: [
            Text('SCAN DEPTH:', style: TextStyle(
                color: FalconColors.darkOnSurfaceVariant,
                fontSize: 12, letterSpacing: 1)),
            Expanded(child: Slider(
              value: s.scanDepthCm.toDouble(),
              min: 10, max: 300, divisions: 29,
              activeColor: primary,
              inactiveColor: FalconColors.darkOutline,
              onChanged: (v) =>
                  ref.read(metalDetectionProvider.notifier).setScanDepth(v),
            )),
            Text('${s.scanDepthCm.toStringAsFixed(0)} cm',
                style: TextStyle(color: primary, fontSize: 12)),
          ]),

          const SizedBox(height: 8),

          // Signal quality bars
          if (s.signalQualities.isNotEmpty) ...[
            const Text('SIGNAL QUALITY:',
                style: TextStyle(
                    color: FalconColors.darkOnSurfaceVariant,
                    fontSize: 10,
                    letterSpacing: 1)),
            const SizedBox(height: 6),
            ...s.signalQualities.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                SizedBox(
                  width: 40,
                  child: Text(e.key,
                      style: TextStyle(color: primary, fontSize: 9)),
                ),
                Expanded(child: LinearProgressIndicator(
                  value: e.value,
                  color: Color.lerp(
                      const Color(0xFFFF3333), const Color(0xFF00FF66), e.value),
                  backgroundColor: FalconColors.darkOutline,
                  minHeight: 4,
                )),
                SizedBox(
                  width: 30,
                  child: Text('${(e.value * 100).toInt()}%',
                      style: const TextStyle(
                          color: FalconColors.darkOnSurfaceVariant, fontSize: 9),
                      textAlign: TextAlign.right),
                ),
              ]),
            )),
            const SizedBox(height: 12),
          ],

          // Progress bar
          if (s.isScanning || s.scanProgress > 0) ...[
            LinearProgressIndicator(
              value: s.scanProgress,
              color: primary,
              backgroundColor: FalconColors.darkOutline,
            ),
            const SizedBox(height: 8),
            Text(s.statusMessage,
                style: TextStyle(
                    color: primary, fontSize: 11, letterSpacing: 1)),
            if (!s.isCalibrated) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 14),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'CALIBRATION REQUIRED — Press CALIBRATE, then wave device in figure-8',
                    style: TextStyle(
                        color: Colors.orange, fontSize: 10, height: 1.4),
                  )),
                ]),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.07),
                  border: Border.all(color: primary.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(children: [
                  Icon(Icons.check_circle, color: primary, size: 12),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    'BASELINE: ${s.baselineMagnitude.toStringAsFixed(1)} µT  |  '
                    'CURRENT: ${s.currentMagnitude.toStringAsFixed(1)} µT  |  '
                    'Δ: ${(s.currentMagnitude - s.baselineMagnitude).abs().toStringAsFixed(2)} µT',
                    style: TextStyle(
                        color: primary,
                        fontSize: 9,
                        fontFamily: 'monospace'),
                  )),
                ]),
              ),
            ],
            const SizedBox(height: 16),
          ],

          // ── SCAN / STOP BUTTON + CALIBRATE ───────────────────────────────
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                // V49.9 FIX: Button is ALWAYS tappable — works as START or STOP
                onPressed: () {
                  if (s.isScanning) {
                    ref.read(metalDetectionProvider.notifier).stopScan();
                  } else {
                    ref.read(metalDetectionProvider.notifier).startScan();
                  }
                },
                icon: Icon(
                  s.isScanning ? Icons.stop_circle_outlined : Icons.radar,
                  size: 18,
                ),
                label: Text(
                  s.isScanning ? 'STOP SCAN' : 'START MULTI-SIGNAL SCAN',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: s.isScanning
                      ? Colors.red.withValues(alpha: 0.25)
                      : primary,
                  foregroundColor: s.isScanning ? Colors.red : Colors.black,
                  side: BorderSide(
                    color: s.isScanning
                        ? Colors.red.withValues(alpha: 0.6)
                        : primary,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: s.isCalibrating
                  ? null
                  : () => ref.read(metalDetectionProvider.notifier).calibrate(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: primary,
                side: BorderSide(color: primary.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(
                    vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              child: Text(s.isCalibrating ? 'CAL...' : 'CALIBRATE'),
            ),
          ]),

          const SizedBox(height: 20),

          // Detected materials list
          if (sorted.isNotEmpty) ...[
            Row(children: [
              Text('ANOMALIES (${sorted.length}/${s.detections.length}):',
                  style: TextStyle(
                      color: primary, fontSize: 12, letterSpacing: 2)),
              const Spacer(),
              if (_flagged.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text('${_flagged.length} FLAGGED',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
            ]),
            const SizedBox(height: 8),
            ...sorted.asMap().entries.map((entry) {
              final idx = s.detections.indexOf(entry.value);
              final det = entry.value;
              final detColor = _matterTypeColor(det.matterType);
              final isFlagged = _flagged.contains(idx);
              return GestureDetector(
                onTap: () => _showMatterDetailDialog(det, detColor, isFlagged, idx),
                child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isFlagged
                      ? Colors.orange.withValues(alpha: 0.06)
                      : detColor.withValues(alpha: 0.08),
                  border: Border.all(
                      color: isFlagged
                          ? Colors.orange.withValues(alpha: 0.6)
                          : detColor.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: detColor.withValues(alpha: 0.3),
                      border: Border.all(color: detColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(child: Text(det.elementHint,
                        style: TextStyle(
                            color: detColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(det.elementHint,
                            style: TextStyle(
                                color: detColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: detColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(det.matterType.name,
                              style: TextStyle(
                                  color: detColor, fontSize: 8)),
                        ),
                        const Spacer(),
                        // Tap hint
                        Icon(Icons.info_outline,
                            color: detColor.withValues(alpha: 0.4), size: 13),
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        'Depth: ${(det.depthMetres * 100).toStringAsFixed(0)}cm  '
                        '•  Dist: ${det.distanceMetres.toStringAsFixed(1)}m  '
                        '•  Conf: ${(det.confidence * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: FalconColors.darkOnSurfaceVariant,
                            fontSize: 10),
                      ),
                      Text(
                        'Sources: ${det.signalSources.join(", ")}  •  '
                        '${det.signalStrengthDbm.toStringAsFixed(0)} dBm',
                        style: const TextStyle(
                            color: FalconColors.darkOnSurfaceVariant,
                            fontSize: 9),
                      ),
                    ],
                  )),
                  SizedBox(
                    width: 36, height: 36,
                    child: Stack(alignment: Alignment.center, children: [
                      CircularProgressIndicator(
                        value: det.confidence,
                        strokeWidth: 2.5,
                        backgroundColor: FalconColors.darkOutline,
                        color: detColor,
                      ),
                      Text('${(det.confidence * 100).toInt()}',
                          style: TextStyle(
                              color: detColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() {
                      if (isFlagged) {
                        _flagged.remove(idx);
                      } else {
                        _flagged.add(idx);
                      }
                    }),
                    child: Icon(
                      isFlagged ? Icons.flag : Icons.flag_outlined,
                      color: isFlagged
                          ? Colors.orange
                          : FalconColors.darkOnSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ]),
              ),
              );
            }),
          ] else if (s.detections.isNotEmpty) ...[
            Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No anomalies above ${(_confidenceThreshold * 100).toInt()}% confidence threshold',
                style: const TextStyle(
                    color: FalconColors.darkOnSurfaceVariant, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            )),
          ],
        ],
      ),
    );
  }

  // ─── AUTO SCAN SECTION WIDGET ─────────────────────────────────────────────
  Widget _buildAutoScanSection(MetalDetectionState s, Color primary) {
    final autoColor = _autoScanEnabled ? const Color(0xFF00FF66) : primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _autoScanEnabled
            ? const Color(0xFF00FF66).withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.4),
        border: Border.all(
          color: _autoScanEnabled
              ? const Color(0xFF00FF66).withValues(alpha: 0.5)
              : primary.withValues(alpha: 0.25),
          width: _autoScanEnabled ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(children: [
            Icon(Icons.autorenew,
                color: autoColor, size: 16,
                // spin when auto scan is active
                ),
            const SizedBox(width: 6),
            Text('AUTO SCAN',
                style: TextStyle(
                    color: autoColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
            const Spacer(),
            // Cycle counter
            if (_autoScanEnabled) ...[
              Text('CYCLE $_autoScanCycleCount',
                  style: TextStyle(
                      color: autoColor.withValues(alpha: 0.6),
                      fontSize: 9,
                      fontFamily: 'monospace')),
              const SizedBox(width: 10),
            ],
            // ON/OFF toggle
            GestureDetector(
              onTap: () {
                if (!s.isCalibrated && !_autoScanEnabled) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                      'Calibrate magnetometer before enabling auto scan.',
                      style: TextStyle(color: Colors.orange),
                    ),
                    backgroundColor: Colors.black87,
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 3),
                  ));
                  return;
                }
                _toggleAutoScan();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44, height: 22,
                decoration: BoxDecoration(
                  color: _autoScanEnabled
                      ? const Color(0xFF00FF66).withValues(alpha: 0.25)
                      : Colors.black,
                  border: Border.all(
                      color: _autoScanEnabled
                          ? const Color(0xFF00FF66)
                          : FalconColors.darkOutline,
                      width: 1.5),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Stack(children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    left: _autoScanEnabled ? 22 : 2,
                    top: 2,
                    child: Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        color: _autoScanEnabled
                            ? const Color(0xFF00FF66)
                            : FalconColors.darkOnSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ]),

          // Countdown + interval selector (only when enabled or as config)
          const SizedBox(height: 10),
          Row(children: [
            // Interval chips
            Expanded(child: Row(children: [
              Text('INTERVAL: ',
                  style: TextStyle(
                      color: autoColor.withValues(alpha: 0.6),
                      fontSize: 9, letterSpacing: 0.5)),
              ..._kAutoScanIntervals.map((sec) {
                final selected = _autoScanIntervalSec == sec;
                return GestureDetector(
                  onTap: () {
                    setState(() => _autoScanIntervalSec = sec);
                    // Restart timer if currently running with new interval
                    if (_autoScanEnabled) _startAutoScan();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: selected
                          ? autoColor.withValues(alpha: 0.18)
                          : Colors.transparent,
                      border: Border.all(
                          color: selected
                              ? autoColor
                              : FalconColors.darkOutline,
                          width: selected ? 1.5 : 1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      sec >= 60 ? '${sec ~/ 60}m' : '${sec}s',
                      style: TextStyle(
                          color: selected
                              ? autoColor
                              : FalconColors.darkOnSurfaceVariant,
                          fontSize: 9,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal),
                    ),
                  ),
                );
              }),
            ])),
          ]),

          // Countdown progress bar (when active)
          if (_autoScanEnabled) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.timer, color: autoColor, size: 11),
              const SizedBox(width: 4),
              Text('NEXT SCAN IN ${_autoScanCountdown}s',
                  style: TextStyle(
                      color: autoColor, fontSize: 9, fontFamily: 'monospace')),
              const Spacer(),
              Text(
                s.isCalibrated ? '● MAG OK' : '○ WAITING CALIB',
                style: TextStyle(
                    color: s.isCalibrated
                        ? const Color(0xFF00FF66)
                        : Colors.orange,
                    fontSize: 8),
              ),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _autoScanIntervalSec > 0
                    ? 1.0 -
                        (_autoScanCountdown / _autoScanIntervalSec)
                            .clamp(0.0, 1.0)
                    : 0.0,
                minHeight: 3,
                backgroundColor: autoColor.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(autoColor),
              ),
            ),
          ],

          // Description
          const SizedBox(height: 8),
          Text(
            _autoScanEnabled
                ? 'Auto-scan running — magnetometer is polled every $_autoScanIntervalSec seconds. '
                  'Move device slowly over the target area for best results.'
                : 'Enable to continuously scan for metal anomalies at a fixed interval. '
                  'Calibrate magnetometer first for accurate detection.',
            style: const TextStyle(
                color: FalconColors.darkOnSurfaceVariant,
                fontSize: 9,
                height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _signalCard(IconData icon, String label, String value,
      bool supported, bool active, Color color) {
    return Opacity(
      opacity: supported ? 1.0 : 0.4,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          border: Border.all(
              color: active && supported
                  ? color
                  : FalconColors.darkOutline),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon,
                  color: active ? color : FalconColors.darkOnSurfaceVariant,
                  size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(label,
                  style: TextStyle(
                      color: active
                          ? color
                          : FalconColors.darkOnSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1),
                  overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: active ? Colors.white : FalconColors.darkOutline,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TAB 3: 3D MATTER TWIN
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  //  TAB 3: ENHANCED 3D MATTER TWIN  V49.9
  //  • Isometric / Cross-Section / Top-Down view modes
  //  • Drag-to-orbit (horizontal=yaw, vertical=pitch)
  //  • Named soil strata with geology labels
  //  • Detection clustering (group hits within 0.8 m radius)
  //  • Toggle-able XSEC side panel
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMatter3DTab(MetalDetectionState s, Color primary) {
    final clusters = _showClusters
        ? _clusterDetections(s.detections, 0.8)
        : s.detections
            .map((d) => _DetCluster(
                  members: [d],
                  cx: d.x,
                  cy: d.depthMetres,
                  cz: d.z,
                  totalMassG: d.massEstimateG,
                  avgConfidence: d.confidence,
                  dominantType: d.matterType,
                ))
            .toList();

    return Column(
      children: [
        // ── View controls toolbar ───────────────────────────────────────
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(children: [
            ..._ViewMode.values.map((m) {
              final active = _viewMode == m;
              final label = switch (m) {
                _ViewMode.isometric    => 'ISO',
                _ViewMode.crossSection => 'CROSS',
                _ViewMode.topDown      => 'TOP',
              };
              return GestureDetector(
                onTap: () => setState(() => _viewMode = m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: active ? primary.withValues(alpha: 0.18) : Colors.transparent,
                    border: Border.all(
                        color: active ? primary : FalconColors.darkOutline,
                        width: active ? 1.5 : 1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          color: active ? primary : FalconColors.darkOnSurfaceVariant,
                          fontSize: 9,
                          fontWeight: active ? FontWeight.bold : FontWeight.normal,
                          letterSpacing: 0.5)),
                ),
              );
            }),
            const SizedBox(width: 4),
            _toolBtn('STRATA', _showStrata, primary,
                () => setState(() => _showStrata = !_showStrata)),
            const SizedBox(width: 4),
            _toolBtn('CLUSTER', _showClusters, primary,
                () => setState(() => _showClusters = !_showClusters)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() {
                _orbitAngle = 0.3;
                _pitchAngle = 0.45;
              }),
              child: Icon(Icons.refresh,
                  color: FalconColors.darkOnSurfaceVariant, size: 16),
            ),
            const SizedBox(width: 6),
            Text('DRAG TO ORBIT',
                style: TextStyle(
                    color: FalconColors.darkOnSurfaceVariant.withValues(alpha: 0.4),
                    fontSize: 7,
                    letterSpacing: 0.5)),
          ]),
        ),

        // ── Main 3D canvas ──────────────────────────────────────────────
        Expanded(
          child: Row(children: [
            Expanded(
              flex: _showCrossSection ? 3 : 1,
              child: GestureDetector(
                onPanUpdate: (d) => setState(() {
                  _orbitAngle =
                      (_orbitAngle + d.delta.dx * 0.012) % (2 * math.pi);
                  _pitchAngle =
                      (_pitchAngle - d.delta.dy * 0.008).clamp(0.05, 0.9);
                }),
                onTapUp: (details) {
                  if (clusters.isEmpty) return;
                  final sz = context.size ?? const Size(360, 600);
                  int? nearest;
                  double minDist = 44;
                  for (int i = 0; i < clusters.length; i++) {
                    final c = clusters[i];
                    final proj = _projectIso(
                        c.cx, c.cy, c.cz, sz,
                        s.scanDepthCm, _orbitAngle, _pitchAngle, _viewMode);
                    final dist = (details.localPosition - proj).distance;
                    if (dist < minDist) {
                      minDist = dist;
                      nearest = i;
                    }
                  }
                  setState(() {
                    _selectedClusterIdx =
                        nearest == _selectedClusterIdx ? null : nearest;
                    _selectedDetectionIdx = _selectedClusterIdx != null
                        ? s.detections
                            .indexOf(clusters[_selectedClusterIdx!].members.first)
                        : null;
                  });
                },
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                  animation: _voxelAnimController,
                  builder: (context, _) => CustomPaint(
                    size: Size.infinite,
                    painter: _Matter3DPainter(
                      detections: s.detections,
                      clusters: clusters,
                      time: _voxelAnimController.value * 8,
                      scanDepthCm: s.scanDepthCm.toInt(),
                      primaryColor: primary,
                      magnetometerCurrent: s.magnetometerCurrent,
                      magnetometerBaseline: s.magnetometerBaseline,
                      selectedClusterIdx: _selectedClusterIdx,
                      orbitAngle: _orbitAngle,
                      pitchAngle: _pitchAngle,
                      viewMode: _viewMode,
                      showStrata: _showStrata,
                      showClusters: _showClusters,
                    ),
                  ),
                ),
                ),
              ),
            ),
            if (_showCrossSection) ...[
              Container(width: 1, color: primary.withValues(alpha: 0.2)),
              Expanded(
                flex: 2,
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                  animation: _voxelAnimController,
                  builder: (_, __) => CustomPaint(
                    size: Size.infinite,
                    painter: _CrossSectionPainter(
                      clusters: clusters,
                      scanDepthCm: s.scanDepthCm.toInt(),
                      primaryColor: primary,
                      time: _voxelAnimController.value * 8,
                    ),
                  ),
                ),
                ),
              ),
            ],
          ]),
        ),

        // ── Bottom HUD bar ──────────────────────────────────────────────
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(children: [
            Icon(Icons.layers, color: primary, size: 12),
            const SizedBox(width: 5),
            Text(
              '${s.detections.length} det  •  ${clusters.length} cluster'
              '  •  ${(_orbitAngle * 57.3).toStringAsFixed(0)}° orbit',
              style: TextStyle(
                  color: FalconColors.darkOnSurfaceVariant,
                  fontSize: 8,
                  fontFamily: 'monospace'),
            ),
            const Spacer(),
            if (s.isScanning)
              AnimatedBuilder(
                animation: _pulseAnimController,
                builder: (_, __) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF3333).withValues(
                        alpha: 0.5 + _pulseAnimController.value * 0.5),
                  ),
                ),
              ),
            _toolBtn('XSEC', _showCrossSection, primary,
                () => setState(() => _showCrossSection = !_showCrossSection)),
          ]),
        ),

        // ── Cluster detail panel ────────────────────────────────────────
        if (_selectedClusterIdx != null &&
            _selectedClusterIdx! < clusters.length)
          _buildClusterDetail(clusters[_selectedClusterIdx!], primary),

        if (s.detections.isEmpty)
          Expanded(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.view_in_ar_outlined,
                    color: FalconColors.darkOnSurfaceVariant, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'RUN A MULTI-SIGNAL SCAN\nor enable AUTO SCAN\nto populate the 3D matter twin',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: FalconColors.darkOnSurfaceVariant, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: s.isScanning
                      ? () => ref.read(metalDetectionProvider.notifier).stopScan()
                      : () => ref.read(metalDetectionProvider.notifier).startScan(),
                  icon: Icon(
                    s.isScanning ? Icons.stop_circle_outlined : Icons.radar,
                    size: 16,
                  ),
                  label: Text(
                    s.isScanning ? 'STOP SCAN' : 'START SCAN',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: s.isScanning
                        ? Colors.red.withValues(alpha: 0.2)
                        : primary.withValues(alpha: 0.9),
                    foregroundColor: s.isScanning ? Colors.red : Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ]),
            ),
          ),
      ],
    );
  }

  // ── Cluster detail footer card ──────────────────────────────────────────
  Widget _buildClusterDetail(_DetCluster cluster, Color primary) {
    final color = _matterTypeColor(cluster.dominantType);
    final topDet = cluster.members
        .reduce((a, b) => a.confidence > b.confidence ? a : b);
    final stratum = _stratumForDepth(cluster.cy * 100);
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: color.withValues(alpha: 0.5)))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                cluster.members.length > 1
                    ? '${cluster.members.length}×'
                    : topDet.elementHint,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                cluster.members.length > 1
                    ? 'CLUSTER — ${cluster.members.length} detections'
                    : '${topDet.elementHint}  •  ${topDet.matterType.name.toUpperCase()}',
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Text(
                '${cluster.dominantType.name}  •  ${stratum.name}  •  ${stratum.composition}',
                style: TextStyle(
                    color: color.withValues(alpha: 0.6), fontSize: 9),
              ),
            ]),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _selectedClusterIdx = null;
              _selectedDetectionIdx = null;
            }),
            child: Icon(Icons.close,
                color: FalconColors.darkOnSurfaceVariant, size: 14),
          ),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _miniStat('DEPTH', '${(cluster.cy * 100).toStringAsFixed(0)}cm', color),
          _miniStat('CONF', '${(cluster.avgConfidence * 100).toInt()}%', color),
          _miniStat(
              'MASS',
              cluster.totalMassG < 1000
                  ? '${cluster.totalMassG.toStringAsFixed(0)}g'
                  : '${(cluster.totalMassG / 1000).toStringAsFixed(2)}kg',
              color),
          _miniStat('HITS', '${cluster.members.length}', color),
          _miniStat('STRAT', stratum.name, color),
        ]),
      ]),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  Widget _toolBtn(
          String label, bool active, Color primary, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: active ? primary.withValues(alpha: 0.15) : Colors.transparent,
            border: Border.all(
                color: active ? primary : FalconColors.darkOutline,
                width: active ? 1.5 : 1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(label,
              style: TextStyle(
                  color: active ? primary : FalconColors.darkOnSurfaceVariant,
                  fontSize: 8,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        ),
      );

  _SoilStratum _stratumForDepth(double depthCm) => _kStrata
      .firstWhere((s) => depthCm < s.toCm, orElse: () => _kStrata.last);

  // Project 3D point → screen Offset (used for hit testing)
  Offset _projectIso(double wx, double wy, double wz, Size sz,
      double scanDepthCm, double orbit, double pitch, _ViewMode mode) {
    final cx = sz.width / 2;
    final groundY = sz.height * 0.18;
    final sceneH = sz.height - groundY - 20;
    switch (mode) {
      case _ViewMode.topDown:
        return Offset(
          cx + wx * sz.width * 0.08,
          groundY + (wy / (scanDepthCm / 100.0)).clamp(0, 1) * sceneH * 0.5 +
              wz * sz.width * 0.06,
        );
      case _ViewMode.crossSection:
        return Offset(
          cx + wx * sz.width * 0.1,
          groundY + (wy / (scanDepthCm / 100.0)).clamp(0, 1) * sceneH,
        );
      case _ViewMode.isometric:
      default:
        final cosA = math.cos(orbit);
        final sinA = math.sin(orbit);
        final rx = wx * cosA - wz * sinA;
        final rz = wx * sinA + wz * cosA;
        final isoX = cx + rx * sz.width * 0.1;
        final isoY = groundY +
            (wy / (scanDepthCm / 100.0)).clamp(0, 1) * sceneH * pitch +
            rz * sz.height * 0.04;
        return Offset(isoX, isoY);
    }
  }

  Widget _miniStat(String label, String val, Color color) =>
      Column(children: [
        Text(val,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(
                color: FalconColors.darkOnSurfaceVariant,
                fontSize: 8,
                letterSpacing: 0.5)),
      ]);

  //  TAB 4: ANOMALY ANALYSIS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAnalysisTab(MetalDetectionState s, Color primary) {
    if (s.detections.isEmpty) {
      final deltaT = s.magnetometerCurrent - s.magnetometerBaseline;
      final anomalyColor = deltaT.abs() > 5
          ? const Color(0xFFFF3333)
          : deltaT.abs() > 2
              ? const Color(0xFFFFD700)
              : primary;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Icon(Icons.analytics_outlined,
              color: FalconColors.darkOnSurfaceVariant, size: 44),
          const SizedBox(height: 10),
          const Text('Run a scan to see anomaly analysis',
              style: TextStyle(
                  color: FalconColors.darkOnSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 20),
          // Live MAG stats shown pre-scan
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.05),
              border: Border.all(color: primary.withValues(alpha: 0.25)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(children: [
              Text('LIVE MAGNETOMETER',
                  style: TextStyle(
                      color: primary,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _preScanStat('CURRENT',
                      '${s.magnetometerCurrent.toStringAsFixed(1)} μT', anomalyColor),
                  Container(width: 1, height: 36,
                      color: primary.withValues(alpha: 0.2)),
                  _preScanStat('BASELINE',
                      s.isCalibrated
                          ? '${s.magnetometerBaseline.toStringAsFixed(1)} μT'
                          : '—',
                      primary),
                  Container(width: 1, height: 36,
                      color: primary.withValues(alpha: 0.2)),
                  _preScanStat('Δ',
                      s.isCalibrated
                          ? '${deltaT > 0 ? '+' : ''}${deltaT.toStringAsFixed(1)} μT'
                          : '—',
                      anomalyColor),
                ],
              ),
              if (!s.isCalibrated) ...[ 
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.warning_amber, color: Colors.orange, size: 12),
                  const SizedBox(width: 6),
                  Text('Calibrate magnetometer for accurate analysis',
                      style: const TextStyle(color: Colors.orange, fontSize: 10)),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: s.isScanning
                  ? () => ref.read(metalDetectionProvider.notifier).stopScan()
                  : () => ref.read(metalDetectionProvider.notifier).startScan(),
              icon: Icon(
                s.isScanning ? Icons.stop_circle_outlined : Icons.radar,
                size: 16,
              ),
              label: Text(
                s.isScanning ? 'STOP SCAN' : 'START MULTI-SIGNAL SCAN',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: s.isScanning
                    ? Colors.red.withValues(alpha: 0.2)
                    : primary,
                foregroundColor: s.isScanning ? Colors.red : Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
        ]),
      );
    }

    final byType = <MatterType, List<DetectedMatter>>{};
    for (final d in s.detections) {
      byType.putIfAbsent(d.matterType, () => []).add(d);
    }
    final deepest = s.detections.reduce(
        (a, b) => a.depthMetres > b.depthMetres ? a : b);
    final strongest = s.detections.reduce(
        (a, b) => a.confidence > b.confidence ? a : b);
    final avgConf = s.detections.fold(0.0, (sum, d) => sum + d.confidence) /
        s.detections.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _analysisCard('DEEPEST',
              '${(deepest.depthMetres * 100).toStringAsFixed(0)}cm',
              deepest.elementHint.split(' ').first, const Color(0xFF4FC3F7)),
          const SizedBox(width: 6),
          _analysisCard('STRONGEST',
              '${(strongest.confidence * 100).toInt()}%',
              strongest.elementHint.split(' ').first, const Color(0xFF00FF66)),
          const SizedBox(width: 6),
          _analysisCard('AVG CONF', '${(avgConf * 100).toInt()}%',
              '${s.detections.length} total', primary),
        ]),
        const SizedBox(height: 14),
        Text('MATTER TYPE BREAKDOWN', style: TextStyle(color: primary,
            fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: Row(children: [
            SizedBox(width: 150, height: 150,
              child: CustomPaint(
                painter: _TypePiePainter(byType: byType, total: s.detections.length),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: byType.entries.map((e) {
                final pct = (e.value.length / s.detections.length * 100).toInt();
                final c = _matterTypeColor(e.key);
                return GestureDetector(
                  onTap: () => _showMatterDetailDialog(e.value.first, c, false, 0),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Container(width: 10, height: 10,
                          decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Expanded(child: Text(e.key.name,
                          style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold))),
                      Text('$pct% (${e.value.length})',
                          style: const TextStyle(
                              color: FalconColors.darkOnSurfaceVariant, fontSize: 8)),
                      const SizedBox(width: 3),
                      Icon(Icons.chevron_right, color: c.withValues(alpha: 0.5), size: 12),
                    ]),
                  ),
                );
              }).toList(),
            )),
          ]),
        ),
        const SizedBox(height: 14),
        Text('DEPTH DISTRIBUTION', style: TextStyle(color: primary,
            fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        _buildDepthHistogram(s.detections, primary),
        const SizedBox(height: 14),
        Text('FUSION SOURCE MATRIX', style: TextStyle(color: primary,
            fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        _buildFusionMatrix(s.detections, primary),
        const SizedBox(height: 14),
        Row(children: [
          Text('ALL DETECTIONS', style: TextStyle(color: primary,
              fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${s.detections.length}',
                style: TextStyle(color: primary, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 8),
        ...(_filteredSorted(s.detections).asMap().entries.map((entry) {
          final idx = entry.key;
          final det = entry.value;
          final dc = _matterTypeColor(det.matterType);
          final isFlagged = _flagged.contains(idx);
          return GestureDetector(
            onTap: () => _showMatterDetailDialog(det, dc, isFlagged, idx),
            child: Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: dc.withValues(alpha: 0.05),
                border: Border.all(color: dc.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: dc.withValues(alpha: 0.15),
                      border: Border.all(color: dc, width: 1),
                      borderRadius: BorderRadius.circular(4)),
                  child: Center(child: Text(
                    det.elementHint.split(' ').first,
                    style: TextStyle(color: dc, fontSize: 8, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  )),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(det.elementHint, style: TextStyle(color: dc, fontSize: 10,
                      fontWeight: FontWeight.bold)),
                  Text(
                    '${(det.depthMetres * 100).toStringAsFixed(0)}cm  •  '
                    '${(det.confidence * 100).toInt()}% conf  •  ${det.matterType.name}',
                    style: const TextStyle(
                        color: FalconColors.darkOnSurfaceVariant, fontSize: 8),
                  ),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    det.massEstimateG < 1000
                        ? '${det.massEstimateG.toStringAsFixed(0)}g'
                        : '${(det.massEstimateG / 1000).toStringAsFixed(1)}kg',
                    style: TextStyle(color: dc, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                  if (isFlagged) const Icon(Icons.flag, color: Colors.red, size: 10),
                  Icon(Icons.chevron_right, color: dc.withValues(alpha: 0.5), size: 14),
                ]),
              ]),
            ),
          );
        })),
        const SizedBox(height: 8),
      ]),
    );
  }

  // Pre-scan stat cell used in the Analysis tab empty state
  Widget _preScanStat(String label, String value, Color color) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(
                color: color.withValues(alpha: 0.6),
                fontSize: 9,
                letterSpacing: 0.8)),
      ]);

  Widget _analysisCard(String label, String value, String sub, Color color) =>
      Expanded(child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.6),
                  fontSize: 9,
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          Text(sub,
              style: const TextStyle(
                  color: FalconColors.darkOnSurfaceVariant, fontSize: 9)),
        ]),
      ));

  Widget _buildDepthHistogram(List<DetectedMatter> dets, Color color) {
    if (dets.isEmpty) return const SizedBox.shrink();
    final maxDepth = dets.map((d) => d.depthMetres).reduce((a, b) => a > b ? a : b);
    if (maxDepth == 0) return const SizedBox.shrink();
    final bins = List.filled(5, 0);
    for (final d in dets) {
      final b = (d.depthMetres / maxDepth * 4.99).toInt().clamp(0, 4);
      bins[b]++;
    }
    final maxBin = bins.reduce((a, b) => a > b ? a : b).toDouble().clamp(1.0, 999.0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: bins.asMap().entries.map((e) {
        final frac = e.value / maxBin;
        final depthLabel =
            '${((e.key * 0.2) * maxDepth * 100).toStringAsFixed(0)}cm';
        return Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(children: [
            Text('${e.value}',
                style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: 60 * frac,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            Text(depthLabel,
                style: const TextStyle(
                    color: FalconColors.darkOnSurfaceVariant, fontSize: 7)),
          ]),
        ));
      }).toList(),
    );
  }

  Widget _buildFusionMatrix(List<DetectedMatter> dets, Color color) {
    final sourceCounts = <String, int>{};
    for (final d in dets) {
      for (final src in d.signalSources) {
        sourceCounts[src] = (sourceCounts[src] ?? 0) + 1;
      }
    }
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: sourceCounts.entries.map((e) {
        final pct = dets.isEmpty
            ? 0
            : (e.value / dets.length * 100).toInt();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(children: [
            Text(e.key.toUpperCase(),
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            Text('${e.value} dets  |  $pct%',
                style: const TextStyle(
                    color: FalconColors.darkOnSurfaceVariant, fontSize: 8)),
          ]),
        );
      }).toList(),
    );
  }

  // ─── Small helpers ────────────────────────────────────────────────────────
  // ─── Matter detail popup (scan tab card tap) ─────────────────────────────
  void _showMatterDetailDialog(
      DetectedMatter det, Color color, bool isFlagged, int idx) {
    final stratum = _stratumForDepth(det.depthMetres * 100);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF050D0A),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 18)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    border: Border.all(color: color),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(child: Text(
                    det.elementHint.split(' ').first,
                    style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold),
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(det.elementHint,
                      style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(det.matterType.name.toUpperCase(),
                      style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10, letterSpacing: 1)),
                ])),
                if (isFlagged)
                  Icon(Icons.flag, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Icon(Icons.close, color: color.withValues(alpha: 0.6), size: 18),
                ),
              ]),
            ),

            // Confidence ring + mass estimate hero row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(children: [
                // Confidence ring
                SizedBox(width: 64, height: 64,
                  child: Stack(alignment: Alignment.center, children: [
                    CircularProgressIndicator(
                      value: det.confidence,
                      strokeWidth: 5,
                      backgroundColor: color.withValues(alpha: 0.1),
                      color: color,
                    ),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${(det.confidence * 100).toInt()}%',
                          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('CONF', style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 7)),
                    ]),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    det.massEstimateG < 1000
                        ? '${det.massEstimateG.toStringAsFixed(1)} g'
                        : '${(det.massEstimateG / 1000).toStringAsFixed(2)} kg',
                    style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text('EST. MASS', style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 9, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('Vol: ${det.volumeEstimateCm3.toStringAsFixed(1)} cm³',
                      style: TextStyle(color: FalconColors.darkOnSurfaceVariant, fontSize: 10)),
                ])),
              ]),
            ),

            // Info grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(children: [
                _detRow('Depth underground', '${(det.depthMetres * 100).toStringAsFixed(1)} cm', color),
                _detRow('Distance from device', '${det.distanceMetres.toStringAsFixed(2)} m', color),
                _detRow('Signal strength', '${det.signalStrengthDbm.toStringAsFixed(1)} dBm', color),
                _detRow('Magnetic anomaly', '${det.magneticAnomaly.toStringAsFixed(2)} μT', color),
                _detRow('Phase shift', '${det.phaseShiftRad.toStringAsFixed(3)} rad', color),
                _detRow('Backscatter ratio', '${(det.backscatterRatio * 100).toStringAsFixed(0)}%', color),
                _detRow('Signal sources', det.signalSources.join(', '), color),
                _detRow('Atomic Z', det.atomicNumber > 0 ? '${det.atomicNumber}' : '—', color),
                _detRow('Soil stratum', '${stratum.name}  •  ${stratum.composition}', color),
                _detRow('3D position', '(${det.x.toStringAsFixed(1)}, ${det.depthMetres.toStringAsFixed(2)}, ${det.z.toStringAsFixed(1)}) m', color),
              ]),
            ),
            const SizedBox(height: 8),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      if (isFlagged) _flagged.remove(idx); else _flagged.add(idx);
                    });
                  },
                  icon: Icon(isFlagged ? Icons.flag : Icons.flag_outlined,
                      size: 14, color: isFlagged ? Colors.orange : color),
                  label: Text(isFlagged ? 'UNFLAG' : 'FLAG',
                      style: TextStyle(
                          color: isFlagged ? Colors.orange : color, fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isFlagged
                        ? Colors.orange.withValues(alpha: 0.4)
                        : color.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _tabController.animateTo(2);
                  },
                  icon: const Icon(Icons.view_in_ar, size: 14),
                  label: const Text('VIEW 3D', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                )),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _detRow(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3.5),
    child: Row(children: [
      Text(label, style: const TextStyle(color: FalconColors.darkOnSurfaceVariant, fontSize: 10)),
      const Spacer(),
      Flexible(child: Text(value,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
    ]),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  //  TAB 5: MAP & HISTORY
  //  Top half: canvas radar-map showing all detected matters with relative XZ
  //  Bottom half: scrollable session history list
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMapHistoryTab(MetalDetectionState s, Color primary) {
    // V50.0: Live compass heading from real magnetometer/IMU
    final imu = ref.watch(imuFusionProvider);
    final compassHeading = imu.yaw;   // radians, real compass heading
    final headingDeg = (compassHeading * 180 / math.pi).round();

    // Nearest detection (closest to device)
    DetectedMatter? nearest;
    if (s.detections.isNotEmpty) {
      nearest = s.detections.reduce((a, b) =>
          (a.x * a.x + a.z * a.z) < (b.x * b.x + b.z * b.z) ? a : b);
    }

    return Column(children: [
      // ── TOP: Compass-guided radar detection map ─────────────────────────
      Expanded(
        flex: 3,
        child: Stack(children: [
          RepaintBoundary(
            child: AnimatedBuilder(
            animation: _voxelAnimController,
            builder: (_, __) => CustomPaint(
              size: Size.infinite,
              painter: _RadarMapPainter(
                currentDetections: s.detections,
                history: _scanHistory,
                primaryColor: primary,
                time: _voxelAnimController.value * 8,
                compassHeading: compassHeading,
                nearestDetection: nearest,
              ),
            ),
          ),
          ),
          // Map legend
          Positioned(top: 8, right: 8, child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('DETECTION MAP', style: TextStyle(
                  color: primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              Text('Compass-up  •  Real heading',
                  style: TextStyle(color: FalconColors.darkOnSurfaceVariant, fontSize: 8)),
              const SizedBox(height: 4),
              _mapLegendChip('Current scan', primary),
              ..._scanHistory.take(3).toList().asMap().entries.map((e) =>
                  _mapLegendChip('Session ${_scanHistory.length - e.key}',
                      _historyColor(e.key))),
            ],
          )),
          // Compass heading + guidance panel (top-left)
          Positioned(
            top: 8, left: 8,
            child: _buildCompassGuidancePanel(
                compassHeading, headingDeg, nearest, primary, imu.hasMag),
          ),
        ]),
      ),

      Container(height: 1, color: primary.withValues(alpha: 0.2)),

      // ── MIDDLE: Real GPS Map (OpenStreetMap tiles) — Expanded flex:5 ─────
      Expanded(
        flex: 5,
        child: Column(children: [
          // GPS map header
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(children: [
              Icon(Icons.map, color: primary, size: 13),
              const SizedBox(width: 6),
              Text('GPS DETECTION MAP',
                  style: TextStyle(color: primary, fontSize: 11,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(width: 6),
              Text('· OpenStreetMap',
                  style: TextStyle(
                      color: FalconColors.darkOnSurfaceVariant, fontSize: 8)),
            ]),
          ),
          Expanded(
            child: _OsmMapWidget(
              currentDetections: s.detections,
              history: _scanHistory,
              primaryColor: primary,
            ),
          ),
        ]),
      ),

      Container(height: 1, color: primary.withValues(alpha: 0.2)),

      // ── BOTTOM: Scan history list ────────────────────────────────────────
      Expanded(
        flex: 3,
        child: Column(children: [
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              Icon(Icons.history, color: primary, size: 14),
              const SizedBox(width: 6),
              Text('SCAN HISTORY  •  ${_scanHistory.length} sessions',
                  style: TextStyle(color: primary, fontSize: 11,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              const Spacer(),
              if (_scanHistory.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _scanHistory.clear()),
                  child: Text('CLEAR',
                      style: TextStyle(
                          color: FalconColors.darkOnSurfaceVariant, fontSize: 9)),
                ),
            ]),
          ),
          Expanded(child: _scanHistory.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.radar, color: FalconColors.darkOnSurfaceVariant, size: 36),
                const SizedBox(height: 8),
                const Text('Complete a scan to record history',
                    style: TextStyle(color: FalconColors.darkOnSurfaceVariant, fontSize: 12)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                itemCount: _scanHistory.length,
                itemBuilder: (_, i) {
                  final entry = _scanHistory[i];
                  final histColor = i == 0 ? primary : _historyColor(i);
                  final dom = entry.dominantType;
                  final domColor = dom != null ? _matterTypeColor(dom) : FalconColors.darkOnSurfaceVariant;
                  final timeStr = _formatTime(entry.timestamp);
                  return GestureDetector(
                    onTap: () => _showHistoryDetail(entry, histColor),
                    child: Container(
                    margin: const EdgeInsets.only(bottom: 7),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: histColor.withValues(alpha: 0.05),
                      border: Border.all(color: histColor.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: histColor.withValues(alpha: 0.15),
                          border: Border.all(color: histColor.withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(child: Text('${_scanHistory.length - i}',
                            style: TextStyle(color: histColor, fontSize: 11,
                                fontWeight: FontWeight.bold))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(timeStr,
                              style: TextStyle(color: histColor, fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          if (i == 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text('LATEST',
                                  style: TextStyle(color: primary, fontSize: 7,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ]),
                        const SizedBox(height: 2),
                        Row(children: [
                          Text('${entry.anomalyCount} anomalies',
                              style: const TextStyle(
                                  color: FalconColors.darkOnSurfaceVariant, fontSize: 10)),
                          const SizedBox(width: 8),
                          if (dom != null) ...[ 
                            Container(width: 7, height: 7,
                                decoration: BoxDecoration(color: domColor, shape: BoxShape.circle)),
                            const SizedBox(width: 3),
                            Text(dom.name,
                                style: TextStyle(color: domColor, fontSize: 9)),
                          ],
                          const Spacer(),
                          Text('${entry.magnetometerReading.toStringAsFixed(1)} μT',
                              style: const TextStyle(
                                  color: FalconColors.darkOnSurfaceVariant, fontSize: 9)),
                        ]),
                      ])),
                      Icon(Icons.chevron_right,
                          color: histColor.withValues(alpha: 0.5), size: 18),
                    ]),
                  ),
                  );
                },
              )),
        ]),
      ),
    ]);
  }

  // ── Compass + Guidance Panel ─────────────────────────────────────────────
  Widget _buildCompassGuidancePanel(double headingRad, int headingDeg,
      DetectedMatter? nearest, Color primary, bool hasMag) {
    // Cardinal name
    const cardinals = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final cardIdx = (((headingDeg + 360) % 360 + 22) ~/ 45) % 8;
    final cardinal = cardinals[cardIdx.clamp(0, 7)];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        border: Border.all(color: primary.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Heading row
          Row(mainAxisSize: MainAxisSize.min, children: [
            Transform.rotate(
              angle: headingRad,
              child: const Icon(Icons.navigation,
                  color: Color(0xFFFF3333), size: 14),
            ),
            const SizedBox(width: 5),
            Text('$headingDeg° $cardinal',
                style: TextStyle(
                    color: primary, fontSize: 11, fontWeight: FontWeight.bold)),
            if (!hasMag) ...[ 
              const SizedBox(width: 5),
              const Icon(Icons.warning_amber, color: Colors.orange, size: 10),
            ],
          ]),
          // Guidance to nearest detection
          if (nearest != null) ...[ 
            const SizedBox(height: 5),
            Builder(builder: (_) {
              final dist = math.sqrt(nearest.x * nearest.x + nearest.z * nearest.z);
              // World bearing: z-negative=north, x-positive=east
              final worldBearing = math.atan2(nearest.x, -nearest.z);
              // Bearing relative to phone heading
              final relBearingDeg = ((worldBearing - headingRad) * 180 / math.pi)
                  .remainder(360);
              final normDeg = relBearingDeg < -180
                  ? relBearingDeg + 360
                  : relBearingDeg > 180
                      ? relBearingDeg - 360
                      : relBearingDeg;
              String dir;
              if (normDeg.abs() < 20) dir = '▲ AHEAD';
              else if (normDeg > 0 && normDeg < 90) dir = '▶ TURN R';
              else if (normDeg >= 90) dir = '◀ BEHIND R';
              else if (normDeg < 0 && normDeg > -90) dir = '◀ TURN L';
              else dir = '▶ BEHIND L';
              final detColor = _matterTypeColor(nearest.matterType);
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 7, height: 7,
                    decoration: BoxDecoration(color: detColor, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(
                  '${nearest.elementHint.split(' ').first}  '
                  '${dist.toStringAsFixed(1)}m  $dir',
                  style: TextStyle(
                      color: detColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold),
                ),
              ]);
            }),
          ] else ...[ 
            const SizedBox(height: 4),
            Text('No detections', style: TextStyle(
                color: FalconColors.darkOnSurfaceVariant, fontSize: 8)),
          ],
        ],
      ),
    );
  }

  Color _historyColor(int sessionAge) {
    const palette = [
      Color(0xFF00FF66), Color(0xFF00CCFF), Color(0xFFFFD700),
      Color(0xFFBB88FF), Color(0xFFFF8A65), Color(0xFF4FC3F7),
    ];
    return palette[sessionAge.clamp(0, palette.length - 1)];
  }

  Widget _mapLegendChip(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 8)),
    ],
  );

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showHistoryDetail(_ScanHistoryEntry entry, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF050D0A),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 32, height: 3,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              Text('Session  ${_formatTime(entry.timestamp)}',
                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${entry.anomalyCount} detections',
                  style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 11)),
            ]),
          ),
          Divider(color: color.withValues(alpha: 0.2), height: 1),
          Expanded(child: ListView.builder(
            controller: ctrl,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: entry.detections.length,
            itemBuilder: (_, i) {
              final det = entry.detections[i];
              final dc = _matterTypeColor(det.matterType);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: dc.withValues(alpha: 0.06),
                  border: Border.all(color: dc.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                        color: dc.withValues(alpha: 0.2),
                        border: Border.all(color: dc),
                        borderRadius: BorderRadius.circular(3)),
                    child: Center(child: Text(
                      det.elementHint.split(' ').first,
                      style: TextStyle(color: dc, fontSize: 9, fontWeight: FontWeight.bold),
                    )),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(det.elementHint,
                        style: TextStyle(color: dc, fontSize: 11, fontWeight: FontWeight.bold)),
                    Text(
                      'Depth ${(det.depthMetres*100).toStringAsFixed(0)}cm  •  '
                      '${(det.confidence*100).toInt()}% conf  •  '
                      '${det.matterType.name}',
                      style: const TextStyle(
                          color: FalconColors.darkOnSurfaceVariant, fontSize: 9),
                    ),
                  ])),
                  Text('${det.massEstimateG < 1000 ? '${det.massEstimateG.toStringAsFixed(0)}g' : '${(det.massEstimateG/1000).toStringAsFixed(1)}kg'}',
                      style: TextStyle(color: dc, fontSize: 10, fontWeight: FontWeight.bold)),
                ]),
              );
            },
          )),
        ]),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      border: Border.all(color: color.withValues(alpha: 0.4)),
      borderRadius: BorderRadius.circular(2),
    ),
    child: Text(text,
        style: TextStyle(
            color: color, fontSize: 8, fontWeight: FontWeight.bold)),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  3D MATTER PAINTER
// ═══════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════
//  3D MATTER PAINTER — Isometric / Top-Down / Cross-Section
// ═══════════════════════════════════════════════════════════════════════════
class _Matter3DPainter extends CustomPainter {
  final List<DetectedMatter> detections;
  final List<_DetCluster> clusters;
  final double time;
  final int scanDepthCm;
  final Color primaryColor;
  final double magnetometerCurrent;
  final double magnetometerBaseline;
  final int? selectedClusterIdx;
  final double orbitAngle;
  final double pitchAngle;
  final _ViewMode viewMode;
  final bool showStrata;
  final bool showClusters;

  _Matter3DPainter({
    required this.detections,
    required this.clusters,
    required this.time,
    required this.scanDepthCm,
    required this.primaryColor,
    required this.magnetometerCurrent,
    required this.magnetometerBaseline,
    this.selectedClusterIdx,
    required this.orbitAngle,
    required this.pitchAngle,
    required this.viewMode,
    required this.showStrata,
    required this.showClusters,
  });

  // ── coordinate transform ────────────────────────────────────────────────
  Offset _project(double wx, double wy, double wz, Size sz) {
    final cx = sz.width / 2;
    final groundY = sz.height * 0.18;
    final sceneH = sz.height - groundY - 20;
    final maxD = scanDepthCm / 100.0;
    switch (viewMode) {
      case _ViewMode.topDown:
        // looking straight down; x=horizontal, z=horizontal, depth fades to background
        return Offset(
          cx + wx * sz.width * 0.09,
          sz.height * 0.5 + wz * sz.height * 0.09,
        );
      case _ViewMode.crossSection:
        // front-slice: x=horizontal, depth=vertical
        return Offset(
          cx + wx * sz.width * 0.1,
          groundY + (wy / maxD).clamp(0, 1) * sceneH,
        );
      case _ViewMode.isometric:
      default:
        final cosA = math.cos(orbitAngle);
        final sinA = math.sin(orbitAngle);
        final rx = wx * cosA - wz * sinA;
        final rz = wx * sinA + wz * cosA;
        return Offset(
          cx + rx * sz.width * 0.095,
          groundY +
              (wy / maxD).clamp(0, 1) * sceneH * pitchAngle +
              rz * sz.height * 0.04 * (1 - pitchAngle * 0.5),
        );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF020808));

    final groundY = size.height * 0.18;
    final sceneH = size.height - groundY - 20;
    final maxD = scanDepthCm / 100.0;

    // ── Sky gradient ──────────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, groundY),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF000408), Color(0xFF020C08)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, groundY)),
    );

    // ── Soil strata ───────────────────────────────────────────────────────
    if (showStrata && viewMode != _ViewMode.topDown) {
      for (final stratum in _kStrata) {
        final y0 = groundY +
            (stratum.fromCm / scanDepthCm).clamp(0, 1) * sceneH;
        final y1 = groundY +
            (stratum.toCm.clamp(0, scanDepthCm.toDouble()) / scanDepthCm)
                .clamp(0, 1) *
                sceneH;
        if (y1 <= y0) continue;
        canvas.drawRect(
          Rect.fromLTWH(0, y0, size.width, y1 - y0),
          Paint()..color = stratum.color.withValues(alpha: 0.18),
        );
        // Stratum label (left edge)
        _txt(canvas, stratum.name, 6, y0 + 3,
            stratum.color.withValues(alpha: 0.55), 7.5);
        // Dashed boundary line
        _dashedHLine(canvas, y0, size.width,
            stratum.color.withValues(alpha: 0.22));
      }
    }

    // ── Subsurface grid ───────────────────────────────────────────────────
    if (viewMode != _ViewMode.topDown) {
      final gp = Paint()
        ..color = primaryColor.withValues(alpha: 0.04)
        ..strokeWidth = 0.3;
      for (int i = 1; i <= 5; i++) {
        final y = groundY + i * sceneH / 6;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
      }
      for (int i = 1; i <= 8; i++) {
        final x = i * size.width / 9;
        canvas.drawLine(Offset(x, groundY), Offset(x, size.height), gp);
      }
    } else {
      // Top-down: draw concentric rings
      final gp = Paint()
        ..color = primaryColor.withValues(alpha: 0.06)
        ..strokeWidth = 0.4
        ..style = PaintingStyle.stroke;
      final cx = size.width / 2;
      final cy = size.height / 2;
      for (int r = 1; r <= 5; r++) {
        canvas.drawCircle(Offset(cx, cy), r * size.width * 0.1, gp);
      }
      // N/S/E/W cross
      canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), gp);
      canvas.drawLine(Offset(0, cy), Offset(size.width, cy), gp);
    }

    // ── Ground surface line ───────────────────────────────────────────────
    if (viewMode != _ViewMode.topDown) {
      canvas.drawLine(
        Offset(0, groundY),
        Offset(size.width, groundY),
        Paint()
          ..color = primaryColor.withValues(alpha: 0.45)
          ..strokeWidth = 1.5,
      );
      _txt(canvas, 'SURFACE ▼', 8, groundY - 14,
          primaryColor.withValues(alpha: 0.5), 8.5);
    }

    // ── Depth scale ───────────────────────────────────────────────────────
    if (viewMode != _ViewMode.topDown) {
      for (int d = 0; d <= 5; d++) {
        final depthCm = d * scanDepthCm ~/ 5;
        final y = groundY + d * sceneH / 5;
        _txt(canvas, '${depthCm}cm', size.width - 36, y + 2,
            FalconColors.darkOnSurfaceVariant, 7.5);
        canvas.drawLine(
          Offset(size.width - 42, y),
          Offset(size.width - 38, y),
          Paint()
            ..color = FalconColors.darkOnSurfaceVariant.withValues(alpha: 0.25)
            ..strokeWidth = 0.5,
        );
      }
    }

    // ── Scan sweep ────────────────────────────────────────────────────────
    if (viewMode != _ViewMode.topDown) {
      final sweep = (time * 0.3) % 1.0;
      final sweepY = groundY + sweep * sceneH;
      canvas.drawRect(
        Rect.fromLTWH(0, sweepY, size.width, 2),
        Paint()
          ..color = primaryColor.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    } else {
      // Rotating sweep for top-down
      final sweepA = time * 0.6;
      final cx = size.width / 2;
      final cy = size.height / 2;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + math.cos(sweepA) * size.width * 0.5,
            cy + math.sin(sweepA) * size.height * 0.5),
        Paint()
          ..color = primaryColor.withValues(alpha: 0.18)
          ..strokeWidth = 1.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // ── Phone indicator (iso/cross only) ─────────────────────────────────
    if (viewMode != _ViewMode.topDown) {
      final cx = size.width / 2;
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset(cx, groundY - 18), width: 10, height: 18),
        Paint()
          ..color = primaryColor.withValues(alpha: 0.6)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
      canvas.drawCircle(Offset(cx, groundY - 18), 2,
          Paint()..color = primaryColor.withValues(alpha: 0.4));
      canvas.drawPath(
        Path()
          ..moveTo(cx, groundY)
          ..lineTo(cx - size.width * 0.42, size.height)
          ..lineTo(cx + size.width * 0.42, size.height)
          ..close(),
        Paint()..color = primaryColor.withValues(alpha: 0.03),
      );
    }

    // ── Magnetometer bar ──────────────────────────────────────────────────
    const bx = 10.0;
    final by = size.height - 20;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, 64, 6), const Radius.circular(2)),
        Paint()..color = const Color(0xFF1A1A1A));
    final fill =
        ((magnetometerCurrent - magnetometerBaseline + 20) / 40).clamp(0.0, 1.0);
    final barColor = fill > 0.6
        ? const Color(0xFFFF3333)
        : fill > 0.3
            ? const Color(0xFFFFD700)
            : const Color(0xFF00FF66);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, by, 64 * fill, 6), const Radius.circular(2)),
        Paint()..color = barColor);
    _txt(canvas, 'MAG Δ', bx, by - 11, FalconColors.darkOnSurfaceVariant, 7);

    // ── View mode label ───────────────────────────────────────────────────
    final modeLabel = switch (viewMode) {
      _ViewMode.isometric    => 'ISO ${(orbitAngle * 57.3).toStringAsFixed(0)}°',
      _ViewMode.crossSection => 'CROSS-SECTION',
      _ViewMode.topDown      => 'TOP-DOWN',
    };
    _txt(canvas, modeLabel, size.width - 80, 8, primaryColor.withValues(alpha: 0.4), 8);

    if (detections.isEmpty) return;

    // ── Draw detections / clusters ────────────────────────────────────────
    final pulse = 0.7 + 0.3 * math.sin(time * 2);
    final rng = math.Random(42);
    final items = showClusters ? clusters : clusters; // always clusters list

    for (int i = 0; i < items.length; i++) {
      final cluster = items[i];
      final color = _matterTypeColor(cluster.dominantType);
      final isSelected = i == selectedClusterIdx;

      final sp = _project(cluster.cx, cluster.cy, cluster.cz, size);

      // Volume-based radius (sum of members)
      final totalVol =
          cluster.members.fold(0.0, (s, d) => s + d.volumeEstimateCm3);
      final baseR = 5.0 + totalVol * (showClusters ? 2.5 : 1.8);
      final radius = (baseR * pulse * cluster.avgConfidence).clamp(3.0, 28.0);

      // ── Depth-connection line to surface ───────────────────────────────
      if (viewMode != _ViewMode.topDown) {
        final surfPt = _project(cluster.cx, 0, cluster.cz, size);
        canvas.drawLine(
          surfPt,
          Offset(sp.dx, sp.dy - radius),
          Paint()
            ..color = color.withValues(alpha: 0.10)
            ..strokeWidth = 0.6
            ..style = PaintingStyle.stroke,
        );
      }

      // ── Selection ring ─────────────────────────────────────────────────
      if (isSelected) {
        canvas.drawCircle(
          sp,
          radius * 3.2,
          Paint()
            ..color = color.withValues(alpha: 0.15)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
        );
        canvas.drawCircle(
          sp,
          radius * 2,
          Paint()
            ..color = color.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }

      // ── Outer glow ────────────────────────────────────────────────────
      canvas.drawCircle(
        sp,
        radius * 2.4,
        Paint()
          ..color = color.withValues(alpha: 0.07 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );

      // ── Orbital ring (cluster) ─────────────────────────────────────────
      canvas.drawCircle(
        sp,
        radius * 1.5,
        Paint()
          ..color = color.withValues(alpha: 0.18 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      // ── Core blob ─────────────────────────────────────────────────────
      canvas.drawCircle(
        sp,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.75 * pulse),
              color.withValues(alpha: 0.2 * pulse),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(
              Rect.fromCircle(center: sp, radius: radius)),
      );

      // ── Scatter points ────────────────────────────────────────────────
      final pts = (4 + cluster.avgConfidence * 9 + cluster.members.length * 2)
          .round()
          .clamp(4, 22);
      for (int j = 0; j < pts; j++) {
        final ox = (rng.nextDouble() - 0.5) * radius * 2.2;
        final oy = (rng.nextDouble() - 0.5) * radius * 2.2;
        canvas.drawCircle(
          Offset(sp.dx + ox, sp.dy + oy),
          0.5 + rng.nextDouble() * 1.5,
          Paint()
            ..color = color.withValues(
                alpha: 0.28 * pulse * cluster.avgConfidence),
        );
      }

      // ── Multi-member indicator ring ───────────────────────────────────
      if (cluster.members.length > 1) {
        canvas.drawCircle(
          sp,
          radius * 1.85,
          Paint()
            ..color = color.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }

      // ── Labels ────────────────────────────────────────────────────────
      final label = cluster.members.length > 1
          ? '${cluster.members.length}×${cluster.dominantType.name.substring(0, 2).toUpperCase()}'
          : cluster.members.first.elementHint;
      _txt(canvas, label, sp.dx - 10, sp.dy - radius - 14,
          Colors.white, 10, bold: true, shadow: color);

      final massLabel = cluster.totalMassG < 1000
          ? '${cluster.totalMassG.toStringAsFixed(0)}g'
          : '${(cluster.totalMassG / 1000).toStringAsFixed(1)}kg';
      _txt(canvas, massLabel, sp.dx - 8, sp.dy + radius + 4,
          color.withValues(alpha: 0.75), 8);

      if (viewMode != _ViewMode.topDown) {
        _txt(canvas, '${(cluster.cy * 100).toStringAsFixed(0)}cm',
            sp.dx + radius + 4, sp.dy - 4,
            FalconColors.darkOnSurfaceVariant, 7);
      }
    }
  }

  void _dashedHLine(Canvas canvas, double y, double width, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    const dashW = 8.0, gap = 6.0;
    double x = 0;
    while (x < width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashW, y), paint);
      x += dashW + gap;
    }
  }

  void _txt(Canvas canvas, String text, double x, double y, Color color,
      double fontSize, {bool bold = false, Color? shadow}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: 'monospace',
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          shadows: shadow != null ? [Shadow(color: shadow, blurRadius: 6)] : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(_Matter3DPainter old) =>
      old.time != time ||
      old.clusters.length != clusters.length ||
      old.magnetometerCurrent != magnetometerCurrent ||
      old.primaryColor != primaryColor ||
      old.selectedClusterIdx != selectedClusterIdx ||
      old.orbitAngle != orbitAngle ||
      old.pitchAngle != pitchAngle ||
      old.viewMode != viewMode ||
      old.showStrata != showStrata ||
      old.showClusters != showClusters;
}

// ═══════════════════════════════════════════════════════════════════════════
//  CROSS-SECTION PAINTER — side view: X horizontal, depth vertical
// ═══════════════════════════════════════════════════════════════════════════
class _CrossSectionPainter extends CustomPainter {
  final List<_DetCluster> clusters;
  final int scanDepthCm;
  final Color primaryColor;
  final double time;

  const _CrossSectionPainter({
    required this.clusters,
    required this.scanDepthCm,
    required this.primaryColor,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF010606));

    final topY = 20.0;
    final botY = size.height - 16.0;
    final sceneH = botY - topY;

    // Strata strips
    for (final s in _kStrata) {
      final y0 = topY + (s.fromCm / scanDepthCm).clamp(0, 1) * sceneH;
      final y1 = topY +
          (s.toCm.clamp(0, scanDepthCm.toDouble()) / scanDepthCm).clamp(0, 1) *
              sceneH;
      if (y1 <= y0) continue;
      canvas.drawRect(
        Rect.fromLTWH(0, y0, size.width, y1 - y0),
        Paint()..color = s.color.withValues(alpha: 0.22),
      );
      _txt(canvas, s.name, 4, y0 + 2, s.color.withValues(alpha: 0.6), 7);
    }

    // Depth ruler
    for (int d = 0; d <= 4; d++) {
      final depthCm = d * scanDepthCm ~/ 4;
      final y = topY + d * sceneH / 4;
      _txt(canvas, '${depthCm}cm', size.width - 28, y + 1,
          FalconColors.darkOnSurfaceVariant, 6.5);
      canvas.drawLine(
        Offset(size.width - 30, y),
        Offset(size.width - 4, y),
        Paint()
          ..color = FalconColors.darkOnSurfaceVariant.withValues(alpha: 0.18)
          ..strokeWidth = 0.4,
      );
    }

    // Title
    _txt(canvas, 'CROSS-SECTION', 5, 4,
        primaryColor.withValues(alpha: 0.45), 7.5);

    // Detections
    final pulse = 0.7 + 0.3 * math.sin(time * 2);
    for (final c in clusters) {
      final color = _matterTypeColor(c.dominantType);
      final sx = (size.width * 0.5 + c.cx * size.width * 0.12)
          .clamp(8.0, size.width - 8);
      final sy =
          topY + (c.cy / (scanDepthCm / 100.0)).clamp(0, 1) * sceneH;

      // Horizontal stratum zone line
      canvas.drawLine(
        Offset(0, sy),
        Offset(size.width, sy),
        Paint()
          ..color = color.withValues(alpha: 0.08)
          ..strokeWidth = 0.5,
      );

      // Blob
      final r = (4.0 + c.totalMassG / 80.0 * pulse).clamp(3.0, 16.0);
      canvas.drawCircle(
          Offset(sx, sy),
          r * 1.8,
          Paint()
            ..color = color.withValues(alpha: 0.1)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(
          Offset(sx, sy),
          r,
          Paint()
            ..shader = RadialGradient(
              colors: [
                color.withValues(alpha: 0.8 * pulse),
                color.withValues(alpha: 0.1 * pulse),
                Colors.transparent,
              ],
              stops: const [0, 0.5, 1],
            ).createShader(
                Rect.fromCircle(center: Offset(sx, sy), radius: r)));

      // Label
      _txt(canvas,
          c.members.length > 1
              ? '${c.members.length}×'
              : c.members.first.elementHint,
          sx - 6,
          sy - r - 10,
          Colors.white,
          8,
          bold: true);
    }
  }

  void _txt(Canvas canvas, String text, double x, double y, Color color,
      double fontSize, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontFamily: 'monospace',
              fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(_CrossSectionPainter old) =>
      old.time != time || old.clusters.length != clusters.length;
}

class _TypePiePainter extends CustomPainter {
  final Map<MatterType, List<DetectedMatter>> byType;
  final int total;
  const _TypePiePainter({required this.byType, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 8;
    final rInner = r * 0.55;
    double startAngle = -math.pi / 2;
    for (final entry in byType.entries) {
      final sweep = entry.value.length / total * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle, sweep, true,
        Paint()..color = _matterTypeColor(entry.key).withValues(alpha: 0.7),
      );
      canvas.drawCircle(Offset(cx, cy), rInner,
          Paint()..color = const Color(0xFF020808));
      startAngle += sweep;
    }
    final tp = TextPainter(
      text: TextSpan(
        text: '$total\nANOM',
        style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            height: 1.3),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_TypePiePainter old) => old.total != total;
}

// ═══════════════════════════════════════════════════════════════════════════
//  RADAR MAP PAINTER — Top-down relative XZ map with history sessions
// ═══════════════════════════════════════════════════════════════════════════
class _RadarMapPainter extends CustomPainter {
  final List<DetectedMatter> currentDetections;
  final List<_ScanHistoryEntry> history;
  final Color primaryColor;
  final double time;
  final double compassHeading;          // V50.0: real IMU yaw (radians)
  final DetectedMatter? nearestDetection; // V50.0: highlight nearest

  const _RadarMapPainter({
    required this.currentDetections,
    required this.history,
    required this.primaryColor,
    required this.time,
    this.compassHeading = 0.0,
    this.nearestDetection,
  });

  Color _histColor(int idx) {
    const palette = [
      Color(0xFF00FF66), Color(0xFF00CCFF), Color(0xFFFFD700),
      Color(0xFFBB88FF), Color(0xFFFF8A65), Color(0xFF4FC3F7),
    ];
    return palette[idx.clamp(0, palette.length - 1)];
  }

  /// Project world (x,z) → screen (sx,sy) rotating by compass heading
  /// so that the direction the phone faces is always "up" on the radar.
  Offset _project(double wx, double wz, double cx, double cy, double maxR) {
    // Rotate world point by -heading so phone-forward = screen-up
    final cosH = math.cos(-compassHeading);
    final sinH = math.sin(-compassHeading);
    final rx = wx * cosH - wz * sinH;
    final rz = wx * sinH + wz * cosH;
    // 8m world radius = maxR pixels
    final sx = (cx + rx * maxR / 8).clamp(8.0, cx * 2 - 8);
    final sy = (cy + rz * maxR / 8).clamp(8.0, cy * 2 - 8);
    return Offset(sx, sy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = math.min(cx, cy) * 0.88;

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF020A06));

    // Concentric range rings
    for (int r = 1; r <= 4; r++) {
      canvas.drawCircle(
        Offset(cx, cy), maxR * r / 4,
        Paint()
          ..color = primaryColor.withValues(alpha: 0.06)
          ..strokeWidth = 0.6
          ..style = PaintingStyle.stroke,
      );
      final tp = TextPainter(
        text: TextSpan(text: '${r * 2}m',
            style: TextStyle(color: primaryColor.withValues(alpha: 0.25),
                fontSize: 7, fontFamily: 'monospace')),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx + maxR * r / 4 + 2, cy - 8));
    }

    // Cardinal lines rotated by compass so phone-forward = up
    final cp = Paint()..color = primaryColor.withValues(alpha: 0.08)..strokeWidth = 0.4;
    canvas.drawLine(Offset(cx, cy - maxR), Offset(cx, cy + maxR), cp);
    canvas.drawLine(Offset(cx - maxR, cy), Offset(cx + maxR, cy), cp);

    // Compass-north indicator — always points toward true north even as phone rotates
    final northAngle = -compassHeading - math.pi / 2; // north in screen space
    final nxEnd = cx + math.cos(northAngle) * (maxR + 10);
    final nyEnd = cy + math.sin(northAngle) * (maxR + 10);
    canvas.drawLine(Offset(cx, cy), Offset(nxEnd, nyEnd),
        Paint()..color = const Color(0xFFFF3333).withValues(alpha: 0.5)
          ..strokeWidth = 1.0);
    _txt(canvas, 'N', nxEnd - 4, nyEnd - 8, const Color(0xFFFF4444), 9, bold: true);

    // Phone-forward indicator (top = ahead)
    _txt(canvas, '▲', cx - 5, cy - maxR - 18, primaryColor.withValues(alpha: 0.7), 11);

    // Sweep line
    final sweepA = time * 0.5;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + math.cos(sweepA) * maxR, cy + math.sin(sweepA) * maxR),
      Paint()
        ..color = primaryColor.withValues(alpha: 0.22)
        ..strokeWidth = 1.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: maxR * 0.7),
      sweepA - 0.6, 0.6, false,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.07)
        ..strokeWidth = maxR * 0.7
        ..style = PaintingStyle.stroke,
    );

    // Device (centre)
    canvas.drawCircle(Offset(cx, cy), 5, Paint()..color = primaryColor.withValues(alpha: 0.9));
    canvas.drawCircle(Offset(cx, cy), 9,
        Paint()..color = primaryColor.withValues(alpha: 0.3)..strokeWidth = 1.2..style = PaintingStyle.stroke);

    // History sessions
    final pulse = 0.7 + 0.3 * math.sin(time * 2);
    for (int si = history.length - 1; si >= 0; si--) {
      final entry = history[si];
      final hColor = _histColor(si);
      final fade = (1.0 - si * 0.18).clamp(0.15, 1.0);
      for (final det in entry.detections) {
        final wx = det.x + entry.lonOffset * 1000;
        final wz = det.z + entry.latOffset * 1000;
        final pos = _project(wx, wz, cx, cy, maxR);
        final r = (3.0 + det.volumeEstimateCm3 * 0.3).clamp(2.5, 9.0);
        canvas.drawCircle(pos, r * 1.6, Paint()..color = hColor.withValues(alpha: 0.08 * fade));
        canvas.drawCircle(pos, r,
            Paint()..shader = RadialGradient(colors: [
              hColor.withValues(alpha: 0.7 * fade),
              hColor.withValues(alpha: 0.1 * fade),
              Colors.transparent,
            ], stops: const [0, 0.5, 1])
                .createShader(Rect.fromCircle(center: pos, radius: r)));
      }
    }

    // Current scan detections
    for (final det in currentDetections) {
      final color = _matterTypeColor(det.matterType);
      final pos = _project(det.x, det.z, cx, cy, maxR);
      final r = (4.0 + det.volumeEstimateCm3 * 0.4 * pulse).clamp(3.5, 12.0);
      final isNearest = nearestDetection != null &&
          det.elementHint == nearestDetection!.elementHint;

      // Glow
      canvas.drawCircle(pos, r * 2.5,
          Paint()..color = color.withValues(alpha: 0.12 * pulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      // Ring — extra ring if nearest
      if (isNearest) {
        canvas.drawCircle(pos, r * 2.2,
            Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.35 * pulse)
              ..strokeWidth = 1.2..style = PaintingStyle.stroke);
      }
      canvas.drawCircle(pos, r * 1.5,
          Paint()..color = color.withValues(alpha: 0.25 * pulse)
            ..strokeWidth = 0.8..style = PaintingStyle.stroke);
      // Core
      canvas.drawCircle(pos, r,
          Paint()..shader = RadialGradient(colors: [
            color.withValues(alpha: 0.85 * pulse),
            color.withValues(alpha: 0.2 * pulse),
            Colors.transparent,
          ], stops: const [0, 0.5, 1])
              .createShader(Rect.fromCircle(center: pos, radius: r)));

      // Depth connector
      final depthFrac = (det.depthMetres / 3.0).clamp(0.0, 1.0);
      canvas.drawLine(pos, Offset(pos.dx, pos.dy - 3 - depthFrac * 14),
          Paint()..color = color.withValues(alpha: 0.35)..strokeWidth = 0.8);

      // Label
      _txt(canvas, det.elementHint.split(' ').first,
          pos.dx - 6, pos.dy - r - 12, Colors.white, 8.5, bold: true);

      // V50.0: Arrow from centre toward nearest detection
      if (isNearest) {
        final dx = pos.dx - cx, dy = pos.dy - cy;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len > 14) {
          final ux = dx / len, uy = dy / len;
          canvas.drawLine(
            Offset(cx + ux * 12, cy + uy * 12),
            Offset(cx + ux * (len - 10), cy + uy * (len - 10)),
            Paint()..color = color.withValues(alpha: 0.7 * pulse)
              ..strokeWidth = 1.5..strokeCap = StrokeCap.round,
          );
          // Arrowhead
          final perpX = -uy, perpY = ux;
          final arrowBase = Offset(cx + ux * (len - 10), cy + uy * (len - 10));
          canvas.drawPath(
            Path()
              ..moveTo(cx + ux * len, cy + uy * len)
              ..lineTo(arrowBase.dx + perpX * 4, arrowBase.dy + perpY * 4)
              ..lineTo(arrowBase.dx - perpX * 4, arrowBase.dy - perpY * 4)
              ..close(),
            Paint()..color = color.withValues(alpha: 0.8 * pulse),
          );
        }
      }
    }

    if (currentDetections.isEmpty && history.isEmpty) {
      _txt(canvas, 'No detections yet', cx - 48, cy + 20,
          primaryColor.withValues(alpha: 0.3), 11);
    }
  }

  void _txt(Canvas canvas, String text, double x, double y,
      Color color, double size, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text,
          style: TextStyle(
              color: color, fontSize: size,
              fontFamily: 'monospace',
              fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(_RadarMapPainter old) =>
      old.time != time ||
      old.compassHeading != compassHeading ||
      old.currentDetections.length != currentDetections.length ||
      old.history.length != history.length ||
      old.nearestDetection != nearestDetection;
}

// ═══════════════════════════════════════════════════════════════════════════
//  OSM GPS MAP WIDGET  V50.0
//  Renders an OpenStreetMap tile at the user's real GPS location and plots
//  all detected matter as pinned markers on the real-world map.
//  Uses only geolocator (already in pubspec) + http (already in pubspec).
//  No extra dependencies required.
// ═══════════════════════════════════════════════════════════════════════════
class _OsmMapWidget extends StatefulWidget {
  final List<DetectedMatter> currentDetections;
  final List<_ScanHistoryEntry> history;
  final Color primaryColor;

  const _OsmMapWidget({
    required this.currentDetections,
    required this.history,
    required this.primaryColor,
  });

  @override
  State<_OsmMapWidget> createState() => _OsmMapWidgetState();
}

class _OsmMapWidgetState extends State<_OsmMapWidget> {
  Position? _pos;
  bool _locating = false;
  String? _locError;

  // Tile cache: tileKey → Image widget
  final Map<String, Image?> _tiles = {};

  // Map pan & zoom state — V51.0: zoom is now mutable for pinch-zoom
  double _mapLat = 0, _mapLon = 0;
  int _zoom = 17;               // OSM zoom level (14–19)
  Offset _dragStart = Offset.zero;
  double _panLat = 0, _panLon = 0;  // cumulative pan in degrees

  // Pinch-zoom state
  double _scaleStart = 1.0;
  int _zoomAtScaleStart = 17;

  // Selected detection for info popup
  int? _selectedDetIdx;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    if (_locating) return;
    setState(() { _locating = true; _locError = null; });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        setState(() { _locating = false; _locError = 'Location permission denied'; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      setState(() {
        _pos = pos;
        _mapLat = pos.latitude;
        _mapLon = pos.longitude;
        _panLat = 0; _panLon = 0;
        _locating = false;
      });
    } catch (e) {
      setState(() { _locating = false; _locError = 'GPS: $e'; });
    }
  }

  // Convert lat/lon to OSM tile x/y at zoom
  int _tileX(double lon, int z) =>
      ((lon + 180) / 360 * math.pow(2, z)).floor();
  int _tileY(double lat, int z) {
    final latRad = lat * math.pi / 180;
    return ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
            2 * math.pow(2, z)).floor();
  }

  // OSM tile URL
  String _tileUrl(int x, int y, int z) =>
      'https://tile.openstreetmap.org/$z/$x/$y.png';

  // Convert tile + pixel offset → lat/lon
  double _tileToLat(int y, int z) {
    final n = math.pi - 2 * math.pi * y / math.pow(2, z);
    return 180 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
  }
  double _tileToLon(int x, int z) => x / math.pow(2, z) * 360 - 180;

  // Project a lat/lon to pixel offset relative to centre tile
  Offset _latLonToPixel(double lat, double lon, int tx, int ty,
      double tileSize, Size canvasSize) {
    final xTile = (lon + 180) / 360 * math.pow(2, _zoom);
    final latRad = lat * math.pi / 180;
    final yTile = (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
        2 * math.pow(2, _zoom);
    final px = (xTile - tx) * tileSize + canvasSize.width / 2 - tileSize / 2;
    final py = (yTile - ty) * tileSize + canvasSize.height / 2 - tileSize / 2;
    return Offset(px, py);
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.primaryColor;

    if (_locating) {
      return Container(
        color: const Color(0xFF050D0A),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: primary)),
          const SizedBox(height: 8),
          Text('Acquiring GPS…',
              style: TextStyle(color: primary, fontSize: 10, letterSpacing: 1)),
        ])),
      );
    }

    if (_locError != null || _pos == null) {
      return Container(
        color: const Color(0xFF050D0A),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.location_off, color: primary.withValues(alpha: 0.5), size: 28),
          const SizedBox(height: 8),
          Text(_locError ?? 'No GPS fix',
              style: TextStyle(color: FalconColors.darkOnSurfaceVariant, fontSize: 10),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _getLocation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: primary.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('RETRY', style: TextStyle(color: primary, fontSize: 10,
                  fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ])),
      );
    }

    final viewLat = _mapLat + _panLat;
    final viewLon = _mapLon + _panLon;
    final centreTX = _tileX(viewLon, _zoom);
    final centreTY = _tileY(viewLat, _zoom);

    return GestureDetector(
      onScaleStart: (d) {
        _dragStart = d.focalPoint;
        _scaleStart = 1.0;
        _zoomAtScaleStart = _zoom;
        setState(() => _selectedDetIdx = null);
      },
      onScaleUpdate: (d) {
        // Pan
        final degPerPx = 360.0 / (math.pow(2, _zoom) * 256);
        final delta = d.focalPoint - _dragStart;
        _dragStart = d.focalPoint;
        // Zoom via pinch
        if (d.scale != 1.0) {
          final newZoom = (_zoomAtScaleStart + math.log(d.scale) / math.log(2))
              .round().clamp(12, 19);
          if (newZoom != _zoom) {
            setState(() {
              _zoom = newZoom;
              _tiles.clear(); // invalidate tile cache on zoom change
            });
          }
        }
        setState(() {
          _panLon -= delta.dx * degPerPx;
          _panLat += delta.dy * degPerPx;
        });
      },
      child: LayoutBuilder(builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        const tileSize = 256.0;

        return ClipRect(
          child: Stack(children: [
            // Dark background while tiles load
            Container(color: const Color(0xFF0A1A10)),

            // OSM tile grid (3×3 around centre)
            for (int dx = -1; dx <= 1; dx++)
              for (int dy = -1; dy <= 1; dy++)
                Builder(builder: (_) {
                  final tx = centreTX + dx;
                  final ty = centreTY + dy;
                  final tileLon = _tileToLon(tx, _zoom);
                  final tileLat = _tileToLat(ty, _zoom);
                  final pixPos = _latLonToPixel(
                      tileLat, tileLon, centreTX, centreTY, tileSize,
                      Size(w, h));

                  // Build/cache tile image
                  final key = '$_zoom/$tx/$ty';
                  if (!_tiles.containsKey(key)) {
                    _tiles[key] = null;
                    // Trigger image load via Image.network
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() {
                        _tiles[key] = Image.network(
                          _tileUrl(tx, ty, _zoom),
                          headers: const {'User-Agent': 'FalconEye/50.0'},
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        );
                      });
                    });
                  }

                  return Positioned(
                    left: pixPos.dx,
                    top: pixPos.dy,
                    width: tileSize, height: tileSize,
                    child: ColorFiltered(
                      // Dark map tint to match app theme
                      colorFilter: const ColorFilter.matrix([
                        -0.8,  0,    0,    0, 200,
                         0,   -0.8,  0,    0, 200,
                         0,    0,   -0.8,  0, 200,
                         0,    0,    0,    1,   0,
                      ]),
                      child: _tiles[key] ?? Container(color: const Color(0xFF111A13)),
                    ),
                  );
                }),

            // Device position dot
            Builder(builder: (_) {
              final centre = Offset(w / 2, h / 2);
              return Positioned(
                left: centre.dx - 6, top: centre.dy - 6,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary,
                    boxShadow: [BoxShadow(color: primary, blurRadius: 8)],
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              );
            }),

            // Current detection markers — V51.0: tappable with detail popup
            for (int di = 0; di < widget.currentDetections.length; di++)
              Builder(builder: (_) {
                final det = widget.currentDetections[di];
                // Each detection has x/z in metres relative to device
                // Convert to lat/lon using 1° ≈ 111km approximation
                final detLat = viewLat + det.z / 111000;
                final detLon = viewLon + det.x /
                    (111000 * math.cos(viewLat * math.pi / 180));
                final pos = _latLonToPixel(detLat, detLon,
                    centreTX, centreTY, tileSize, Size(w, h));
                final detColor = _matterTypeColor(det.matterType);
                final isSelected = _selectedDetIdx == di;
                return Positioned(
                  left: pos.dx - 20, top: pos.dy - 55,
                  child: GestureDetector(
                    onTap: () => setState(() =>
                        _selectedDetIdx = isSelected ? null : di),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      // Expanded popup on tap
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.92),
                            border: Border.all(color: detColor, width: 1.5),
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: [BoxShadow(color: detColor.withValues(alpha: 0.4), blurRadius: 8)],
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(det.elementHint,
                                style: TextStyle(color: detColor, fontSize: 9, fontWeight: FontWeight.bold)),
                            Text(
                              'Depth ${(det.depthMetres * 100).toStringAsFixed(0)}cm',
                              style: const TextStyle(color: Colors.white70, fontSize: 8),
                            ),
                            Text(
                              'Conf ${(det.confidence * 100).toInt()}%  •  ${det.matterType.name}',
                              style: const TextStyle(color: Colors.white54, fontSize: 8),
                            ),
                            Text(
                              det.massEstimateG < 1000
                                  ? '~${det.massEstimateG.toStringAsFixed(0)}g'
                                  : '~${(det.massEstimateG / 1000).toStringAsFixed(1)}kg',
                              style: TextStyle(color: detColor, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ]),
                        ),
                      // Label bubble
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? detColor.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.85),
                          border: Border.all(color: detColor.withValues(alpha: isSelected ? 1.0 : 0.7),
                              width: isSelected ? 1.5 : 1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(det.elementHint.split(' ').first,
                            style: TextStyle(color: detColor, fontSize: 7,
                                fontWeight: FontWeight.bold)),
                      ),
                      // Pin stem
                      Container(width: 1.5, height: 6, color: detColor),
                      // Pin head
                      Container(width: isSelected ? 11 : 8, height: isSelected ? 11 : 8,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: detColor,
                              boxShadow: [BoxShadow(color: detColor, blurRadius: isSelected ? 8 : 4)])),
                    ]),
                  ),
                );
              }),

            // History detection markers (faded)
            for (int si = 0; si < widget.history.length; si++)
              for (final det in widget.history[si].detections)
                Builder(builder: (_) {
                  final entry = widget.history[si];
                  final detLat = viewLat + (det.z + entry.latOffset * 1000) / 111000;
                  final detLon = viewLon + (det.x + entry.lonOffset * 1000) /
                      (111000 * math.cos(viewLat * math.pi / 180));
                  final pos = _latLonToPixel(detLat, detLon,
                      centreTX, centreTY, tileSize, Size(w, h));
                  final hColor = _historyColor2(si);
                  final fade = (1.0 - si * 0.2).clamp(0.2, 0.7);
                  return Positioned(
                    left: pos.dx - 4, top: pos.dy - 4,
                    child: Container(width: 8, height: 8,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hColor.withValues(alpha: fade),
                            border: Border.all(
                                color: hColor.withValues(alpha: fade), width: 1))),
                  );
                }),

            // GPS accuracy ring
            Positioned(
              left: w / 2 - 22, top: h / 2 - 22,
              child: Container(width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: primary.withValues(alpha: 0.25), width: 1),
                  )),
            ),

            // Attribution (OSM requires it)
            Positioned(
              bottom: 2, right: 4,
              child: Text('© OpenStreetMap contributors',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35), fontSize: 6)),
            ),

            // Recenter + GPS button + Zoom controls — V51.0
            Positioned(
              top: 4, right: 4,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: _getLocation,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      border: Border.all(color: primary.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.my_location, color: primary, size: 14),
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    if (_zoom < 19) setState(() { _zoom++; _tiles.clear(); });
                  },
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      border: Border.all(color: primary.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.add, color: primary, size: 16),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 28, height: 20,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    border: Border.all(color: primary.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Center(child: Text('$_zoom',
                      style: TextStyle(color: primary, fontSize: 8, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () {
                    if (_zoom > 12) setState(() { _zoom--; _tiles.clear(); });
                  },
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      border: Border.all(color: primary.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.remove, color: primary, size: 16),
                  ),
                ),
              ]),
            ),

            // Detection count badge
            if (widget.currentDetections.isNotEmpty)
              Positioned(
                top: 4, left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    border: Border.all(color: primary.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text('${widget.currentDetections.length} detections',
                      style: TextStyle(color: primary, fontSize: 8,
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ]),
        );
      }),
    );
  }

  Color _historyColor2(int si) {
    const p = [
      Color(0xFF00FF66), Color(0xFF00CCFF), Color(0xFFFFD700),
      Color(0xFFBB88FF), Color(0xFFFF8A65),
    ];
    return p[si.clamp(0, p.length - 1)];
  }

  Color _matterTypeColor(MatterType type) {
    switch (type) {
      case MatterType.ferrousMetal:    return const Color(0xFFE65100);
      case MatterType.nonFerrousMetal: return const Color(0xFFB87333);
      case MatterType.preciousMetal:   return const Color(0xFFFFD700);
      case MatterType.alloy:           return const Color(0xFF90A4AE);
      case MatterType.mineral:         return const Color(0xFF9C27B0);
      case MatterType.water:           return const Color(0xFF2196F3);
      case MatterType.organic:         return const Color(0xFF4CAF50);
      default:                         return const Color(0xFF757575);
    }
  }
}
