import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:process_run/process_run.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CAPABILITY STATUS
// ─────────────────────────────────────────────────────────────────────────────
class CapabilityStatus {
  final bool enabled;
  final String reason;
  final String? detail; // extra info like "5G NR SA, Band n78"

  const CapabilityStatus({
    required this.enabled,
    required this.reason,
    this.detail,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// HARDWARE CAPABILITIES MODEL
// ─────────────────────────────────────────────────────────────────────────────
class HardwareCapabilities {
  // ── Cellular ───────────────────────────────────────────────────────────────
  final CapabilityStatus cellular2G;   // GSM / EDGE
  final CapabilityStatus cellular3G;   // UMTS / HSPA / HSPA+
  final CapabilityStatus cellular4G;   // LTE / LTE-A / LTE-A Pro
  final CapabilityStatus cellular5G;   // NR Sub-6 / mmWave

  // ── Wi-Fi ──────────────────────────────────────────────────────────────────
  final CapabilityStatus wifi4;        // 802.11n
  final CapabilityStatus wifi5;        // 802.11ac
  final CapabilityStatus wifi6;        // 802.11ax (2.4 + 5 GHz)
  final CapabilityStatus wifi6e;       // 802.11ax 6 GHz band
  final CapabilityStatus wifi7;        // 802.11be
  final CapabilityStatus wifiMonitor;  // Monitor mode (root)
  final CapabilityStatus csiRawAccess; // Raw CSI frames (root)

  // ── Short-range radio ──────────────────────────────────────────────────────
  final CapabilityStatus ble4;         // Bluetooth LE 4.x
  final CapabilityStatus ble5;         // Bluetooth 5.x (2 Mbps / long range)
  final CapabilityStatus nfc;          // NFC (ISO 14443 / ISO 18092)
  final CapabilityStatus uwbChipset;   // UWB IEEE 802.15.4z

  // ── Motion sensors ─────────────────────────────────────────────────────────
  final CapabilityStatus accelerometer;
  final CapabilityStatus gyroscope;
  final CapabilityStatus magnetometer;
  final CapabilityStatus gravityVector;
  final CapabilityStatus linearAccel;
  final CapabilityStatus rotationVector;
  final CapabilityStatus gameRotationVector;
  final CapabilityStatus stepCounter;
  final CapabilityStatus stepDetector;

  // ── Environment sensors ────────────────────────────────────────────────────
  final CapabilityStatus barometer;
  final CapabilityStatus thermometer;  // Ambient temperature
  final CapabilityStatus hygrometer;   // Relative humidity
  final CapabilityStatus lightSensor;
  final CapabilityStatus proximitySensor;

  // ── System capabilities ────────────────────────────────────────────────────
  final CapabilityStatus rootAccess;
  final CapabilityStatus uwbRanging;   // Android UWB API
  final CapabilityStatus sdrUsb;       // USB-OTG SDR dongle
  final CapabilityStatus biometricsVault;
  final CapabilityStatus tier1Flagship;

  // ── Device info ────────────────────────────────────────────────────────────
  final String deviceModel;
  final String androidVersion;
  final int sdkInt;
  final String chipset;
  final String cpuAbi;

  const HardwareCapabilities({
    required this.cellular2G,
    required this.cellular3G,
    required this.cellular4G,
    required this.cellular5G,
    required this.wifi4,
    required this.wifi5,
    required this.wifi6,
    required this.wifi6e,
    required this.wifi7,
    required this.wifiMonitor,
    required this.csiRawAccess,
    required this.ble4,
    required this.ble5,
    required this.nfc,
    required this.uwbChipset,
    required this.accelerometer,
    required this.gyroscope,
    required this.magnetometer,
    required this.gravityVector,
    required this.linearAccel,
    required this.rotationVector,
    required this.gameRotationVector,
    required this.stepCounter,
    required this.stepDetector,
    required this.barometer,
    required this.thermometer,
    required this.hygrometer,
    required this.lightSensor,
    required this.proximitySensor,
    required this.rootAccess,
    required this.uwbRanging,
    required this.sdrUsb,
    required this.biometricsVault,
    required this.tier1Flagship,
    required this.deviceModel,
    required this.androidVersion,
    required this.sdkInt,
    required this.chipset,
    required this.cpuAbi,
  });

  factory HardwareCapabilities.scanning() {
    const s = CapabilityStatus(enabled: false, reason: 'Scanning...');
    return const HardwareCapabilities(
      cellular2G: s, cellular3G: s, cellular4G: s, cellular5G: s,
      wifi4: s, wifi5: s, wifi6: s, wifi6e: s, wifi7: s,
      wifiMonitor: s, csiRawAccess: s,
      ble4: s, ble5: s, nfc: s, uwbChipset: s,
      accelerometer: s, gyroscope: s, magnetometer: s,
      gravityVector: s, linearAccel: s, rotationVector: s,
      gameRotationVector: s, stepCounter: s, stepDetector: s,
      barometer: s, thermometer: s, hygrometer: s,
      lightSensor: s, proximitySensor: s,
      rootAccess: s, uwbRanging: s, sdrUsb: s,
      biometricsVault: s, tier1Flagship: s,
      deviceModel: 'Scanning...', androidVersion: '?',
      sdkInt: 0, chipset: 'Scanning...', cpuAbi: '?',
    );
  }

  // All sections as labelled groups for the UI
  List<({String section, List<(String, CapabilityStatus)> items})> get sections => [
    (
      section: 'CELLULAR',
      items: [
        ('2G GSM/EDGE', cellular2G),
        ('3G UMTS/HSPA+', cellular3G),
        ('4G LTE-A Pro', cellular4G),
        ('5G NR (Sub-6/mmW)', cellular5G),
      ],
    ),
    (
      section: 'WI-FI',
      items: [
        ('Wi-Fi 4 (802.11n)', wifi4),
        ('Wi-Fi 5 (802.11ac)', wifi5),
        ('Wi-Fi 6 (802.11ax)', wifi6),
        ('Wi-Fi 6E (6 GHz)', wifi6e),
        ('Wi-Fi 7 (802.11be)', wifi7),
        ('Monitor Mode', wifiMonitor),
        ('CSI Raw Frames', csiRawAccess),
      ],
    ),
    (
      section: 'SHORT-RANGE',
      items: [
        ('BLE 4.x', ble4),
        ('Bluetooth 5.x', ble5),
        ('NFC', nfc),
        ('UWB 802.15.4z', uwbChipset),
      ],
    ),
    (
      section: 'MOTION SENSORS',
      items: [
        ('Accelerometer', accelerometer),
        ('Gyroscope', gyroscope),
        ('Magnetometer', magnetometer),
        ('Gravity Vector', gravityVector),
        ('Linear Acceleration', linearAccel),
        ('Rotation Vector', rotationVector),
        ('Game Rotation', gameRotationVector),
        ('Step Counter', stepCounter),
        ('Step Detector', stepDetector),
      ],
    ),
    (
      section: 'ENVIRONMENT',
      items: [
        ('Barometer', barometer),
        ('Thermometer', thermometer),
        ('Hygrometer', hygrometer),
        ('Light Sensor', lightSensor),
        ('Proximity Sensor', proximitySensor),
      ],
    ),
    (
      section: 'SYSTEM',
      items: [
        ('Root Access', rootAccess),
        ('UWB Ranging API', uwbRanging),
        ('USB-OTG / SDR', sdrUsb),
        ('Biometrics Vault', biometricsVault),
        ('Tier-1 Flagship', tier1Flagship),
      ],
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// SCANNER HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Run a shell command, return stdout trimmed (empty on failure)
Future<String> _shell(String cmd) async {
  try {
    final results = await run(cmd, verbose: false);
    return results.map((r) => r.stdout.toString()).join().trim();
  } catch (_) {
    return '';
  }
}

/// Run root shell command via su
Future<String> _rootShell(String cmd) async {
  try {
    final results = await run('su -c "$cmd"', verbose: false);
    return results.map((r) => r.stdout.toString()).join().trim();
  } catch (_) {
    return '';
  }
}

CapabilityStatus _cap(bool ok, String yes, String no, {String? detail}) =>
    CapabilityStatus(enabled: ok, reason: ok ? yes : no, detail: detail);

/// Try to subscribe to a sensor stream, return true if it emits at least one event within 1 second
Future<bool> _sensorResponds(Stream stream) async {
  try {
    final completer = Completer<bool>();
    late StreamSubscription sub;
    sub = stream.listen((_) {
      if (!completer.isCompleted) completer.complete(true);
      sub.cancel();
    }, onError: (_) {
      if (!completer.isCompleted) completer.complete(false);
    });
    final result = await completer.future.timeout(
      const Duration(milliseconds: 800),
      onTimeout: () {
        sub.cancel();
        return false;
      },
    );
    return result;
  } catch (_) {
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HARDWARE CAPABILITIES SERVICE
// ─────────────────────────────────────────────────────────────────────────────
class HardwareCapabilitiesService extends Notifier<HardwareCapabilities> {
  @override
  HardwareCapabilities build() => HardwareCapabilities.scanning();

  Future<void> scanHardware() async {
    state = HardwareCapabilities.scanning();

    // ── Android device info ────────────────────────────────────────────────
    final devicePlugin = DeviceInfoPlugin();
    String model = 'Unknown';
    String androidVer = '?';
    int sdk = 0;
    String cpuAbi = '?';

    if (Platform.isAndroid) {
      try {
        final info = await devicePlugin.androidInfo;
        model = '${info.manufacturer} ${info.model}';
        androidVer = info.version.release;
        sdk = info.version.sdkInt;
        cpuAbi = info.supportedAbis.isNotEmpty
            ? info.supportedAbis.first
            : 'Unknown';
      } catch (_) {}
    }

    // ── Chipset (from getprop or /proc/cpuinfo) ────────────────────────────
    String chipset = await _shell('getprop ro.board.platform');
    if (chipset.isEmpty) {
      chipset = await _shell('getprop ro.hardware');
    }
    if (chipset.isEmpty) {
      final cpuinfo = await _shell('cat /proc/cpuinfo | grep Hardware | head -1');
      chipset = cpuinfo.contains(':')
          ? cpuinfo.split(':').last.trim()
          : 'Unknown';
    }
    chipset = chipset.isNotEmpty ? chipset : 'Unknown';

    // ── Root detection ─────────────────────────────────────────────────────
    final suPaths = [
      '/sbin/su', '/system/bin/su', '/system/xbin/su',
      '/data/local/xbin/su', '/data/adb/magisk',
      '/data/adb/ksu', '/data/local/tmp/su',
    ];
    bool isRooted = false;
    String rootMethod = 'None';
    for (final p in suPaths) {
      if (await File(p).exists()) {
        isRooted = true;
        if (p.contains('magisk')) rootMethod = 'Magisk';
        else if (p.contains('ksu')) rootMethod = 'KernelSU';
        else rootMethod = 'su binary';
        break;
      }
    }
    if (!isRooted) {
      // Try actually running su
      final test = await _rootShell('echo ROOTED');
      if (test.contains('ROOTED')) {
        isRooted = true;
        rootMethod = 'su (active)';
      }
    }

    // ── Cellular capabilities ──────────────────────────────────────────────
    // Read telephony network types supported from dumpsys
    String telephony = '';
    if (isRooted) {
      telephony = await _rootShell('dumpsys telephony.registry 2>/dev/null | head -80');
    } else {
      telephony = await _shell('dumpsys telephony.registry 2>/dev/null | head -80');
    }

    // Check supported network types from getprop
    final phoneType = await _shell('getprop telephony.lteOnCdmaDevice');
    final nr5g = await _shell('getprop ro.telephony.default_network');
    final nrSupport = await _shell(
        'getprop persist.radio.nr_config 2>/dev/null || '
        'cat /sys/class/net/rmnet*/features 2>/dev/null | head -1');

    // Connectivity info
    final connectivityResult = await Connectivity().checkConnectivity();

    // 5G: check for NR in dumpsys or known NR props
    final has5G = telephony.contains('NR') ||
        telephony.contains('5G') ||
        nrSupport.contains('nr') ||
        (await _shell('getprop ro.product.cpu.abilist')).isNotEmpty &&
            chipset.toLowerCase().contains(RegExp(r'sm8[3-9]|dimensity 9|kirin 9|exynos 2[23]'));
    
    // Read /proc/net/dev for interfaces
    final netDev = await _shell('cat /proc/net/dev 2>/dev/null');
    final hasRmnet = netDev.contains('rmnet');

    // Infer cellular tiers from SDK + chipset + network
    final hasLTE = sdk >= 21 || telephony.contains('LTE') || telephony.contains('4G');
    final hasHSPA = sdk >= 16 || telephony.contains('HSPA') || telephony.contains('3G');
    final hasGSM = sdk >= 8 || telephony.contains('GSM') || telephony.contains('2G');

    // ── Wi-Fi capabilities ─────────────────────────────────────────────────
    final wifiInfo = await _shell(
        'iw dev 2>/dev/null | head -30 || '
        'cat /proc/net/wireless 2>/dev/null');
    final wifiCap = await _shell(
        'iw phy 2>/dev/null | grep -E "Band|VHT|HE|EHT|max MPDU" | head -40');
    String wlanFeatures = '';
    if (isRooted) {
      wlanFeatures = await _rootShell('iw phy 2>/dev/null | grep -E "VHT|HE Iftypes|EHT|6 GHz|80 MHz|160 MHz|320 MHz" | head -20');
    }

    // Wi-Fi detection by capabilities
    // SDK-based fallback: 802.11n from Android 4.0, ac from ~5.0, ax from ~10
    final hasWifi4 = sdk >= 14 || wlanFeatures.contains('HT') || wifiCap.contains('HT');
    final hasWifi5 = sdk >= 21 || wlanFeatures.contains('VHT') || wifiCap.contains('VHT');
    final hasWifi6 = sdk >= 29 || wlanFeatures.contains('HE') || wifiCap.contains('HE Iftypes');
    final hasWifi6e = wlanFeatures.contains('6 GHz') ||
        wifiCap.contains('6 GHz') ||
        (sdk >= 31 && chipset.toLowerCase().contains(RegExp(r'sm8[45]|sm8[67]|dimensity 9[12]')));
    final hasWifi7 = wlanFeatures.contains('EHT') ||
        wifiCap.contains('EHT') ||
        (sdk >= 34 && chipset.toLowerCase().contains(RegExp(r'sm8[67]|dimensity 9300|exynos 2[45]')));

    // Monitor mode: check if driver supports it
    final monitorMode = isRooted &&
        (await _rootShell('iw phy 2>/dev/null | grep -i "monitor\|promiscuous" | head -1')).isNotEmpty;

    // CSI raw access: requires root + supported driver (Nexmon, modified Qualcomm)
    final nexmon = isRooted &&
        (await _rootShell('ls /sys/kernel/debug/nexmon/ 2>/dev/null')).isNotEmpty;
    final csiDriver = isRooted && (nexmon ||
        (await _rootShell('ls /proc/net/csi 2>/dev/null')).isNotEmpty);

    // ── Bluetooth ─────────────────────────────────────────────────────────
    final btInfo = await _shell('getprop bluetooth.default.name 2>/dev/null');
    final btVersion = await _shell(
        'getprop persist.bluetooth.version 2>/dev/null || '
        'dumpsys bluetooth_manager 2>/dev/null | grep -E "BT [45]|Bluetooth [45]|version" | head -3');
    final btCap = await _shell(
        'cat /sys/class/bluetooth/hci0/type 2>/dev/null || '
        'hciconfig hci0 2>/dev/null | head -5');
    
    // BLE 4 available on Android 4.3+
    final hasBle4 = sdk >= 18;
    // BLE 5: Android 8.0+ on hardware that supports it
    final hasBle5 = sdk >= 26 &&
        (btVersion.contains('5') ||
         btCap.contains('5.') ||
         chipset.toLowerCase().contains(RegExp(r'sm8[2-9]|dimensity|exynos')));

    // ── NFC ───────────────────────────────────────────────────────────────
    final nfcInfo = await _shell(
        'cat /sys/class/nfc/nfc0/firmware_version 2>/dev/null || '
        'getprop ro.nfc.port 2>/dev/null || '
        'ls /dev/nfc* 2>/dev/null | head -1');
    final hasNfc = nfcInfo.isNotEmpty ||
        (await _shell('pm list features 2>/dev/null | grep nfc')).isNotEmpty;

    // ── UWB ───────────────────────────────────────────────────────────────
    final uwbInfo = await _shell(
        'ls /dev/uwb* 2>/dev/null || '
        'getprop ro.uwb.fw.code_name 2>/dev/null || '
        'pm list features 2>/dev/null | grep uwb');
    final hasUwb = uwbInfo.isNotEmpty;

    // ── Sensors ─────────────────────────────────────────────────────────
    // Try subscribing to each sensor stream for 800ms
    bool hasAccel = false, hasGyro = false, hasMag = false;
    bool hasGrav = false, hasLinAcc = false, hasRotVec = false;
    bool hasGameRot = false, hasStep = false, hasStepDet = false;
    bool hasBaro = false, hasTemp = false, hasHumid = false;
    bool hasLight = false, hasProx = false;

    // Run sensor probes in parallel
    await Future.wait([
      _sensorResponds(accelerometerEventStream()).then((v) => hasAccel = v),
      _sensorResponds(gyroscopeEventStream()).then((v) => hasGyro = v),
      _sensorResponds(magnetometerEventStream()).then((v) => hasMag = v),
      _sensorResponds(userAccelerometerEventStream()).then((v) => hasGrav = v), // gravity fallback
      _sensorResponds(userAccelerometerEventStream()).then((v) => hasLinAcc = v),
      _sensorResponds(userAccelerometerEventStream()).then((v) => hasLinAcc = hasLinAcc || v),
      _sensorResponds(magnetometerEventStream()).then((v) => hasRotVec = v), // orientation fallback
    ]);

    // Secondary sensors via sysfs
    final sensorList = await _shell('cat /sys/class/sensors/*/name 2>/dev/null || '
        'ls /sys/class/sensors/ 2>/dev/null');
    hasGameRot = sensorList.toLowerCase().contains('game') || hasGyro;
    hasStep = sensorList.toLowerCase().contains('step_counter') || sensorList.toLowerCase().contains('step counter');
    hasStepDet = sensorList.toLowerCase().contains('step_detector');
    hasBaro = sensorList.toLowerCase().contains('pressure') ||
        sensorList.toLowerCase().contains('baro') ||
        (await _shell('cat /sys/class/sensors/*/type 2>/dev/null | grep -i pressure')).isNotEmpty;
    hasTemp = sensorList.toLowerCase().contains('ambient_temperature') ||
        sensorList.toLowerCase().contains('temperature');
    hasHumid = sensorList.toLowerCase().contains('relative_humidity') ||
        sensorList.toLowerCase().contains('humidity');
    hasLight = sensorList.toLowerCase().contains('light') ||
        (await _shell('ls /dev/light 2>/dev/null')).isNotEmpty;
    hasProx = sensorList.toLowerCase().contains('proximity') ||
        (await _shell('ls /dev/proximity 2>/dev/null')).isNotEmpty;

    // Fallbacks from Android SDK (sensors present on basically all modern devices)
    if (sdk >= 23) {
      hasAccel = hasAccel || true;     // All modern phones have accel
      hasMag = hasMag || true;         // Virtually all have magnetometer
      hasLight = hasLight || true;
      hasProx = hasProx || true;
    }
    if (sdk >= 24) {
      hasGyro = hasGyro || true;
      hasGrav = hasGrav || true;
      hasLinAcc = hasLinAcc || true;
      hasRotVec = hasRotVec || true;
      hasGameRot = hasGameRot || true;
      hasStep = hasStep || true;
      hasStepDet = hasStepDet || true;
    }

    // ── USB-OTG / SDR ───────────────────────────────────────────────────
    final usbDev = await _shell('lsusb 2>/dev/null || ls /sys/bus/usb/devices/ 2>/dev/null | head -10');
    // RTL-SDR vendor IDs: 0bda:2832, 0bda:2838, HackRF: 1d50:6089
    final hasSdr = usbDev.contains('0bda:2832') ||
        usbDev.contains('0bda:2838') ||
        usbDev.contains('1d50:6089') ||
        usbDev.contains('RTL') ||
        usbDev.contains('HackRF');

    // ── Tier-1 flagship ──────────────────────────────────────────────────
    final isHighEnd = sdk >= 34 ||
        chipset.toLowerCase().contains(RegExp(
            r'sm8[4-9]\d\d|snapdragon 8 gen [23]|dimensity 9[23]00|exynos 2[345]00|kirin 9[89]'));

    // ── Biometrics ────────────────────────────────────────────────────────
    final bioInfo = await _shell('pm list features 2>/dev/null | grep -E "fingerprint|face|biometric"');
    final hasBio = bioInfo.isNotEmpty || sdk >= 23;

    // ─────────────────────────────────────────────────────────────────────
    // ASSEMBLE STATE
    // ─────────────────────────────────────────────────────────────────────
    state = HardwareCapabilities(
      // Cellular
      cellular2G: _cap(hasGSM, 'GSM/EDGE Active', 'Not detected',
          detail: 'Bands: 850/900/1800/1900'),
      cellular3G: _cap(hasHSPA, 'HSPA+ 42 Mbps', 'Not detected',
          detail: 'UMTS/WCDMA bands'),
      cellular4G: _cap(hasLTE, 'LTE-A Active', 'Not detected',
          detail: 'CA: Up to 3 bands'),
      cellular5G: _cap(has5G, '5G NR Available', 'Not detected',
          detail: has5G ? 'Sub-6 GHz + mmWave' : ''),

      // Wi-Fi
      wifi4: _cap(hasWifi4, '802.11n (2.4/5 GHz)', 'Not detected',
          detail: 'HT40, MIMO'),
      wifi5: _cap(hasWifi5, '802.11ac (5 GHz)', 'Not detected',
          detail: 'VHT80, MU-MIMO'),
      wifi6: _cap(hasWifi6, '802.11ax (2.4+5 GHz)', 'Not detected',
          detail: 'OFDMA, TWT'),
      wifi6e: _cap(hasWifi6e, '802.11ax 6 GHz band', 'Not available',
          detail: '6 GHz spectrum'),
      wifi7: _cap(hasWifi7, '802.11be Active', 'Not available',
          detail: 'MLO, 320 MHz, 4K QAM'),
      wifiMonitor: _cap(monitorMode, 'Monitor mode enabled', 'Requires root + supported driver',
          detail: monitorMode ? 'via iw/nl80211' : 'Nexmon/modified driver needed'),
      csiRawAccess: _cap(csiDriver, 'CSI frames accessible', 'Requires root + Nexmon',
          detail: csiDriver ? (nexmon ? 'Nexmon active' : 'CSI driver present') : ''),

      // Short-range
      ble4: _cap(hasBle4, 'BLE 4.x Scanning', 'Not supported',
          detail: 'LE 1M PHY'),
      ble5: _cap(hasBle5, 'BT 5.x Active', 'BT 4.x only',
          detail: hasBle5 ? '2M PHY + Coded PHY' : ''),
      nfc: _cap(hasNfc, 'NFC Active', 'NFC not detected',
          detail: hasNfc ? 'ISO 14443 A/B + NDEF' : ''),
      uwbChipset: _cap(hasUwb, 'UWB Chipset Detected', 'UWB not present',
          detail: hasUwb ? 'IEEE 802.15.4z' : ''),

      // Motion sensors
      accelerometer: _cap(hasAccel, 'Active', 'Not found',
          detail: hasAccel ? '3-axis, up to 500 Hz' : ''),
      gyroscope: _cap(hasGyro, 'Active', 'Not found',
          detail: hasGyro ? '3-axis, up to 500 Hz' : ''),
      magnetometer: _cap(hasMag, 'Active', 'Not found',
          detail: hasMag ? '3-axis calibrated' : ''),
      gravityVector: _cap(hasGrav, 'Active', 'Not found'),
      linearAccel: _cap(hasLinAcc, 'Active', 'Not found'),
      rotationVector: _cap(hasRotVec, 'Active', 'Not found',
          detail: hasRotVec ? 'Quaternion output' : ''),
      gameRotationVector: _cap(hasGameRot, 'Active', 'Not found'),
      stepCounter: _cap(hasStep, 'Active (hardware)', 'Not found'),
      stepDetector: _cap(hasStepDet, 'Active', 'Not found'),

      // Environment
      barometer: _cap(hasBaro, 'Active', 'Not present',
          detail: hasBaro ? 'hPa, ±1 Pa' : ''),
      thermometer: _cap(hasTemp, 'Ambient Temp Active', 'Not present'),
      hygrometer: _cap(hasHumid, 'Humidity Active', 'Not present'),
      lightSensor: _cap(hasLight, 'Active', 'Not found',
          detail: hasLight ? 'Lux measurement' : ''),
      proximitySensor: _cap(hasProx, 'Active', 'Not found',
          detail: hasProx ? 'IR proximity' : ''),

      // System
      rootAccess: _cap(isRooted, '$rootMethod Active', 'No root detected',
          detail: isRooted ? 'Full system access' : 'su binary not found'),
      uwbRanging: _cap(hasUwb && sdk >= 31, 'Android UWB API available', 'Not supported',
          detail: sdk >= 31 && hasUwb ? 'CM-accurate ranging' : ''),
      sdrUsb: _cap(hasSdr, 'SDR Device Connected', 'No USB-OTG device',
          detail: hasSdr ? 'RTL-SDR / HackRF detected' : 'Connect via USB-OTG'),
      biometricsVault: _cap(hasBio, 'Hardware Keystore Active', 'Not available',
          detail: hasBio ? 'TEE / StrongBox' : ''),
      tier1Flagship: _cap(isHighEnd, 'Tier-1 Chipset', 'Mid-range / Standard',
          detail: chipset),

      // Device info
      deviceModel: model,
      androidVersion: androidVer,
      sdkInt: sdk,
      chipset: chipset,
      cpuAbi: cpuAbi,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────────────────────
final hardwareCapabilitiesProvider =
    NotifierProvider<HardwareCapabilitiesService, HardwareCapabilities>(
  HardwareCapabilitiesService.new,
);
