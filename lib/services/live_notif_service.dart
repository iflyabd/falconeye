import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  LIVE NOTIFICATION SERVICE  V49.9
//  "Home Widget" implemented as a persistent live intelligence notification:
//  • Shows a persistent Android notification with live signal counts
//  • Updates every 10 seconds with current BLE/Cell/WiFi/matter counts
//  • Tapping notification launches the app
//  • Notification styled as a HUD-style intelligence brief
//  • Uses NotificationDetails with ongoing=true so it pins to status bar
// ═══════════════════════════════════════════════════════════════════════════════

const _kNotifId = 900;
const _kChannelId = 'fe_live_hud';
const _kChannelName = 'Falcon Eye Live HUD';

class LiveNotifState {
  final bool active;
  final int updateCount;
  final String lastContent;

  const LiveNotifState({
    required this.active,
    required this.updateCount,
    required this.lastContent,
  });

  static LiveNotifState idle() => const LiveNotifState(
        active: false,
        updateCount: 0,
        lastContent: '',
      );

  LiveNotifState copyWith({bool? active, int? updateCount, String? lastContent}) =>
      LiveNotifState(
        active: active ?? this.active,
        updateCount: updateCount ?? this.updateCount,
        lastContent: lastContent ?? this.lastContent,
      );
}

class LiveNotifService extends Notifier<LiveNotifState> {
  final _notifs = FlutterLocalNotificationsPlugin();
  Timer? _timer;
  bool _init = false;
  int _bleCount = 0, _cellCount = 0, _wifiHz = 0, _matterCount = 0;

  @override
  LiveNotifState build() {
    ref.onDispose(_stop);
    return LiveNotifState.idle();
  }

  Future<void> enable() async {
    if (state.active) return;
    await _ensureInit();
    state = state.copyWith(active: true);
    _push(); // immediate first update
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _push());
  }

  void disable() => _stop();

  /// Call from neo_matrix build to feed live data
  void updateCounts({
    required int bleDevices,
    required int cellTowers,
    required int wifiHz,
    required int matterPoints,
  }) {
    _bleCount = bleDevices;
    _cellCount = cellTowers;
    _wifiHz = wifiHz;
    _matterCount = matterPoints;
  }

  Future<void> _ensureInit() async {
    if (_init) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await (_notifs as dynamic).initialize(const InitializationSettings(android: android));
    await _notifs
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _kChannelId,
            _kChannelName,
            importance: Importance.low,
            showBadge: false,
          ),
        );
    _init = true;
  }

  Future<void> _push() async {
    if (!state.active) return;
    final content =
        '📡 BLE:$_bleCount  📶 CELL:$_cellCount  📻 WiFi:${_wifiHz}Hz  ⚗️ Matter:$_matterCount';
    await (_notifs as dynamic).show(
      _kNotifId,
      '🦅 FALCON EYE — LIVE INTELLIGENCE',
      content,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelId,
          _kChannelName,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(
            content,
            htmlFormatBigText: false,
            contentTitle: '🦅 FALCON EYE — LIVE INTELLIGENCE',
          ),
        ),
      ),
    );
    state = state.copyWith(
      updateCount: state.updateCount + 1,
      lastContent: content,
    );
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    (_notifs as dynamic).cancel(_kNotifId);
    state = LiveNotifState.idle();
  }
}

final liveNotifProvider =
    NotifierProvider<LiveNotifService, LiveNotifState>(LiveNotifService.new);
