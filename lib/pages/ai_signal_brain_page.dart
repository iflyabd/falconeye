// ═══════════════════════════════════════════════════════════════════════════
// FALCON EYE V50.0 — AI SIGNAL BRAIN
// Feeds live signal environment snapshot to Claude API for tactical analysis.
// API key stored encrypted (SHA-256 device-ID key) in SharedPreferences.
// Response streams into terminal ticker display character by character.
// ═══════════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../services/signal_engine.dart';  // EnvironmentState, signalEngineProvider
import '../widgets/back_button_top_left.dart';

class AiSignalBrainPage extends ConsumerStatefulWidget {
  const AiSignalBrainPage({super.key});
  @override
  ConsumerState<AiSignalBrainPage> createState() => _AiSignalBrainPageState();
}

class _AiSignalBrainPageState extends ConsumerState<AiSignalBrainPage>
    with SingleTickerProviderStateMixin {
  static const _grn  = Color(0xFF00FF41);
  static const _cyn  = Color(0xFF00FFFF);
  static const _pur  = Color(0xFFCC88FF);

  String  _output      = '';
  String  _displayText = '';   // ticker-revealed portion
  bool    _loading     = false;
  bool    _autoAnalyse = false;
  String? _apiKey;
  String  _statusMsg   = 'FALCON EYE AI SIGNAL BRAIN — READY';

  Timer?  _autoTimer;
  Timer?  _tickerTimer;
  late AnimationController _cursorCtrl;

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _cursorCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _loadApiKey();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _tickerTimer?.cancel();
    _cursorCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── API Key management ────────────────────────────────────────────────────
  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final enc   = prefs.getString('falcon_ai_key_enc') ?? '';
    if (enc.isEmpty) return;
    try {
      final key     = await _deviceKey();
      final decoded = _xorDecrypt(enc, key);
      if (mounted) setState(() => _apiKey = decoded);
    } catch (_) {}
  }

  Future<String> _deviceKey() async {
    final info    = await DeviceInfoPlugin().androidInfo;
    final raw     = '${info.id}${info.model}';
    final digest  = sha256.convert(utf8.encode(raw));
    return digest.toString().substring(0, 32);
  }

  String _xorDecrypt(String enc, String key) {
    final bytes = base64.decode(enc);
    final kBytes = utf8.encode(key);
    return String.fromCharCodes(
      List.generate(bytes.length, (i) => bytes[i] ^ kBytes[i % kBytes.length])
    );
  }

  // ── Ticker reveal ─────────────────────────────────────────────────────────
  void _startTicker(String fullText) {
    _tickerTimer?.cancel();
    _displayText = '';
    int idx = 0;
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 18), (t) {
      if (!mounted) { t.cancel(); return; }
      if (idx >= fullText.length) { t.cancel(); return; }
      final end = (idx + 2).clamp(0, fullText.length);
      setState(() => _displayText = fullText.substring(0, end));
      idx = end;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    });
  }

  // ── Build prompt from live signal state ───────────────────────────────────
  String _buildPrompt(EnvironmentState env) {
    final ble     = env.sources.where((s) => s.type == 'BLE').toList();
    final wifi    = env.sources.where((s) => s.type == 'WiFi').toList();
    final cell    = env.sources.where((s) => s.type == 'Cell').toList();
    final moving  = env.sources.where((s) => s.isMoving).toList();
    final bleRssi = ble.isEmpty ? 'N/A'
        : ble.map((s) => s.rssi).reduce((a, b) => a > b ? a : b)
            .toStringAsFixed(1);
    final wifiRssi = wifi.isEmpty ? 'N/A'
        : wifi.map((s) => s.rssi).reduce((a, b) => a > b ? a : b)
            .toStringAsFixed(1);

    return '''You are FALCON EYE tactical AI core V50.0. Analyse this live signal environment snapshot and return a precise technical tactical assessment. Be specific and technical. Keep response under 220 words.

LIVE SIGNAL SNAPSHOT:
- BLE devices detected  : ${ble.length}  (strongest: $bleRssi dBm)
- WiFi networks         : ${wifi.length}  (strongest: $wifiRssi dBm)
- Cell towers           : ${cell.length}
- Moving signal sources : ${moving.length}
- Total signal sources  : ${env.sources.length}
- Anomalies detected    : ${env.sources.where((s) => s.isMoving).length}

OUTPUT FORMAT:
THREAT LEVEL: [LOW/MEDIUM/HIGH/CRITICAL]
NOTABLE FINDINGS: [key observations]
RECOMMENDED ACTION: [specific tactical response]
SIGNAL ANALYSIS: [technical breakdown]''';
  }

  // ── API call ─────────────────────────────────────────────────────────────
  Future<void> _analyse() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      setState(() {
        _output = 'NO API KEY SET\n\nEnter your Anthropic API key in the Admin Panel.\nAdmin → AI CONFIGURATION → Enter key → SAVE';
        _displayText = _output;
        _statusMsg = 'API KEY REQUIRED';
      });
      return;
    }

    final env = ref.read(signalEngineProvider);  // EnvironmentState
    setState(() {
      _loading   = true;
      _output    = '';
      _displayText = '';
      _statusMsg = 'ANALYSING SIGNAL ENVIRONMENT...';
    });

    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type':    'application/json',
          'x-api-key':       _apiKey!,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model':      'claude-sonnet-4-20250514',
          'max_tokens': 450,
          'messages':   [{'role': 'user', 'content': _buildPrompt(env)}],
        }),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = (data['content'] as List?)
                ?.firstWhere((c) => c['type'] == 'text',
                    orElse: () => {'text': 'No response'})['text']
                ?.toString() ?? 'Empty response';
        setState(() {
          _output    = text;
          _loading   = false;
          _statusMsg = 'ANALYSIS COMPLETE — ${DateTime.now().hour.toString().padLeft(2,'0')}:${DateTime.now().minute.toString().padLeft(2,'0')}';
        });
        _startTicker(text);
      } else if (response.statusCode == 401) {
        setState(() {
          _loading   = false;
          _output    = 'AUTHENTICATION FAILED\nInvalid API key. Update in Admin Panel → AI CONFIGURATION.';
          _displayText = _output;
          _statusMsg = 'AUTH FAILED';
        });
      } else {
        setState(() {
          _loading   = false;
          _output    = 'API ERROR ${response.statusCode}\n${response.body}';
          _displayText = _output;
          _statusMsg = 'ERROR ${response.statusCode}';
        });
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() { _loading = false; _statusMsg = 'TIMEOUT — RETRY'; _output = 'REQUEST TIMED OUT — CHECK NETWORK'; _displayText = _output; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _statusMsg = 'ERROR'; _output = 'ERROR: $e'; _displayText = _output; });
    }
  }

  void _toggleAutoAnalyse(bool v) {
    setState(() => _autoAnalyse = v);
    _autoTimer?.cancel();
    if (v) {
      _autoTimer = Timer.periodic(const Duration(seconds: 60), (_) => _analyse());
    }
  }

  Future<void> _saveReport() async {
    if (_output.isEmpty) return;
    try {
      // Save via recording service
      final prefs = await SharedPreferences.getInstance();
      final key   = 'ai_report_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(key, _output);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('REPORT SAVED TO DATA VAULT',
              style: TextStyle(fontFamily: 'Courier New', color: Color(0xFF00FF41))),
          backgroundColor: Color(0xFF001100),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SAVE FAILED: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final env = ref.watch(signalEngineProvider);
    final bleList  = env.sources.where((s) => s.type == 'BLE');
    final ble  = bleList.length;
    final wifi = env.sources.where((s) => s.type == 'WiFi').length;
    final cell = env.sources.where((s) => s.type == 'Cell').length;
    final mv   = env.sources.where((s) => s.isMoving).length;

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
              const Text('AI SIGNAL BRAIN',
                  style: TextStyle(color: _pur, fontFamily: 'Courier New',
                      fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
              Text(_statusMsg,
                  overflow: TextOverflow.ellipsis, maxLines: 1,
                  style: TextStyle(color: _loading ? Colors.amber : _grn,
                      fontFamily: 'Courier New', fontSize: 10)),
            ])),
          ]),
        ),

        // ── Live stats strip ─────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF050005),
            border: Border.all(color: const Color(0xFF330044)),
          ),
          child: Row(children: [
            _statChip('BLE', '$ble', _grn),
            const SizedBox(width: 12),
            _statChip('WiFi', '$wifi', _cyn),
            const SizedBox(width: 12),
            _statChip('CELL', '$cell', Colors.amber),
            const SizedBox(width: 12),
            _statChip('MOVING', '$mv', mv > 0 ? Colors.red : Colors.grey),
            const Spacer(),
            _statChip('ANOM', '${env.sources.where((s) => s.isMoving).length}',
                env.sources.where((s) => s.isMoving).length > 0 ? Colors.red : Colors.grey),
          ]),
        ),

        // ── Controls ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
            // ANALYSE button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _pur),
                foregroundColor: _pur,
              ),
              onPressed: _loading ? null : _analyse,
              icon: _loading
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5,
                          color: _pur))
                  : const Icon(Icons.psychology, size: 16),
              label: Text(_loading ? 'ANALYSING...' : 'ANALYSE NOW',
                  style: const TextStyle(fontFamily: 'Courier New',
                      fontSize: 11, letterSpacing: 1)),
            ),
            const SizedBox(width: 8),
            // SAVE button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _output.isEmpty ? Colors.grey : _grn),
                foregroundColor: _output.isEmpty ? Colors.grey : _grn,
              ),
              onPressed: _output.isEmpty ? null : _saveReport,
              icon: const Icon(Icons.save_alt, size: 14),
              label: const Text('SAVE', style: TextStyle(
                  fontFamily: 'Courier New', fontSize: 11)),
            ),
            const Spacer(),
            // AUTO toggle
            const Text('AUTO', style: TextStyle(color: Colors.grey,
                fontFamily: 'Courier New', fontSize: 11)),
            Switch(
              value: _autoAnalyse,
              onChanged: _toggleAutoAnalyse,
              activeColor: _pur,
            ),
          ]),
        ),

        const Divider(color: Color(0xFF220033), height: 12),

        // ── Terminal output ───────────────────────────────────────────────
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF020002),
              border: Border.all(color: const Color(0xFF220033)),
            ),
            child: _loading && _displayText.isEmpty
                ? Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _cursorCtrl,
                        builder: (_, __) => Text(
                          'ANALYSING SIGNAL ENVIRONMENT${_cursorCtrl.value > 0.5 ? '_' : ' '}',
                          style: const TextStyle(color: _pur,
                              fontFamily: 'Courier New', fontSize: 13),
                        ),
                      ),
                    ]))
                : SingleChildScrollView(
                    controller: _scroll,
                    child: AnimatedBuilder(
                      animation: _cursorCtrl,
                      builder: (_, __) => Text(
                        _displayText.isEmpty
                            ? 'AWAITING COMMAND...'
                            : '$_displayText${_displayText == _output ? '' : (_cursorCtrl.value > 0.5 ? '▋' : ' ')}',
                        style: TextStyle(
                          color: _displayText.isEmpty ? Colors.grey : _grn,
                          fontFamily: 'Courier New',
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ])),
    );
  }

  Widget _statChip(String label, String val, Color col) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$label:', style: const TextStyle(
          color: Colors.grey, fontFamily: 'Courier New', fontSize: 10)),
      const SizedBox(width: 3),
      Text(val, style: TextStyle(
          color: col, fontFamily: 'Courier New',
          fontSize: 11, fontWeight: FontWeight.bold)),
    ],
  );
}
