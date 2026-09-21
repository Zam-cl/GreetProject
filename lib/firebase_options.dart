import 'package:firebase_core/firebase_core.dart';

// Public web config from the Firebase console (safe to keep in client code —
// access is actually protected by Firestore Security Rules, not by hiding
// these values). Only a `web` target is defined since this app only ships
// to GitHub Pages, not to a native Android/iOS Firebase app.
class DefaultFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCRVRC89yG73fq-BoPdL4FEaFcitAlqhBE',
    authDomain: 'zamclgithub.firebaseapp.com',
    projectId: 'zamclgithub',
    storageBucket: 'zamclgithub.firebasestorage.app',
    messagingSenderId: '247083531701',
    appId: '1:247083531701:web:c20fdc95cb604b5b7eadfc',
  );
}
