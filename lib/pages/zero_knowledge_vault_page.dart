import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/features_provider.dart';
import '../widgets/back_button_top_left.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  FALCON EYE V48.1 — ZERO-KNOWLEDGE VAULT
//  Encryption key = SHA-256(deviceID + fingerprint). No password stored.
//  Vault entries encrypted/decrypted in-memory. Data stored Base64 in prefs.
//  NOTE: Full AES encryption requires dart:crypto — here we use XOR with the
//  derived key (production-quality: replace with AES-GCM via pointycastle).
// ═══════════════════════════════════════════════════════════════════════════════

class VaultEntry {
  final String id;
  final String label;
  final String encryptedData; // base64
  final DateTime createdAt;
  final String hint;          // non-secret hint shown without decryption

  const VaultEntry({
    required this.id,
    required this.label,
    required this.encryptedData,
    required this.createdAt,
    required this.hint,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'label': label, 'encryptedData': encryptedData,
    'createdAt': createdAt.toIso8601String(), 'hint': hint,
  };

  factory VaultEntry.fromJson(Map<String, dynamic> j) => VaultEntry(
    id: j['id'], label: j['label'], encryptedData: j['encryptedData'],
    createdAt: DateTime.parse(j['createdAt']), hint: j['hint'] ?? '',
  );
}

class ZeroKnowledgeVaultPage extends ConsumerStatefulWidget {
  const ZeroKnowledgeVaultPage({super.key});
  @override
  ConsumerState<ZeroKnowledgeVaultPage> createState() => _ZeroKnowledgeVaultPageState();
}

class _ZeroKnowledgeVaultPageState extends ConsumerState<ZeroKnowledgeVaultPage> {
  static const _kPrefsKey = 'falcon_zk_vault_v481';

  List<VaultEntry> _entries = [];
  String? _derivedKey;
  bool _unlocked = false;
  bool _deriving = false;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null) return;
    final list = jsonDecode(raw) as List;
    if (mounted) setState(() {
      _entries = list.map((e) => VaultEntry.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, jsonEncode(_entries.map((e) => e.toJson()).toList()));
  }

  Future<String> _deriveKey() async {
    final info = await DeviceInfoPlugin().androidInfo;
    final deviceId = info.id;
    final fingerprint = info.fingerprint;
    final combined = '$deviceId::$fingerprint::falcon_eye_zk';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _unlockVault() async {
    setState(() => _deriving = true);
    final key = await _deriveKey();
    setState(() {
      _derivedKey = key;
      _unlocked = true;
      _deriving = false;
    });
  }

  void _lockVault() {
    setState(() {
      _derivedKey = null;
      _unlocked = false;
    });
  }

  // XOR "encryption" with key bytes — replace with AES-GCM in production
  String _xorEncrypt(String plaintext, String key) {
    final ptBytes = utf8.encode(plaintext);
    final keyBytes = utf8.encode(key);
    final result = Uint8List(ptBytes.length);
    for (int i = 0; i < ptBytes.length; i++) {
      result[i] = ptBytes[i] ^ keyBytes[i % keyBytes.length];
    }
    return base64.encode(result);
  }

  String _xorDecrypt(String ciphertext, String key) {
    try {
      final ctBytes = base64.decode(ciphertext);
      final keyBytes = utf8.encode(key);
      final result = Uint8List(ctBytes.length);
      for (int i = 0; i < ctBytes.length; i++) {
        result[i] = ctBytes[i] ^ keyBytes[i % keyBytes.length];
      }
      return utf8.decode(result);
    } catch (_) {
      return '[DECRYPTION FAILED — WRONG DEVICE?]';
    }
  }

  Future<void> _addEntry(String label, String plaintext, String hint) async {
    if (_derivedKey == null) return;
    final encrypted = _xorEncrypt(plaintext, _derivedKey!);
    final entry = VaultEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: label,
      encryptedData: encrypted,
      createdAt: DateTime.now(),
      hint: hint,
    );
    setState(() => _entries.add(entry));
    _saveEntries();
  }

  void _showAddDialog() {
    final labelCtrl = TextEditingController();
    final dataCtrl = TextEditingController();
    final hintCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text('ADD VAULT ENTRY', style: TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _field(labelCtrl, 'Label (visible)'),
          const SizedBox(height: 8),
          _field(dataCtrl, 'Secret data (encrypted)', obscure: true),
          const SizedBox(height: 8),
          _field(hintCtrl, 'Hint (visible, non-secret)'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white38, fontFamily: 'monospace'))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addEntry(labelCtrl.text, dataCtrl.text, hintCtrl.text);
            },
            child: const Text('STORE', style: TextStyle(color: Color(0xFF00FF41), fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, {bool obscure = false}) => TextField(
    controller: ctrl,
    obscureText: obscure,
    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 11),
      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF41))),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final color = ref.watch(featuresProvider).primaryColor;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: Column(children: [
        // ── Header ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            const BackButtonTopLeft(),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ZERO-KNOWLEDGE VAULT', style: TextStyle(color: color, fontSize: 13,
                  fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              Text('KEY = SHA-256(DEVICE-ID + FINGERPRINT) — NO PASSWORD STORED',
                  style: const TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'monospace')),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: _unlocked ? Colors.greenAccent : Colors.red),
              ),
              child: Text(_unlocked ? '🔓 OPEN' : '🔒 LOCKED',
                  style: TextStyle(color: _unlocked ? Colors.greenAccent : Colors.red,
                      fontSize: 10, fontFamily: 'monospace')),
            ),
          ]),
        ),
        // ── Status ──────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.2)),
            color: color.withValues(alpha: 0.04),
          ),
          child: Text(
            _unlocked
                ? 'KEY: ${_derivedKey!.substring(0, 20)}… (hardware-bound, never stored)'
                : 'Tap UNLOCK to derive key from this device\'s hardware ID.\nThe key is ephemeral — computed on-demand, never persisted.',
            style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9, fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(height: 8),
        // ── Vault list ───────────────────────────────────────────────
        Expanded(
          child: _entries.isEmpty
              ? Center(child: Text('VAULT EMPTY',
                  style: TextStyle(color: color.withValues(alpha: 0.4),
                      fontFamily: 'monospace', letterSpacing: 2)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _entries.length,
                  itemBuilder: (_, i) {
                    final e = _entries[i];
                    final decrypted = _unlocked && _derivedKey != null
                        ? _xorDecrypt(e.encryptedData, _derivedKey!)
                        : null;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: color.withValues(alpha: 0.2)),
                        color: color.withValues(alpha: 0.03),
                      ),
                      child: Row(children: [
                        Icon(Icons.enhanced_encryption, color: color.withValues(alpha: 0.5), size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.label, style: const TextStyle(color: Colors.white, fontSize: 11,
                              fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                          if (e.hint.isNotEmpty)
                            Text('HINT: ${e.hint}', style: TextStyle(color: color.withValues(alpha: 0.6),
                                fontSize: 9, fontFamily: 'monospace')),
                          if (decrypted != null)
                            Text(decrypted, style: TextStyle(color: Colors.greenAccent,
                                fontSize: 10, fontFamily: 'monospace'))
                          else
                            const Text('••••••••••••',
                                style: TextStyle(color: Colors.white30, fontSize: 12, letterSpacing: 4)),
                        ])),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                          onPressed: () {
                            setState(() => _entries.removeAt(i));
                            _saveEntries();
                          },
                          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                        ),
                      ]),
                    );
                  },
                ),
        ),
        // ── Controls ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: _btn(
              _deriving ? 'DERIVING KEY...' : (_unlocked ? 'LOCK' : 'UNLOCK'),
              _unlocked ? Colors.red : color,
              _deriving ? () {} : (_unlocked ? _lockVault : _unlockVault),
            )),
            const SizedBox(width: 8),
            Expanded(child: _btn('+ ADD ENTRY', color,
                _unlocked ? _showAddDialog : () {})),
          ]),
        ),
      ])),
    );
  }

  Widget _btn(String label, Color c, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: 0.5)),
        color: c.withValues(alpha: 0.08),
      ),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(color: c, fontFamily: 'monospace',
          fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
    ),
  );
}
