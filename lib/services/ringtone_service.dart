import 'package:flutter/services.dart';

/// Joue la sonnerie système via un MethodChannel natif (Android RingtoneManager).
class RingtoneService {
  RingtoneService._();
  static final RingtoneService instance = RingtoneService._();

  static const MethodChannel _channel = MethodChannel('dar_plus/ringtone');

  Future<void> play() async {
    try {
      await _channel.invokeMethod('play');
    } catch (_) {}
  }

  Future<void> playRingback() async {
    try {
      await _channel.invokeMethod('playRingback');
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }
}
