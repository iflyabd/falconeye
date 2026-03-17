import 'package:flutter/services.dart';

class UwbService {
  static const MethodChannel _channel = MethodChannel('falcon_eye/uwb');

  static Future<bool> isUwbSupported() async {
    try {
      final res = await _channel.invokeMethod<bool>('isUwbSupported');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
