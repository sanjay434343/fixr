import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => const FirebaseOptions(
    apiKey: '*********************************',
    appId: '*********************************',
    messagingSenderId: '*********************************',
    projectId: '*********************************',
    databaseURL: '*********************************',
    storageBucket: '*********************************',
  );
}
