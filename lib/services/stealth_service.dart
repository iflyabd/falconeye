import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple global toggle for Stealth Protocol.
class StealthProtocolNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void enable() => state = true;
  void disable() => state = false;
  void toggle() => state = !state;
}

final stealthProtocolProvider = NotifierProvider<StealthProtocolNotifier, bool>(() {
  return StealthProtocolNotifier();
});
