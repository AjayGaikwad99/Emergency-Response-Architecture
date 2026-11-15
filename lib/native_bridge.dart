import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _channel =
      MethodChannel('com.yourcompany.fire_alert_app/foreground');

  static Future<bool> enableMonitoring() async {
    try {
      final res = await _channel.invokeMethod<bool>('enableMonitoring');
      return res == true;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> disableMonitoring() async {
    try {
      final res = await _channel.invokeMethod<bool>('disableMonitoring');
      return res == true;
    } on PlatformException {
      return false;
    }
  }
}
