import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAB7gHJeTXGlCLoILail7YNL9Jv19nEnHM',
    appId: '1:169704801434:android:d4d49f1361609bc87b8b23',
    messagingSenderId: '169704801434',
    projectId: 'boardcastsurf',
    storageBucket: 'boardcastsurf.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA0d2craOvFbsgyrS0TtaX8qK-ZCrDEUqY',
    appId: '1:169704801434:ios:0e01e093ab4976577b8b23',
    messagingSenderId: '169704801434',
    projectId: 'boardcastsurf',
    storageBucket: 'boardcastsurf.firebasestorage.app',
    iosBundleId: 'com.boardcast.app',
  );
}
