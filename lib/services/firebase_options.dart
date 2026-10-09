// Firebase options for the ultracem app (project: ultracem-b97e1).
//
// Only Android is configured - it comes from android/app/google-services.json
// (package com.ultracem.flutter). The old project's iOS/macOS/web/windows
// options were removed on purpose: left in, those platforms would silently keep
// talking to the previous app's database. To enable another platform, register
// it in the Firebase console and run `flutterfire configure`.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase is not configured for web on ultracem-b97e1. '
        'Register a web app in the Firebase console and run `flutterfire configure`.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Firebase is only configured for Android on ultracem-b97e1. '
          'Register this platform in the Firebase console and run `flutterfire configure`.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD0kGgOXgg0VNhhMC9rzu-WEyzwMAC0OOo',
    appId: '1:834116742888:android:2b105d6e50a5f572a1635d',
    messagingSenderId: '834116742888',
    projectId: 'ultracem-b97e1',
    storageBucket: 'ultracem-b97e1.firebasestorage.app',
  );
}
