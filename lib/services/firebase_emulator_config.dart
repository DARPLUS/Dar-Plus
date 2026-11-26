import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class FirebaseEmulatorConfig {
  static const enabled = bool.fromEnvironment('DARPLUS_USE_FIREBASE_EMULATORS');
  static const projectId = String.fromEnvironment(
    'DARPLUS_EMULATOR_PROJECT_ID',
    defaultValue: 'demo-darplus-local',
  );

  static String get host {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return '127.0.0.1';
  }
}
