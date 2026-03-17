import 'dart:convert';
// =============================================================================
// FALCON EYE V48.1 — SECRET ADMIN SETTINGS PAGE
// Only accessible with the correct admin secret code.
// Manage wallet addresses, generate access codes, view stats.
// =============================================================================
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/subscription_service.dart';
import '../services/features_provider.dart';
import '../widgets/back_button_top_left.dart';

class AdminSettingsPage extends ConsumerStatefulWidget {
  const AdminSettingsPage({super.key});
  @override
  ConsumerState<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends ConsumerState<AdminSettingsPage> {
  final _currencyCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _networkCtrl = TextEditingController();
  int _batchCount = 10;

  @override
  void dispose() {
    _currencyCtrl.dispose();
    _addressCtrl.dispose();
    _networkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionProvider);
    final features = ref.watch(featuresProvider);
    final primary = features.primaryColor;

    if (!sub.isAdmin) {
      return _AdminLoginGate();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 60, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(children: [
                    Icon(Icons.admin_panel_settings, color: primary, size: 24),
                    const SizedBox(width: 10),
                    Text('ADMIN CONTROL PANEL',
                      style: TextStyle(color: primary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  ]),
                  const SizedBox(height: 4),
                  Text('V48.1 SOVEREIGN ADMIN - CLASSIFIED',
                    style: TextStyle(color: primary.withValues(alpha: 0.4), fontSize: 10, letterSpacing: 2)),
                  
                  const SizedBox(height: 24),

                  // === WALLET MANAGEMENT ===
                  _sectionHeader('CRYPTO WALLET ADDRESSES', Icons.account_balance_wallet, primary),
                  const SizedBox(height: 8),
                  
                  // Existing wallets
                  ...sub.wallets.asMap().entries.map((entry) {
                    final i = entry.key;
                    final w = entry.value;
                    return _walletCard(w, i, primary);
                  }),

                  // Add wallet form
                  _addWalletForm(primary),

                  const SizedBox(height: 24),

                  // === ACCESS CODE GENERATOR ===
                  _sectionHeader('ACCESS CODE GENERATOR', Icons.vpn_key, primary),
                  const SizedBox(height: 8),

                  // Stats
                  Row(children: [
                    _statBox('GENERATED', '${sub.generatedCodes.length}', primary),
                    const SizedBox(width: 8),
                    _statBox('REDEEMED', '${sub.redeemedCodes.length}', Colors.green),
                    const SizedBox(width: 8),
                    _statBox('AVAILABLE', '${sub.generatedCodes.length - sub.redeemedCodes.length}', Colors.amber),
                  ]),
                  
                  const SizedBox(height: 12),

                  // Generate buttons
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final code = ref.read(subscriptionProvider.notifier).generateAccessCode();
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Code generated and copied: $code'), backgroundColor: Colors.green.shade900),
                          );
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('GENERATE 1 CODE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ref.read(subscriptionProvider.notifier).generateBatchCodes(_batchCount);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$_batchCount codes generated'), backgroundColor: Colors.green.shade900),
                          );
                        },
                        icon: const Icon(Icons.dynamic_feed, size: 16),
                        label: Text('BATCH ($_batchCount)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: primary,
                          side: BorderSide(color: primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 12),

                  // Code list
                  if (sub.generatedCodes.isNotEmpty) ...[
                    Text('GENERATED CODES:', style: TextStyle(color: primary.withValues(alpha: 0.6), fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    ...sub.generatedCodes.reversed.take(20).map((code) {
                      final isRedeemed = sub.redeemedCodes.contains(code);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isRedeemed ? Colors.green.withValues(alpha: 0.08) : primary.withValues(alpha: 0.05),
                          border: Border.all(color: isRedeemed ? Colors.green.withValues(alpha: 0.3) : primary.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(children: [
                          Icon(isRedeemed ? Icons.check_circle : Icons.key, 
                            color: isRedeemed ? Colors.green : primary, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(code, style: TextStyle(
                              color: isRedeemed ? Colors.green : primary, 
                              fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                          ),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Copied: $code'), duration: const Duration(seconds: 1)),
                              );
                            },
                            child: Icon(Icons.copy, color: primary.withValues(alpha: 0.5), size: 14),
                          ),
                        ]),
                      );
                    }),
                  ],

                  const SizedBox(height: 24),

                  // === LIFETIME ADMIN LICENCE ===
                  _sectionHeader('ADMIN LICENCE', Icons.workspace_premium, primary),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: sub.isLifetimeAdmin
                          ? Colors.amber.withValues(alpha: 0.08)
                          : primary.withValues(alpha: 0.04),
                      border: Border.all(
                        color: sub.isLifetimeAdmin ? Colors.amber : primary.withValues(alpha: 0.3),
                        width: sub.isLifetimeAdmin ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(children: [
                      Row(children: [
                        Icon(sub.isLifetimeAdmin ? Icons.verified : Icons.timer,
                            color: sub.isLifetimeAdmin ? Colors.amber : primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            sub.isLifetimeAdmin ? 'LIFETIME ADMIN LICENCE ACTIVE' : 'SESSION ADMIN',
                            style: TextStyle(
                              color: sub.isLifetimeAdmin ? Colors.amber : primary,
                              fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          Text(
                            sub.isLifetimeAdmin
                                ? 'Permanent sovereign access — no expiry'
                                : 'Activate lifetime to remove session expiry',
                            style: TextStyle(
                              color: (sub.isLifetimeAdmin ? Colors.amber : primary).withValues(alpha: 0.5),
                              fontSize: 10),
                          ),
                        ])),
                      ]),
                      if (!sub.isLifetimeAdmin) ...[ 
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ref.read(subscriptionProvider.notifier).grantLifetimeAdminLicence();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ LIFETIME ADMIN LICENCE GRANTED — No expiry'),
                                  backgroundColor: Color(0xFF1B5E20),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            },
                            icon: const Icon(Icons.workspace_premium, size: 18),
                            label: const Text('GRANT LIFETIME ADMIN LICENCE',
                                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ),

                  const SizedBox(height: 24),

                  // Logout
                  // === AI CONFIGURATION ===
                  _sectionHeader('AI CONFIGURATION', Icons.psychology, primary),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: _AiKeySection(accent: primary),
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(subscriptionProvider.notifier).logoutAdmin();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.logout, size: 16),
                      label: const Text('LOGOUT ADMIN'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const BackButtonTopLeft(),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: color, width: 1)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
      ]),
    );
  }

  Widget _walletCard(CryptoWallet w, int index, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(w.currency, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(w.address, style: TextStyle(color: color, fontSize: 10, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis),
            Text(w.network, style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 9)),
          ]),
        ),
        IconButton(
          icon: Icon(Icons.delete, color: Colors.red.withValues(alpha: 0.5), size: 16),
          onPressed: () => ref.read(subscriptionProvider.notifier).removeWallet(index),
        ),
      ]),
    );
  }

  Widget _addWalletForm(Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.03),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(children: [
        Text('ADD WALLET', style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10, letterSpacing: 1)),
        const SizedBox(height: 8),
        Row(children: [
          SizedBox(width: 80, child: _inputField(_currencyCtrl, 'BTC/ETH/USDT', color)),
          const SizedBox(width: 6),
          SizedBox(width: 100, child: _inputField(_networkCtrl, 'Network', color)),
        ]),
        const SizedBox(height: 6),
        _inputField(_addressCtrl, 'Wallet Address', color),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              if (_currencyCtrl.text.isNotEmpty && _addressCtrl.text.isNotEmpty) {
                ref.read(subscriptionProvider.notifier).addWallet(CryptoWallet(
                  currency: _currencyCtrl.text.toUpperCase(),
                  address: _addressCtrl.text,
                  network: _networkCtrl.text,
                ));
                _currencyCtrl.clear();
                _addressCtrl.clear();
                _networkCtrl.clear();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: const Text('ADD WALLET'),
          ),
        ),
      ]),
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint, Color color) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: color, fontSize: 11),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: color.withValues(alpha: 0.3), fontSize: 10),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderSide: BorderSide(color: color.withValues(alpha: 0.3))),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: color.withValues(alpha: 0.2))),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: color)),
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 8, letterSpacing: 1)),
        ]),
      ),
    );
  }
}

class _AiKeySection extends StatefulWidget {
  final Color accent;
  const _AiKeySection({required this.accent});
  @override
  State<_AiKeySection> createState() => _AiKeySectionState();
}

class _AiKeySectionState extends State<_AiKeySection> {
  final _keyCtrl = TextEditingController();
  bool _obscure  = true;
  bool _saving   = false;
  String _status = '';

  @override
  void initState() { super.initState(); _loadKey(); }
  @override
  void dispose() { _keyCtrl.dispose(); super.dispose(); }

  Future<String> _deviceKey() async {
    try {
      final info   = await DeviceInfoPlugin().androidInfo;
      final raw    = '\${info.id}\${info.model}';
      final digest = sha256.convert(utf8.encode(raw));
      return digest.toString().substring(0, 32);
    } catch (_) { return 'falcon_eye_default_key_32chars!'; }
  }

  String _xorCrypt(String input, String key) {
    final bytes  = utf8.encode(input);
    final kBytes = utf8.encode(key);
    return base64.encode(
      List.generate(bytes.length, (i) => bytes[i] ^ kBytes[i % kBytes.length])
    );
  }

  Future<void> _loadKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enc   = prefs.getString('falcon_ai_key_enc') ?? '';
      if (enc.isEmpty) return;
      final key   = await _deviceKey();
      final kBytes = utf8.encode(key);
      final bytes  = base64.decode(enc);
      final plain  = String.fromCharCodes(
        List.generate(bytes.length, (i) => bytes[i] ^ kBytes[i % kBytes.length])
      );
      if (mounted) setState(() => _keyCtrl.text = plain);
    } catch (_) {}
  }

  Future<void> _saveKey() async {
    final raw = _keyCtrl.text.trim();
    setState(() { _saving = true; _status = ''; });
    try {
      final key = await _deviceKey();
      final enc = _xorCrypt(raw, key);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('falcon_ai_key_enc', enc);
      if (!mounted) return;
      setState(() { _saving = false; _status = 'KEY SAVED'; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _status = 'SAVE FAILED: \$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _keyCtrl,
        obscureText: _obscure,
        style: const TextStyle(color: Colors.white, fontFamily: 'Courier New', fontSize: 12),
        decoration: InputDecoration(
          hintText: 'sk-ant-api03-...',
          hintStyle: const TextStyle(color: Colors.grey, fontFamily: 'Courier New', fontSize: 11),
          labelText: 'ANTHROPIC API KEY',
          labelStyle: TextStyle(color: widget.accent, fontFamily: 'Courier New', fontSize: 11),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.accent.withOpacity(0.4))),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: widget.accent)),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey, size: 16),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: widget.accent),
            foregroundColor: widget.accent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: _saving ? null : _saveKey,
          child: Text(_saving ? 'SAVING...' : 'SAVE KEY',
              style: const TextStyle(fontFamily: 'Courier New', fontSize: 11)),
        ),
        const SizedBox(width: 12),
        if (_status.isNotEmpty)
          Text(_status, style: TextStyle(
              color: _status.contains('SAVED') ? widget.accent : Colors.red,
              fontFamily: 'Courier New', fontSize: 10)),
      ]),
      const SizedBox(height: 4),
      const Text('Key is AES-encrypted with your device ID. Used by AI Signal Brain page.',
          style: TextStyle(color: Colors.grey, fontFamily: 'Courier New', fontSize: 9)),
    ]);
  }
}


// ─── Admin Login Gate ──────────────────────────────────────────────────────
class _AdminLoginGate extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AdminLoginGate> createState() => _AdminLoginGateState();
}

class _AdminLoginGateState extends ConsumerState<_AdminLoginGate> {
  final _ctrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _errorMsg;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _tryLogin() async {
    final code = _ctrl.text.trim();
    if (code.isEmpty) {
      if (mounted) setState(() => _errorMsg = 'ENTER YOUR ADMIN CODE');
      return;
    }
    if (mounted) setState(() { _loading = true; _errorMsg = null; });

    // Tiny delay lets the loading indicator render before Riverpod triggers rebuild
    await Future.delayed(const Duration(milliseconds: 80));

    try {
      final ok = ref.read(subscriptionProvider.notifier).verifyAdminCode(code);

      // Guard: parent AdminSettingsPage may already be rebuilding (success path)
      if (!mounted) return;

      if (ok) {
        // Parent watches subscriptionProvider → auto-rebuilds to show admin panel
        setState(() => _loading = false);
      } else {
        setState(() { _loading = false; _errorMsg = 'INVALID ADMIN CODE'; });
        _ctrl.clear();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _errorMsg = 'AUTH ERROR — TRY AGAIN'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00FF41);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.admin_panel_settings, color: accent, size: 56),
              const SizedBox(height: 16),
              const Text('ADMIN ACCESS',
                  style: TextStyle(color: accent, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 3)),
              const SizedBox(height: 6),
              const Text('ENTER SECRET ADMIN CODE',
                  style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2)),
              const SizedBox(height: 16),
              // First-launch hint
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF001A00),
                  border: Border.all(color: const Color(0xFF003311)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Color(0xFF2E5A42), size: 14),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'First launch: any code you enter becomes the admin password.',
                    style: TextStyle(color: Color(0xFF2E5A42), fontSize: 10),
                  )),
                ]),
              ),
              TextField(
                controller: _ctrl,
                obscureText: _obscure,
                style: const TextStyle(color: accent, fontSize: 14, fontFamily: 'monospace'),
                onSubmitted: (_) => _tryLogin(),
                decoration: InputDecoration(
                  hintText: 'Admin code...',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                  prefixIcon: const Icon(Icons.lock, color: accent, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: accent, size: 18),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1A3A1A))),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: accent, width: 1.5)),
                  errorText: _errorMsg,
                  errorStyle: const TextStyle(color: Colors.red, fontSize: 11, letterSpacing: 1),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _tryLogin,
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.login, size: 18),
                  label: Text(_loading ? 'AUTHENTICATING...' : 'ENTER ADMIN CONTROL PANEL',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: const Color(0xFF004A1A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('← BACK', style: TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 1)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
