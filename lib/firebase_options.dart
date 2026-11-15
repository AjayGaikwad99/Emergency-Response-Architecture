import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions: web is not supported by this file. Use flutterfire configure to generate web config.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions: this file is generated for Android only.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions: platform not supported.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCVMeNPWEfJQpGSdaD8SdAu4YSwM57gogo',
    appId: '1:186949919879:android:728f5288d5839adafd0422',
    messagingSenderId: '186949919879',
    projectId: 'firealert-675c4',
    storageBucket: 'firealert-675c4.firebasestorage.app',
  );
}
