// =============================================================================
// FALCON EYE V48.1 — SUBSCRIPTION & PAYMENT PAGE
// Crypto payments, trial activation, access code redemption.
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/subscription_service.dart';
import '../services/features_provider.dart';
import '../widgets/back_button_top_left.dart';
import 'admin_settings_page.dart';

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});
  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  final _codeCtrl = TextEditingController();
  final _adminCtrl = TextEditingController();
  bool _showAdminLogin = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _adminCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionProvider);
    final features = ref.watch(featuresProvider);
    final primary = features.primaryColor;

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
                    Icon(Icons.diamond, color: primary, size: 24),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('FALCON EYE SOVEREIGN',
                        style: TextStyle(color: primary, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
                      Text('PREMIUM SUBSCRIPTION',
                        style: TextStyle(color: primary.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 2)),
                    ]),
                  ]),

                  const SizedBox(height: 20),

                  // Current Status
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        primary.withValues(alpha: 0.1),
                        primary.withValues(alpha: 0.03),
                      ]),
                      border: Border.all(color: primary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(sub.isPremium && !sub.isExpired ? Icons.verified : Icons.lock,
                          color: sub.isPremium && !sub.isExpired ? Colors.green : Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          sub.isAdmin ? 'ADMINISTRATOR' :
                          sub.isPremium && !sub.isExpired ? 'PREMIUM ACTIVE' : 'FREE VERSION',
                          style: TextStyle(
                            color: sub.isPremium && !sub.isExpired ? Colors.green : Colors.orange,
                            fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      if (sub.isPremium && !sub.isExpired)
                        Text('Tier: ${sub.currentTier.label}  |  ${sub.daysRemaining} days remaining',
                          style: TextStyle(color: primary, fontSize: 11)),
                      if (sub.isExpired && sub.trialStartDate != null)
                        Text('Your subscription has expired. Renew to continue.',
                          style: TextStyle(color: Colors.red.withValues(alpha: 0.8), fontSize: 11)),
                    ]),
                  ),

                  const SizedBox(height: 20),

                  // Trial
                  if (sub.trialStartDate == null && !sub.isPremium) ...[
                    Text('START FREE TRIAL', style: TextStyle(color: primary, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ref.read(subscriptionProvider.notifier).startTrial();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('7-day trial activated!'), backgroundColor: Colors.green),
                          );
                        },
                        icon: const Icon(Icons.rocket_launch, size: 18),
                        label: const Text('ACTIVATE 7-DAY TRIAL'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Redeem Code
                  Text('REDEEM ACCESS CODE', style: TextStyle(color: primary, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _codeCtrl,
                        style: TextStyle(color: primary, fontSize: 13, fontFamily: 'monospace'),
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'XXXX-XXXX-XXXX-XXXX',
                          hintStyle: TextStyle(color: primary.withValues(alpha: 0.3)),
                          border: OutlineInputBorder(borderSide: BorderSide(color: primary)),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: primary.withValues(alpha: 0.3))),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primary)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final ok = ref.read(subscriptionProvider.notifier).redeemCode(_codeCtrl.text);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok ? 'Code redeemed! Premium activated.' : 'Invalid or used code.'),
                          backgroundColor: ok ? Colors.green : Colors.red,
                        ));
                        if (ok) _codeCtrl.clear();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      child: const Text('REDEEM'),
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Crypto Payment
                  if (sub.wallets.isNotEmpty) ...[
                    Text('PAY WITH CRYPTO', style: TextStyle(color: primary, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...sub.wallets.map((w) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.05),
                        border: Border.all(color: primary.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(w.currency, style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Text(w.network, style: TextStyle(color: primary.withValues(alpha: 0.5), fontSize: 10)),
                        ]),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: w.address));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Wallet address copied!'), duration: Duration(seconds: 1)),
                            );
                          },
                          child: Row(children: [
                            Expanded(
                              child: Text(w.address, style: TextStyle(color: primary, fontSize: 10, fontFamily: 'monospace')),
                            ),
                            Icon(Icons.copy, color: primary.withValues(alpha: 0.5), size: 14),
                          ]),
                        ),
                        const SizedBox(height: 4),
                        Text('Tap address to copy. Send payment and share TX hash for code.',
                          style: TextStyle(color: primary.withValues(alpha: 0.3), fontSize: 9)),
                      ]),
                    )),
                    const SizedBox(height: 16),
                  ],

                  // Admin login (hidden)
                  GestureDetector(
                    onLongPress: () => setState(() => _showAdminLogin = !_showAdminLogin),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Text('V48.1 SOVEREIGN EDITION',
                        style: TextStyle(color: primary.withValues(alpha: 0.15), fontSize: 9, letterSpacing: 2)),
                    ),
                  ),

                  if (_showAdminLogin) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.05),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(children: [
                        Text('ADMIN ACCESS', style: TextStyle(color: Colors.red.withValues(alpha: 0.6), fontSize: 10, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _adminCtrl,
                              obscureText: true,
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Secret Code',
                                hintStyle: TextStyle(color: Colors.red.withValues(alpha: 0.3)),
                                border: OutlineInputBorder(borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.3))),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              final ok = ref.read(subscriptionProvider.notifier).verifyAdminCode(_adminCtrl.text);
                              if (ok) {
                                Navigator.pushReplacement(context, MaterialPageRoute(
                                  builder: (_) => const AdminSettingsPage(),
                                ));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('INVALID CODE'), backgroundColor: Colors.red),
                                );
                              }
                              _adminCtrl.clear();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            child: const Text('ENTER'),
                          ),
                        ]),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
            const BackButtonTopLeft(),
          ],
        ),
      ),
    );
  }
}
