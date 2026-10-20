// Firebase options for DAITOM MOTORLINK LTD (project: daitom).
//
// Android  -> package com.daitom.flutter (matches android/app/google-services.json)
// iOS      -> bundle  com.daitom.flutter
// Web/macOS/Windows/Linux are intentionally NOT configured, so they can never
// silently talk to another project's database. To add one, register it in the
// Firebase console and run `flutterfire configure`.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase is not configured for web on project daitom. '
        'Register a web app in the Firebase console and run `flutterfire configure`.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase is only configured for Android and iOS on project daitom. '
          'Register this platform in the Firebase console and run `flutterfire configure`.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC6mXRXth3bft92Z3pfiaay0z5mZ2hYe74',
    appId: '1:762539988805:android:edd4b6d3dc3b9f7258102c',
    messagingSenderId: '762539988805',
    projectId: 'daitom',
    storageBucket: 'daitom.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCEnHGGk_3A0fpjw64UUsszIXfHEjOHzIo',
    appId: '1:762539988805:ios:5178571364e20c3458102c',
    messagingSenderId: '762539988805',
    projectId: 'daitom',
    storageBucket: 'daitom.firebasestorage.app',
    iosBundleId: 'com.daitom.flutter',
  );
}
