// Firebase configuration for avokaido_app.
//
// Shares the Firebase project avokaido-de9e1 with avokaido_admin and the
// develop_platform desktop app. A separate Web App registration can be
// added later (flutterfire configure) for per-app analytics splits.
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError('avokaido_app is web-only.');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyApBtf1xe2WGemsn9mieZUDijpgoLhRNOg',
    appId: '1:922635591841:web:165ea0781a600e8eef10e0',
    messagingSenderId: '922635591841',
    projectId: 'avokaido-de9e1',
    authDomain: 'avokaido-de9e1.firebaseapp.com',
    storageBucket: 'avokaido-de9e1.firebasestorage.app',
    measurementId: 'G-1Z0BV9Z5FL',
  );
}
