// Configuration Firebase lue depuis .env via flutter_dotenv
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static String get _apiKey           => dotenv.env['FIREBASE_API_KEY']           ?? '';
  static String get _messagingSenderId=> dotenv.env['FIREBASE_MESSAGING_SENDER_ID']?? '';
  static String get _projectId        => dotenv.env['FIREBASE_PROJECT_ID']        ?? '';
  static String get _storageBucket    => dotenv.env['FIREBASE_STORAGE_BUCKET']    ?? '';
  static String get _authDomain       => dotenv.env['FIREBASE_AUTH_DOMAIN']       ?? '';
  static String get _appIdWeb         => dotenv.env['FIREBASE_APP_ID_WEB']        ?? '';
  static String get _appIdAndroid     => dotenv.env['FIREBASE_APP_ID_ANDROID']    ?? '';
  static String get _appIdIos         => dotenv.env['FIREBASE_APP_ID_IOS']        ?? '';

  static FirebaseOptions get web => FirebaseOptions(
    apiKey: _apiKey,
    appId: _appIdWeb,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: _authDomain,
    storageBucket: _storageBucket,
  );

  static FirebaseOptions get android => FirebaseOptions(
    apiKey: _apiKey,
    appId: _appIdAndroid,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
  );

  static FirebaseOptions get ios => FirebaseOptions(
    apiKey: _apiKey,
    appId: _appIdIos,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
  );
}
