import 'package:flutter/foundation.dart';

/// Local placeholder for auth state. Screens only ever touch [isSignedIn],
/// [signIn], and [signOut], so once Firebase is wired up this can be
/// replaced by a controller backed by FirebaseAuth.authStateChanges()
/// without changing anything downstream.
class AuthController extends ChangeNotifier {
  bool isSignedIn = false;

  void signIn() {
    if (isSignedIn) return;
    isSignedIn = true;
    notifyListeners();
  }

  void signOut() {
    if (!isSignedIn) return;
    isSignedIn = false;
    notifyListeners();
  }
}
