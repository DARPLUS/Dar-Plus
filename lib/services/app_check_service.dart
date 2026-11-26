import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'firebase_emulator_config.dart';

class AppCheckService {
  static const _webSiteKey = String.fromEnvironment(
    'DARPLUS_RECAPTCHA_V3_SITE_KEY',
  );

  static bool _isReady = false;
  static String? _error;

  static bool get isReady => _isReady;
  static String? get error => _error;

  static Future<void> initialize() async {
    if (FirebaseEmulatorConfig.enabled) {
      _isReady = false;
      _error = 'Firebase App Check est désactivé avec les émulateurs locaux.';
      return;
    }

    try {
      if (kIsWeb) {
        if (kDebugMode) {
          await FirebaseAppCheck.instance.activate(
            providerWeb: WebDebugProvider(),
          );
        } else {
          if (_webSiteKey.isEmpty) {
            throw StateError(
              'DARPLUS_RECAPTCHA_V3_SITE_KEY is required for App Check on Web.',
            );
          }
          await FirebaseAppCheck.instance.activate(
            providerWeb: ReCaptchaV3Provider(_webSiteKey),
          );
        }
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            await FirebaseAppCheck.instance.activate(
              providerAndroid: kDebugMode
                  ? const AndroidDebugProvider()
                  : const AndroidPlayIntegrityProvider(),
            );
          case TargetPlatform.iOS:
          case TargetPlatform.macOS:
            await FirebaseAppCheck.instance.activate(
              providerApple: kDebugMode
                  ? const AppleDebugProvider()
                  : const AppleAppAttestWithDeviceCheckFallbackProvider(),
            );
          default:
            throw UnsupportedError(
              'Firebase App Check is not configured for this platform.',
            );
        }
      }

      _isReady = true;
      _error = null;
    } catch (error, stackTrace) {
      _isReady = false;
      _error = error.toString();
      debugPrint('Firebase App Check initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
