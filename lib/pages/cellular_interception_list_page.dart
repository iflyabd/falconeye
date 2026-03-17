import 'dart:async';
import 'dart:io'; // For Process if needed, but using root_plus
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fl_chart/fl_chart.dart';
// ignore: depend_on_referenced_packages
// import 'package:root_plus/root_plus.dart'; // Add to pubspec.yaml: root_plus: ^1.0.9
// Assuming 'theme.dart' and 'back_button_top_left.dart' are in your project
// import 'package:dreamflow/theme.dart';
// import 'package:dreamflow/widgets/back_button_top_left.dart';

// Local helpers to replace root_plus
Future<String?> _execTelephonyDump() async {
  if (!Platform.isAndroid) return null;
  try {
    final result = await Process.run('sh', ['-c', 'dumpsys telephony.registry']);
    if (result.exitCode == 0 && (result.stdout is String) && (result.stdout as String).isNotEmpty) {
      return result.stdout as String;
    }
  } catch (_) {
    // Ignore and fall back
  }
  return null;
}

Future<bool> isRootAvailable() async {
  if (!Platform.isAndroid) return false;
  try {
    final res = await Process.run('sh', ['-c', 'which su']);
    return res.exitCode == 0 && (res.stdout as String).toString().trim().isNotEmpty;
  } catch (_) {
    return false;
  }
}

// Placeholder constants (replace with your theme)
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
}

class AppRadius {
  static const double full = 9999.0; // Circular
}

class InterceptionCard extends StatelessWidget {
  final bool supported;
  final bool active;
  final String protocol;
  final String timestamp;
  final String sideA;
  final String sideB;
  final String dbm;
  final String location;

  const InterceptionCard({
    super.key,
    required this.supported,
    required this.active,
    required this.protocol,
    required this.timestamp,
    required this.sideA,
    required this.sideB,
    required this.dbm,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: supported ? 1.0 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? theme.colorScheme.primary : theme.colorScheme.secondary,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      protocol,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  timestamp,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("ORIGIN", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary)),
                      Text(
                        sideA,
                        style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.swap_horiz, color: theme.colorScheme.primary, size: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("TARGET", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary)),
                      Text(
                        sideB,
                        style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(color: theme.colorScheme.outline.withValues(alpha: 0.3), thickness: 0.5),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.signal_cellular_alt, size: 14, color: theme.colorScheme.secondary),
                    const SizedBox(width: AppSpacing.xs),
                    Text("$dbm dBm", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.secondary)),
                    const SizedBox(width: AppSpacing.md),
                    Icon(Icons.pin_drop, size: 14, color: theme.colorScheme.secondary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(location, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.secondary)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: active ? theme.colorScheme.primary : Colors.transparent,
                    border: Border.all(color: active ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    active ? "LIVE STREAM" : "DECRYPTED",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: active ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StatPill extends StatelessWidget {
  final String label;
  final String value;

  const StatPill({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary)),
            Text(value, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

// Model for interception data
class Interception {
  final bool supported;
  final bool active;
  final String protocol;
  final String timestamp;
  final String sideA;
  final String sideB;
  final String dbm;
  final String location;

  Interception({
    required this.supported,
    required this.active,
    required this.protocol,
    required this.timestamp,
    required this.sideA,
    required this.sideB,
    required this.dbm,
    required this.location,
  });
}

// Function to parse dumpsys output
Future<Map<String, dynamic>> parseTelephonyDump() async {
  try {
    // Execute shell command (non-root fallback). Root not required, best-effort.
    final result = await _execTelephonyDump();
    if (result == null || result.isEmpty) {
      throw Exception('No output from dumpsys');
    }

    final lines = result.split('\n');
    String signalStrength = '-100'; // Default
    String serviceState = 'UNKNOWN';
    List<Interception> interceptions = [];
    int activeLinks = 0;
    int totalCaptured = 0;
    String threatLevel = 'LOW';

    // Parse signal strength (example: look for mSignalStrength line)
    final signalRegex = RegExp(r'mSignalStrength=SignalStrength:\s*(.+)', multiLine: true);
    final signalMatch = signalRegex.firstMatch(result);
    if (signalMatch != null) {
      final signalParts = signalMatch.group(1)!.trim().split(' ');
      // Extract relevant dBm: for GSM/UMTS, often signalParts[0] is ASU, dBm = -113 + 2*ASU
      // For LTE, look for RSRP (e.g., index 8 or -93 in example)
      // Prioritize 3G/2G: assume GSM is signalParts[0]
      int asu = int.tryParse(signalParts[0]) ?? 99;
      if (asu != 99) { // 99 is invalid
        signalStrength = (-113 + 2 * asu).toString();
      } else if (signalParts.length > 8) {
        signalStrength = signalParts[8]; // Example RSRP
      }
    }

    // Parse service state for protocol (e.g., HSDPA for 3G, GSM for 2G)
    final serviceRegex = RegExp(r'mServiceState=\d+\s+.+?\s+(\w+:\d+)', multiLine: true);
    final serviceMatch = serviceRegex.firstMatch(result);
    if (serviceMatch != null) {
      serviceState = serviceMatch.group(1) ?? 'UNKNOWN';
      // Map to protocol: HSDPA:9 -> 3G UMTS, GSM -> 2G, etc.
    }

    // Parse cell info (mCellInfo=[CellInfoLte: {...}, ...])
    final cellInfoRegex = RegExp(r'mCellInfo=\[(.+?)\]', dotAll: true);
    final cellMatch = cellInfoRegex.firstMatch(result);
    if (cellMatch != null) {
      final cellsStr = cellMatch.group(1)!;
      // Simple split by CellInfo type
      final cellList = cellsStr.split(RegExp(r'(?=CellInfo)'));
      totalCaptured = cellList.length;
      for (var cell in cellList) {
        if (cell.trim().isEmpty) continue;

        // Extract type: CellInfoWcdma for 3G, CellInfoGsm for 2G
        String protocol = 'UNKNOWN';
        if (cell.contains('CellInfoWcdma')) {
          protocol = '3G WCDMA';
        } else if (cell.contains('CellInfoGsm')) {
          protocol = '2G GSM';
        } else if (cell.contains('CellInfoCdma')) {
          protocol = '2G CDMA';
        } else if (cell.contains('CellInfoTdscdma')) {
          protocol = '3G TDSCDMA';
        } // Ignore others for priority 3G/2G

        if (protocol == 'UNKNOWN') continue;

        // Extract dBm
        final dbmRegex = RegExp(r'dbm=(\-\d+)');
        final dbmMatch = dbmRegex.firstMatch(cell);
        String dbm = dbmMatch?.group(1) ?? '-100';

        // Extract location (e.g., lac=)
        final lacRegex = RegExp(r'lac=(\d+)');
        final lacMatch = lacRegex.firstMatch(cell);
        String location = 'Sector ${lacMatch?.group(1) ?? 'Unknown'}';

        // Active: if registered=true or connectionStatus=primary
        bool active = cell.contains('registered=true') || cell.contains('ConnectionStatus=PRIMARY_SERVING');

        // SideA/B: Device to Cell CID
        final cidRegex = RegExp(r'cid=(\d+)');
        final cidMatch = cidRegex.firstMatch(cell);
        String sideB = 'Cell ${cidMatch?.group(1) ?? 'Unknown'}';

        interceptions.add(Interception(
          supported: true,
          active: active,
          protocol: protocol,
          timestamp: DateTime.now().toString().substring(11, 19),
          sideA: 'Device',
          sideB: sideB,
          dbm: dbm,
          location: location,
        ));

        if (active) activeLinks++;
      }

      // Sort to prioritize 3G over 2G
      interceptions.sort((a, b) {
        int score(String p) => p.startsWith('3G') ? 0 : 1;
        return score(a.protocol) - score(b.protocol);
      });

      // Threat level based on signal
      int dbmInt = int.tryParse(signalStrength) ?? -100;
      threatLevel = dbmInt > -80 ? 'LOW' : (dbmInt > -100 ? 'MEDIUM' : 'HIGH');
    }

    return {
      'interceptions': interceptions,
      'stats': {
        'activeLinks': activeLinks.toString().padLeft(2, '0'),
        'totalCaptured': totalCaptured.toString().padLeft(4, '0'),
        'threatLevel': threatLevel,
      },
      'signal': double.tryParse(signalStrength) ?? -100.0,
    };
  } catch (e) {
    // Fallback or error
    return {
      'interceptions': [],
      'stats': {'activeLinks': '00', 'totalCaptured': '0000', 'threatLevel': 'HIGH'},
      'signal': -100.0,
    };
  }
}

// Provider for telephony data (from rooted dump)
final telephonyDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return await parseTelephonyDump();
});

// Provider for chart data (signal history)
final chartDataProvider = StateProvider<List<double>>((ref) => List.filled(10, 50.0));

// Timer to update data periodically
void startUpdater(WidgetRef ref) {
  Timer.periodic(const Duration(seconds: 5), (_) async {
    final data = await parseTelephonyDump();
    // Refresh async provider
    ref.invalidate(telephonyDataProvider);

    final signal = data['signal'] as double;
    final currentChart = ref.read(chartDataProvider);
    final newChart = [...currentChart..removeAt(0), signal.abs().clamp(0, 100).toDouble()]; // Normalize to 0-100 for chart
    ref.read(chartDataProvider.notifier).state = newChart;
  });
}

class CellularInterceptionListPage extends ConsumerStatefulWidget {
  const CellularInterceptionListPage({super.key});

  @override
  ConsumerState<CellularInterceptionListPage> createState() => _CellularInterceptionListPageState();
}

class _CellularInterceptionListPageState extends ConsumerState<CellularInterceptionListPage> {
  @override
  void initState() {
    super.initState();
    _checkRoot();
    startUpdater(ref);
  }

  Future<void> _checkRoot() async {
    final isRooted = await isRootAvailable();
    if (!isRooted) {
      // Show warning or fallback
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device not rooted! Using fallback data.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chartData = ref.watch(chartDataProvider);
    final dataAsync = ref.watch(telephonyDataProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(telephonyDataProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3), width: 2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "SIGINT INTERCEPT",
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                "FALCON EYE // CELLULAR UPLINK MONITOR",
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                            ),
                            child: Center(
                              child: Icon(Icons.sensors, color: theme.colorScheme.onSurface, size: 24),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Spectrum Density Chart
                    Container(
                      height: 120,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3))),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("SPECTRUM DENSITY (GHz)", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary)),
                              Text("LIVE SCANNING", style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Expanded(
                            child: LineChart(
                              LineChartData(
                                gridData: const FlGridData(show: false),
                                titlesData: const FlTitlesData(show: false),
                                borderData: FlBorderData(show: false),
                                minX: 0,
                                maxX: chartData.length - 1,
                                minY: 0,
                                maxY: 100,
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: chartData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                                    isCurved: true,
                                    color: theme.colorScheme.primary,
                                    barWidth: 2,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Stats Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      child: dataAsync.when(
                        data: (data) {
                          final stats = data['stats'] as Map<String, String>;
                          return Row(
                            children: [
                              StatPill(label: "ACTIVE LINKS", value: stats['activeLinks'] ?? '00'),
                              const SizedBox(width: AppSpacing.md),
                              StatPill(label: "TOTAL CAPTURED", value: stats['totalCaptured'] ?? '0000'),
                              const SizedBox(width: AppSpacing.md),
                              StatPill(label: "THREAT LEVEL", value: stats['threatLevel'] ?? 'LOW'),
                            ],
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const Text('Error loading stats'),
                      ),
                    ),

                    // Interception List Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("INTERCEPTED STREAMS", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface)),
                          Icon(Icons.filter_list, color: theme.colorScheme.onSurface, size: 20),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Interception List
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: dataAsync.when(
                        data: (data) {
                          final interceptions = data['interceptions'] as List<Interception>;
                          return Column(
                            children: interceptions.map((item) => InterceptionCard(
                              supported: item.supported,
                              active: item.active,
                              protocol: item.protocol,
                              timestamp: item.timestamp,
                              sideA: item.sideA,
                              sideB: item.sideB,
                              dbm: item.dbm,
                              location: item.location,
                            )).toList(),
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const Text('Error loading interceptions'),
                      ),
                    ),

                    // Footer Info
                    Container(
                      margin: const EdgeInsets.all(AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.primary),
                        color: Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.security, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              "SOVEREIGN ENCRYPTION ACTIVE. ALL LOGS ARE STORED IN LOCAL VAULT.",
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            // const BackButtonTopLeft(),
          ],
        ),
      ),
    );
  }
}