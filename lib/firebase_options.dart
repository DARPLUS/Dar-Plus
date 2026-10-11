// File generated from android/app/google-services.json for Dar-Plus.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBBr6ZEHLCYb30Qh07TzlWntn6WCr6NEH0',
    appId: '1:295698733625:web:2bd009897270b1d636cbe8',
    messagingSenderId: '295698733625',
    projectId: 'darplus-edfbe',
    authDomain: 'darplus-edfbe.firebaseapp.com',
    storageBucket: 'darplus-edfbe.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBBr6ZEHLCYb30Qh07TzlWntn6WCr6NEH0',
    appId: '1:295698733625:android:2bd009897270b1d636cbe8',
    messagingSenderId: '295698733625',
    projectId: 'darplus-edfbe',
    storageBucket: 'darplus-edfbe.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBBr6ZEHLCYb30Qh07TzlWntn6WCr6NEH0',
    appId: '1:295698733625:ios:2bd009897270b1d636cbe8',
    messagingSenderId: '295698733625',
    projectId: 'darplus-edfbe',
    storageBucket: 'darplus-edfbe.firebasestorage.app',
  );
}
