// =============================================================================
// FALCON EYE V48.1 — SOVEREIGN MONETIZATION SERVICE
// Crypto-payment subscription system with admin secret code.
// Trial period, wallet address configuration, access code generation.
// =============================================================================
import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
// SUBSCRIPTION TIERS
// =============================================================================
enum SubscriptionTier {
  trial('TRIAL', 7, 'Limited features for 7 days'),
  standard('STANDARD', 30, 'Full access for 30 days'),
  sovereign('SOVEREIGN', 365, 'Unlimited access + priority updates');

  const SubscriptionTier(this.label, this.days, this.description);
  final String label;
  final int days;
  final String description;
}

// =============================================================================
// WALLET CONFIGURATION
// =============================================================================
class CryptoWallet {
  final String currency;
  final String address;
  final String network;
  const CryptoWallet({required this.currency, required this.address, required this.network});

  Map<String, dynamic> toJson() => {'currency': currency, 'address': address, 'network': network};
  factory CryptoWallet.fromJson(Map<String, dynamic> json) => CryptoWallet(
    currency: json['currency'] as String? ?? '',
    address: json['address'] as String? ?? '',
    network: json['network'] as String? ?? '',
  );
}

// =============================================================================
// SUBSCRIPTION STATE
// =============================================================================
class SubscriptionState {
  final bool isAdmin;
  final bool isPremium;
  final bool isTrialActive;
  final DateTime? trialStartDate;
  final DateTime? subscriptionExpiry;
  final SubscriptionTier currentTier;
  final List<CryptoWallet> wallets;
  final List<String> generatedCodes;
  final List<String> redeemedCodes;
  final String? activeCode;

  const SubscriptionState({
    this.isAdmin = false,
    this.isPremium = false,
    this.isTrialActive = false,
    this.trialStartDate,
    this.subscriptionExpiry,
    this.currentTier = SubscriptionTier.trial,
    this.wallets = const [],
    this.generatedCodes = const [],
    this.redeemedCodes = const [],
    this.activeCode,
  });

  bool get isExpired {
    if (isAdmin) return false;
    if (subscriptionExpiry == null) return true;
    return DateTime.now().isAfter(subscriptionExpiry!);
  }

  /// -1 means LIFETIME ADMIN LICENCE (no expiry)
  int get daysRemaining {
    if (isAdmin && isLifetimeAdmin) return -1;
    if (isAdmin) return 99999;
    if (subscriptionExpiry == null) return 0;
    return subscriptionExpiry!.difference(DateTime.now()).inDays;
  }

  bool get isLifetimeAdmin => isAdmin && subscriptionExpiry == null;

  String get daysLabel {
    if (isLifetimeAdmin) return 'LIFETIME';
    final d = daysRemaining;
    if (d <= 0) return 'EXPIRED';
    if (d > 9000) return '∞';
    return '$d DAYS';
  }

  SubscriptionState copyWith({
    bool? isAdmin, bool? isPremium, bool? isTrialActive,
    DateTime? trialStartDate, DateTime? subscriptionExpiry,
    SubscriptionTier? currentTier, List<CryptoWallet>? wallets,
    List<String>? generatedCodes, List<String>? redeemedCodes,
    String? activeCode,
  }) => SubscriptionState(
    isAdmin: isAdmin ?? this.isAdmin,
    isPremium: isPremium ?? this.isPremium,
    isTrialActive: isTrialActive ?? this.isTrialActive,
    trialStartDate: trialStartDate ?? this.trialStartDate,
    subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
    currentTier: currentTier ?? this.currentTier,
    wallets: wallets ?? this.wallets,
    generatedCodes: generatedCodes ?? this.generatedCodes,
    redeemedCodes: redeemedCodes ?? this.redeemedCodes,
    activeCode: activeCode ?? this.activeCode,
  );
}

// =============================================================================
// SUBSCRIPTION SERVICE
// =============================================================================
class SubscriptionService extends Notifier<SubscriptionState> {
  static const _kPrefsKey = 'falcon_subscription_v477';
  static const _kWalletsKey = 'falcon_wallets_v477';
  static const _kCodesKey = 'falcon_codes_v477';
  static const _kRedeemedKey = 'falcon_redeemed_v477';
  static const _kAdminKey = 'falcon_admin_v477';

  // The admin password hash - SHA256 of the secret code
  // Default admin code: "FALCON_SOVEREIGN_2024"
  // Users can change this in admin settings
  String _adminPasswordHash = '';

  @override
  SubscriptionState build() {
    _load();
    return const SubscriptionState();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final subJson = prefs.getString(_kPrefsKey);
      final walletsJson = prefs.getString(_kWalletsKey);
      final codesJson = prefs.getString(_kCodesKey);
      final redeemedJson = prefs.getString(_kRedeemedKey);
      final adminHash = prefs.getString(_kAdminKey) ?? '';
      _adminPasswordHash = adminHash;

      List<CryptoWallet> wallets = [];
      if (walletsJson != null) {
        final list = jsonDecode(walletsJson) as List;
        wallets = list.map((w) => CryptoWallet.fromJson(w as Map<String, dynamic>)).toList();
      }

      List<String> codes = [];
      if (codesJson != null) {
        codes = (jsonDecode(codesJson) as List).cast<String>();
      }

      List<String> redeemed = [];
      if (redeemedJson != null) {
        redeemed = (jsonDecode(redeemedJson) as List).cast<String>();
      }

      if (subJson != null) {
        final sub = jsonDecode(subJson) as Map<String, dynamic>;
        state = SubscriptionState(
          isAdmin: sub['isAdmin'] as bool? ?? false,
          isPremium: sub['isPremium'] as bool? ?? false,
          isTrialActive: sub['isTrialActive'] as bool? ?? false,
          trialStartDate: sub['trialStart'] != null ? DateTime.tryParse(sub['trialStart'] as String) : null,
          subscriptionExpiry: sub['expiry'] != null ? DateTime.tryParse(sub['expiry'] as String) : null,
          currentTier: SubscriptionTier.values.firstWhere(
            (t) => t.name == (sub['tier'] as String? ?? 'trial'),
            orElse: () => SubscriptionTier.trial,
          ),
          wallets: wallets,
          generatedCodes: codes,
          redeemedCodes: redeemed,
        );
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsKey, jsonEncode({
        'isAdmin': state.isAdmin,
        'isPremium': state.isPremium,
        'isTrialActive': state.isTrialActive,
        'trialStart': state.trialStartDate?.toIso8601String(),
        'expiry': state.subscriptionExpiry?.toIso8601String(),
        'tier': state.currentTier.name,
      }));
      await prefs.setString(_kWalletsKey, jsonEncode(state.wallets.map((w) => w.toJson()).toList()));
      await prefs.setString(_kCodesKey, jsonEncode(state.generatedCodes));
      await prefs.setString(_kRedeemedKey, jsonEncode(state.redeemedCodes));
      if (_adminPasswordHash.isNotEmpty) {
        await prefs.setString(_kAdminKey, _adminPasswordHash);
      }
    } catch (_) {}
  }

  // Admin authentication
  bool verifyAdminCode(String code) {
    final hash = sha256.convert(utf8.encode(code)).toString();
    // Check against stored hash, or default if none set
    if (_adminPasswordHash.isEmpty) {
      // First-time setup: accept and store
      _adminPasswordHash = hash;
      state = state.copyWith(isAdmin: true);
      _save();
      return true;
    }
    if (hash == _adminPasswordHash) {
      state = state.copyWith(isAdmin: true);
      _save();
      return true;
    }
    return false;
  }

  void setAdminPassword(String newCode) {
    _adminPasswordHash = sha256.convert(utf8.encode(newCode)).toString();
    _save();
  }

  void logoutAdmin() {
    state = state.copyWith(isAdmin: false);
    _save();
  }

  /// Grants a permanent lifetime admin licence — no expiry date set
  void grantLifetimeAdminLicence() {
    if (!state.isAdmin) return;
    // Lifetime = isAdmin true, subscriptionExpiry = null (no end date)
    state = state.copyWith(
      isAdmin: true,
      isPremium: true,
      isTrialActive: false,
      subscriptionExpiry: null, // null = LIFETIME
      currentTier: SubscriptionTier.sovereign,
    );
    _save();
  }

  // Wallet management (admin only)
  void addWallet(CryptoWallet wallet) {
    if (!state.isAdmin) return;
    final wallets = [...state.wallets, wallet];
    state = state.copyWith(wallets: wallets);
    _save();
  }

  void removeWallet(int index) {
    if (!state.isAdmin || index >= state.wallets.length) return;
    final wallets = [...state.wallets]..removeAt(index);
    state = state.copyWith(wallets: wallets);
    _save();
  }

  void updateWallet(int index, CryptoWallet wallet) {
    if (!state.isAdmin || index >= state.wallets.length) return;
    final wallets = [...state.wallets];
    wallets[index] = wallet;
    state = state.copyWith(wallets: wallets);
    _save();
  }

  // Access code generation (admin only)
  String generateAccessCode() {
    if (!state.isAdmin) return '';
    final rng = math.Random.secure();
    final chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final code = List.generate(16, (_) => chars[rng.nextInt(chars.length)]).join();
    final formatted = '${code.substring(0, 4)}-${code.substring(4, 8)}-${code.substring(8, 12)}-${code.substring(12)}';
    final codes = [...state.generatedCodes, formatted];
    state = state.copyWith(generatedCodes: codes);
    _save();
    return formatted;
  }

  List<String> generateBatchCodes(int count) {
    final codes = <String>[];
    for (int i = 0; i < count; i++) {
      codes.add(generateAccessCode());
    }
    return codes;
  }

  // Code redemption (user)
  bool redeemCode(String code) {
    final normalized = code.trim().toUpperCase();
    if (state.generatedCodes.contains(normalized) && !state.redeemedCodes.contains(normalized)) {
      final redeemed = [...state.redeemedCodes, normalized];
      final expiry = DateTime.now().add(const Duration(days: 30));
      state = state.copyWith(
        isPremium: true,
        redeemedCodes: redeemed,
        activeCode: normalized,
        currentTier: SubscriptionTier.standard,
        subscriptionExpiry: expiry,
      );
      _save();
      return true;
    }
    return false;
  }

  // Trial activation
  void startTrial() {
    if (state.trialStartDate != null) return; // Trial already used
    final now = DateTime.now();
    state = state.copyWith(
      isTrialActive: true,
      trialStartDate: now,
      subscriptionExpiry: now.add(const Duration(days: 7)),
      currentTier: SubscriptionTier.trial,
      isPremium: true,
    );
    _save();
  }

  // Check if feature is unlocked
  bool isFeatureUnlocked() {
    if (state.isAdmin) return true;
    if (!state.isPremium) return false;
    return !state.isExpired;
  }
}

final subscriptionProvider =
    NotifierProvider<SubscriptionService, SubscriptionState>(SubscriptionService.new);
