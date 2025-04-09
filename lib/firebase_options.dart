// File: lib/firebase_options.dart

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyCq7vbvvD7axDXJhqdzSqs1c61ARMUP2hc",
    authDomain: "ngo-connect-167c5.firebaseapp.com",
    projectId: "ngo-connect-167c5",
    storageBucket: "ngo-connect-167c5.appspot.com",
    messagingSenderId: "339187545609",
    appId: "1:339187545609:web:4ef73db20472bee941ead8",
    measurementId: "G-7BGEHGDDB3",
  );
}
