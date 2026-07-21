import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/profile_details.dart';
import 'auth_controller.dart';

/// Keeps the signed-in user's own `users/{uid}` doc and `profileDetails/{uid}`
/// doc warm in memory for the whole session, so screens that just need "my
/// own profile" (Settings, Preferences, Edit Profile, the Profile tab,
/// Scoring) can read the latest snapshot synchronously on build instead of
/// each independently awaiting a fresh `watchProfile()/watchProfileDetails()`
/// round-trip every time they're opened — that per-screen await was what
/// made every navigation flash a loading spinner even though the data
/// barely ever changes.
///
/// Owned by [HomeShell] (created once in initState, disposed with it) since
/// that's exactly the session AuthGate already guarantees a `users/{uid}`
/// read has completed for — by the time this is constructed, watchProfile's
/// first emission is a cache hit, not a network round-trip.
class ProfileCache extends ChangeNotifier {
  ProfileCache(AuthController auth) {
    _profileSub = auth.watchProfile().listen((data) {
      profile = data;
      hasProfile = true;
      notifyListeners();
    });
    _detailsSub = auth.watchProfileDetails().listen((data) {
      details = data;
      hasDetails = true;
      notifyListeners();
    });
  }

  late final StreamSubscription<Map<String, dynamic>?> _profileSub;
  late final StreamSubscription<ProfileDetails> _detailsSub;

  Map<String, dynamic>? profile;
  bool hasProfile = false;

  ProfileDetails details = const ProfileDetails();
  bool hasDetails = false;

  /// True once both docs have emitted at least once — the only state where
  /// a screen genuinely has nothing to render yet.
  bool get isReady => hasProfile && hasDetails;

  @override
  void dispose() {
    _profileSub.cancel();
    _detailsSub.cancel();
    super.dispose();
  }
}
