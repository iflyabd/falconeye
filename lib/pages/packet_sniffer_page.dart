// ═══════════════════════════════════════════════════════════════════════════
// FALCON EYE V48.1 — NETWORK PACKET ANALYSER
// Passive IPv4 UDP/TCP/DNS packet capture using RawDatagramSocket.
// Real IPv4 header parsing: protocol, src, dst, ports.
// Real DNS QNAME decode for port-53 queries.
// Rolling bytes/sec + fl_chart PieChart protocol breakdown.
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/back_button_top_left.dart';

// ── Model ────────────────────────────────────────────────────────────────────
class PacketEntry {
  final DateTime time;
  final String protocol;   // UDP/TCP/ICMP/DNS/OTHER
  final String src;
  final String dst;
  final int srcPort;
  final int dstPort;
  final int size;
  final String? dnsQuery;

  const PacketEntry({
    required this.time,
    required this.protocol,
    required this.src,
    required this.dst,
    required this.srcPort,
    required this.dstPort,
    required this.size,
    this.dnsQuery,
  });
}

class PacketStats {
  final int totalPackets;
  final int totalBytes;
  final Map<String, int> protoCounts;
  final Set<String> uniqueIps;
  final double pps;  // packets/sec
  final double bps;  // bytes/sec
  PacketStats({
    required this.totalPackets, required this.totalBytes,
    required this.protoCounts,  required this.uniqueIps,
    required this.pps,          required this.bps,
  });
  static PacketStats empty() => PacketStats(
    totalPackets: 0, totalBytes: 0,
    protoCounts: {}, uniqueIps: {},
    pps: 0, bps: 0,
  );
}

// ── Provider ─────────────────────────────────────────────────────────────────
final packetCaptureProvider =
    NotifierProvider.autoDispose<PacketCaptureNotifier, PacketStats>(PacketCaptureNotifier.new);

class PacketCaptureNotifier extends Notifier<PacketStats> {
  @override
  PacketStats build() => PacketStats.empty();

  RawDatagramSocket? _socket;
  StreamSubscription? _sub;
  Timer? _statsTimer;
  bool _capturing = false;

  final List<PacketEntry> packets = [];
  final List<int> _byteBuckets = List.filled(60, 0);  // rolling 60-sec
  final List<int> _pktBuckets  = List.filled(60, 0);
  int _bucketIdx = 0;

  final Map<String, int> _protoCounts = {};
  final Set<String> _uniqueIps = {};
  int _totalPackets = 0;
  int _totalBytes   = 0;

  bool get capturing => _capturing;

  Future<void> startCapture() async {
    if (_capturing) return;
    try {
      _socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4, 0);
      _socket!.readEventsEnabled = true;
      _capturing = true;

      _sub = _socket!.listen((RawSocketEvent event) {
        if (event != RawSocketEvent.read) return;
        final dg = _socket?.receive();
        if (dg == null) return;
        _processPacket(dg.data, dg.address.address, dg.port);
      });

      // Rolling stats ticker
      _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _bucketIdx = (_bucketIdx + 1) % 60;
        _byteBuckets[_bucketIdx] = 0;
        _pktBuckets[_bucketIdx]  = 0;
        final bps = _byteBuckets.reduce((a, b) => a + b) / 60.0;
        final pps = _pktBuckets.reduce((a, b) => a + b) / 60.0;
        state = PacketStats(
          totalPackets: _totalPackets,
          totalBytes:   _totalBytes,
          protoCounts:  Map.from(_protoCounts),
          uniqueIps:    Set.from(_uniqueIps),
          pps: pps, bps: bps,
        );
      });
    } catch (e) {
      _capturing = false;
    }
  }

  void stopCapture() {
    _sub?.cancel();
    _statsTimer?.cancel();
    _socket?.close();
    _socket = null;
    _capturing = false;
  }

  void clearPackets() {
    packets.clear();
    _protoCounts.clear();
    _uniqueIps.clear();
    _totalPackets = 0;
    _totalBytes   = 0;
    state = PacketStats.empty();
  }

  void _processPacket(Uint8List data, String srcAddr, int srcPort) {
    if (data.length < 20) return;

    // IPv4 header
    final proto = data.length > 9 ? data[9] : 17;
    final src = data.length >= 16
        ? '${data[12]}.${data[13]}.${data[14]}.${data[15]}'
        : srcAddr;
    final dst = data.length >= 20
        ? '${data[16]}.${data[17]}.${data[18]}.${data[19]}'
        : '0.0.0.0';

    int dstPort = 0;
    String protocol = 'OTHER';
    String? dnsQuery;

    if (proto == 17 && data.length >= 28) {
      // UDP: bytes 20-27
      final sp = (data[20] << 8) | data[21];
      dstPort  = (data[22] << 8) | data[23];
      protocol = dstPort == 53 || sp == 53 ? 'DNS' : 'UDP';
      if (protocol == 'DNS' && data.length > 32) {
        dnsQuery = _decodeDnsQuery(data);
      }
      srcPort = sp;
    } else if (proto == 6 && data.length >= 28) {
      srcPort  = (data[20] << 8) | data[21];
      dstPort  = (data[22] << 8) | data[23];
      protocol = 'TCP';
    } else if (proto == 1) {
      protocol = 'ICMP';
    }

    final entry = PacketEntry(
      time: DateTime.now(), protocol: protocol,
      src: src, dst: dst, srcPort: srcPort, dstPort: dstPort,
      size: data.length, dnsQuery: dnsQuery,
    );

    packets.add(entry);
    if (packets.length > 500) packets.removeAt(0);

    _protoCounts[protocol] = (_protoCounts[protocol] ?? 0) + 1;
    _uniqueIps.add(src);
    _totalPackets++;
    _totalBytes += data.length;
    _byteBuckets[_bucketIdx] += data.length;
    _pktBuckets[_bucketIdx]++;
  }

  /// Decode DNS QNAME from byte offset 32 (IP=20 + UDP=8 + DNS header=4)
  String _decodeDnsQuery(Uint8List data) {
    try {
      int i = 32;
      final labels = <String>[];
      while (i < data.length && data[i] != 0) {
        final len = data[i++];
        if (i + len > data.length) break;
        labels.add(String.fromCharCodes(data.sublist(i, i + len)));
        i += len;
      }
      return labels.join('.');
    } catch (_) {
      return 'decode-error';
    }
  }

  @override
  void dispose() {
    stopCapture();
  }
}

// ── Page ─────────────────────────────────────────────────────────────────────
class PacketSnifferPage extends ConsumerStatefulWidget {
  const PacketSnifferPage({super.key});
  @override
  ConsumerState<PacketSnifferPage> createState() => _PacketSnifferPageState();
}

class _PacketSnifferPageState extends ConsumerState<PacketSnifferPage> {
  static const _grn  = Color(0xFF00FF41);
  static const _cyn  = Color(0xFF00FFFF);
  static const _amb  = Color(0xFFFFB300);

  Set<String> _filterProtos = {};  // empty = show all
  bool _paused = false;

  static Color _protoColor(String p) {
    switch (p) {
      case 'UDP':   return const Color(0xFF00FFFF);
      case 'TCP':   return const Color(0xFF00FF41);
      case 'ICMP':  return const Color(0xFFFFB300);
      case 'DNS':   return const Color(0xFFCC88FF);
      default:      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats    = ref.watch(packetCaptureProvider);
    final notifier = ref.read(packetCaptureProvider.notifier);
    final allPackets = notifier.packets.reversed.toList();
    final shown = _filterProtos.isEmpty
        ? allPackets
        : allPackets.where((p) => _filterProtos.contains(p.protocol)).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: Column(children: [

        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(children: [
            const BackButtonTopLeft(),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('NETWORK PACKET ANALYSER',
                  style: TextStyle(color: _cyn, fontFamily: 'Courier New',
                      fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 2)),
              Text(notifier.capturing ? 'CAPTURING ACTIVE' : 'IDLE',
                  style: TextStyle(
                      color: notifier.capturing ? _grn : Colors.grey,
                      fontFamily: 'Courier New', fontSize: 10)),
            ])),
          ]),
        ),

        // ── Stats bar ────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF001A00),
            border: Border.all(color: const Color(0xFF003311)),
          ),
          child: Row(children: [
            _chip('PKT/S', stats.pps.toStringAsFixed(1), _grn),
            const SizedBox(width: 12),
            _chip('BYTE/S', _fmtBytes(stats.bps), _cyn),
            const SizedBox(width: 12),
            _chip('TOTAL', '${stats.totalPackets}', Colors.white),
            const SizedBox(width: 12),
            _chip('IPs', '${stats.uniqueIps.length}', _amb),
          ]),
        ),

        // ── Controls + protocol filter ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
            // Start/Stop
            SizedBox(
              width: 120,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: notifier.capturing ? Colors.red : _grn),
                    foregroundColor:
                        notifier.capturing ? Colors.red : _grn,
                    padding: EdgeInsets.zero),
                onPressed: () => setState(() {
                  if (notifier.capturing) {
                    notifier.stopCapture();
                  } else {
                    notifier.startCapture();
                  }
                }),
                child: Text(
                    notifier.capturing ? '■ STOP' : '▶ CAPTURE',
                    style: const TextStyle(fontFamily: 'Courier New',
                        fontSize: 11, letterSpacing: 1)),
              ),
            ),
            const SizedBox(width: 8),
            // Pause
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF003311)),
                  foregroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              onPressed: () => setState(() => _paused = !_paused),
              child: Text(_paused ? '▶ RESUME' : '❚❚ PAUSE',
                  style: const TextStyle(fontFamily: 'Courier New', fontSize: 10)),
            ),
            const SizedBox(width: 8),
            // Clear
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF003311)),
                  foregroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              onPressed: () => setState(() => notifier.clearPackets()),
              child: const Text('CLR',
                  style: TextStyle(fontFamily: 'Courier New', fontSize: 10)),
            ),
            const Spacer(),
            // Proto filter chips
            for (final p in ['UDP', 'TCP', 'ICMP', 'DNS'])
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: GestureDetector(
                  onTap: () => setState(() {
                    if (_filterProtos.contains(p)) {
                      _filterProtos.remove(p);
                    } else {
                      _filterProtos.add(p);
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _filterProtos.contains(p)
                          ? _protoColor(p).withOpacity(0.2)
                          : Colors.transparent,
                      border: Border.all(
                          color: _filterProtos.contains(p)
                              ? _protoColor(p)
                              : const Color(0xFF003311)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(p,
                        style: TextStyle(
                            color: _filterProtos.contains(p)
                                ? _protoColor(p)
                                : Colors.grey,
                            fontFamily: 'Courier New', fontSize: 9)),
                  ),
                ),
              ),
          ]),
        ),

        // ── Chart + packet list ───────────────────────────────────────────
        Expanded(child: Row(children: [

          // Pie chart
          SizedBox(
            width: 120,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: stats.protoCounts.isEmpty
                  ? const Center(child: Text('NO\nDATA',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey,
                          fontFamily: 'Courier New', fontSize: 10)))
                  : PieChart(PieChartData(
                      sectionsSpace: 1,
                      centerSpaceRadius: 20,
                      sections: stats.protoCounts.entries.map((e) {
                        final total = stats.totalPackets;
                        final pct = total > 0 ? e.value / total * 100 : 0.0;
                        return PieChartSectionData(
                          color: _protoColor(e.key),
                          value: pct,
                          title: pct > 10 ? e.key : '',
                          titleStyle: const TextStyle(
                              fontSize: 7, fontFamily: 'Courier New',
                              color: Colors.black),
                          radius: 40,
                        );
                      }).toList(),
                    )),
            ),
          ),

          // Packet list
          Expanded(
            child: shown.isEmpty
                ? Center(child: Text(
                    notifier.capturing
                        ? 'WAITING FOR PACKETS...'
                        : 'START CAPTURE TO MONITOR TRAFFIC',
                    style: const TextStyle(color: Colors.grey,
                        fontFamily: 'Courier New', fontSize: 12)))
                : ListView.builder(
                    padding: const EdgeInsets.only(right: 8, left: 4),
                    itemCount: shown.length,
                    itemBuilder: (ctx, i) {
                      final pkt = shown[i];
                      final t   = pkt.time;
                      final ts  = '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}:${t.second.toString().padLeft(2,'0')}';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF020602),
                          border: Border(
                            left: BorderSide(
                                color: _protoColor(pkt.protocol), width: 2),
                          ),
                        ),
                        child: Row(children: [
                          Text(ts,
                              style: const TextStyle(color: Colors.grey,
                                  fontFamily: 'Courier New', fontSize: 9)),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 3, vertical: 1),
                            color: _protoColor(pkt.protocol).withOpacity(0.15),
                            child: Text(pkt.protocol,
                                style: TextStyle(
                                    color: _protoColor(pkt.protocol),
                                    fontFamily: 'Courier New', fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 4),
                          Expanded(child: Text(
                            pkt.dnsQuery != null
                                ? '${pkt.src} → DNS: ${pkt.dnsQuery}'
                                : '${pkt.src}:${pkt.srcPort} → ${pkt.dst}:${pkt.dstPort}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70,
                                fontFamily: 'Courier New', fontSize: 9),
                          )),
                          Text('${pkt.size}B',
                              style: const TextStyle(color: Colors.grey,
                                  fontFamily: 'Courier New', fontSize: 9)),
                        ]),
                      );
                    },
                  ),
          ),
        ])),
      ])),
    );
  }

  Widget _chip(String label, String val, Color col) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$label:', style: const TextStyle(color: Colors.grey,
          fontFamily: 'Courier New', fontSize: 9)),
      const SizedBox(width: 2),
      Text(val, style: TextStyle(color: col, fontFamily: 'Courier New',
          fontSize: 10, fontWeight: FontWeight.bold)),
    ],
  );

  String _fmtBytes(double b) {
    if (b >= 1024 * 1024) return '${(b / 1048576).toStringAsFixed(1)}MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(1)}KB';
    return '${b.toStringAsFixed(0)}B';
  }
}
