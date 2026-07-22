import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/discover_candidate.dart';
import '../models/likes_and_matches.dart';
import '../models/profile_details.dart';
import '../models/review_entry.dart';

/// A profile photo's public URL and its Storage path — both are needed
/// because scoring points at the Storage path of an existing profile
/// photo rather than a separate upload.
class ProfilePhoto {
  const ProfilePhoto({
    required this.url,
    required this.storagePath,
    this.category = '',
  });

  final String url;
  final String storagePath;

  /// '' (untagged), 'hobby', or 'food' — at most one photo per category,
  /// enforced by EditProfileScreen's tagging UI. Surfaced to other users as
  /// hobbyPhotoUrl/foodPhotoUrl on ProfileExtras (see summarizeUserDoc in
  /// functions/index.js).
  final String category;

  Map<String, dynamic> toMap() => {
    'url': url,
    'storagePath': storagePath,
    'category': category,
  };
}

/// One suggestion from [AuthController.placeAutocomplete] — placeId is
/// opaque, only meaningful as an input to [AuthController.placeDetails].
class PlaceSuggestion {
  const PlaceSuggestion({required this.placeId, required this.description});

  factory PlaceSuggestion.fromMap(Map<dynamic, dynamic> map) {
    return PlaceSuggestion(
      placeId: (map['placeId'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
    );
  }

  final String placeId;
  final String description;
}

/// The city/state/coordinates resolved from a [PlaceSuggestion] via
/// [AuthController.placeDetails].
class ResolvedPlace {
  const ResolvedPlace({
    required this.city,
    required this.state,
    required this.lat,
    required this.lng,
  });

  factory ResolvedPlace.fromMap(Map<dynamic, dynamic> map) {
    return ResolvedPlace(
      city: (map['city'] ?? '').toString(),
      state: (map['state'] ?? '').toString(),
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
    );
  }

  final String city;
  final String state;
  final double lat;
  final double lng;
}

class PhoneVerificationSession {
  const PhoneVerificationSession({
    required this.verificationId,
    required this.resendToken,
    this.automaticallyVerified = false,
  });

  const PhoneVerificationSession.automaticallyVerified()
    : verificationId = '',
      resendToken = null,
      automaticallyVerified = true;

  final String verificationId;
  final int? resendToken;
  final bool automaticallyVerified;
}

abstract class AuthController extends ChangeNotifier {
  bool get isSignedIn;

  String? get currentUserId;

  Future<PhoneVerificationSession> sendPhoneVerificationCode({
    required String phoneNumber,
    int? forceResendingToken,
    FutureOr<void> Function()? onAutomaticVerification,
  });

  Future<void> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  });

  Future<void> signOut();

  /// Permanently deletes the account and everything tied to it (profile,
  /// photos, matches, messages) — see deleteAccount in functions/index.js.
  /// Signs the local session out afterward so the app routes back to the
  /// welcome screen immediately rather than waiting for a future request
  /// to discover the Auth user is gone.
  Future<void> deleteAccount();

  /// The full users/{uid} document, or null if signed out / not created yet.
  /// Drives AuthGate (profileCompleted, accountStatus) as well as the
  /// profile screens.
  Stream<Map<String, dynamic>?> watchProfile();

  Future<ProfilePhoto> uploadProfilePhoto(File file);

  /// Runs content moderation (nudity, etc. — see moderatePhoto in
  /// functions/index.js) on an already-uploaded photo. Must be called for
  /// every newly uploaded photo before it's included in the list passed to
  /// [saveProfile] — uploadProfilePhoto itself does no moderation. Returns
  /// false if the photo was rejected; the server deletes the Storage file
  /// in that case, so callers don't need to separately clean it up.
  Future<bool> moderatePhoto(String storagePath);

  /// Deletes a profile photo from Storage. Callers are responsible for also
  /// removing it from the photos list passed to [saveProfile] — this only
  /// cleans up the underlying file so removed photos don't linger.
  Future<void> deleteProfilePhoto(String storagePath);

  Future<void> saveProfile({
    required String name,
    required DateTime birthDate,
    required String gender,
    required String interestedIn,
    required List<ProfilePhoto> photos,
  });

  /// Updates just the gender-interest preference — lighter weight than
  /// [saveProfile], which requires every core field together. Used by
  /// PreferencesScreen, which doesn't own the rest of those fields.
  Future<void> updateInterestedIn(String interestedIn);

  /// Hides this account from Discover without deleting anything — existing
  /// matches/messages stay fully usable, only new discovery is affected.
  /// Self-service, unlike accountStatus which only a reviewer can set.
  Future<void> setAccountPaused(bool paused);

  /// Which push notification categories this account wants — keys are
  /// 'like' / 'match' / 'message', matching the category sendPushToUser
  /// checks server-side (see functions/index.js). Missing keys default to
  /// enabled. Pass the full map every time (not just the key that
  /// changed) — this replaces the whole notificationPrefs field rather
  /// than merging into it.
  Future<void> setNotificationPrefs(Map<String, bool> prefs);

  /// Calls the scorePhoto Cloud Function on an existing profile photo
  /// (identified by its Storage path — must be one of this user's own
  /// profile_photos/{uid}/... uploads). The result is written server-side
  /// to Firestore (scoringStatus / scoreRejectionReason on the user doc,
  /// the band itself never leaves the server) — watch [watchProfile] to
  /// see it land.
  Future<void> submitPhotoForScoring(String storagePath);

  /// Today's (up to the daily limit) curated candidates, generated and
  /// cached server-side on first call each day.
  Future<DailyMatches> getDailyMatches();

  /// Returns true if this decision produced an immediate mutual match (the
  /// candidate had already liked this user first).
  Future<bool> recordMatchDecision({
    required String candidateUid,
    required String decision,
  });

  /// People who liked you (received) and people you've liked who haven't
  /// responded yet (sent) — excludes anyone already matched.
  Future<LikesResult> getLikes();

  /// Accept or decline a received like. Accepting creates a match.
  Future<void> respondToLike({required String likerUid, required bool accept});

  /// Withdraws a like you sent that hasn't been responded to yet.
  Future<void> cancelSentLike(String candidateUid);

  Future<List<MatchConnection>> getMatches();

  Stream<List<ChatMessageEntry>> watchMessages(String connectionId);

  Future<void> sendMessage({
    required String connectionId,
    required String text,
  });

  /// Double-tap-to-heart a message, iMessage-tapback style. addReaction
  /// true hearts it (adds the caller's uid), false un-hearts it.
  Future<void> toggleMessageReaction({
    required String connectionId,
    required String messageId,
    required bool addReaction,
  });

  /// This user's own bio/prompts/traits, visibility choices, and matching
  /// preferences (age range, max distance) — never what others see of them.
  Stream<ProfileDetails> watchProfileDetails();

  Future<void> saveProfileDetails(ProfileDetails details);

  /// Stores the device's current coordinates server-side for distance-based
  /// matching and "N miles away" — raw coordinates never come back to any
  /// client, including this one; see functions/index.js enrichSummaries.
  Future<void> updateLocation({required double lat, required double lng});

  /// City suggestions for [input] as the user types — proxied through
  /// placeAutocomplete so the Google Places API key never ships in the app.
  /// Returns an empty list for blank input rather than erroring.
  Future<List<PlaceSuggestion>> placeAutocomplete(String input);

  /// Resolves a [PlaceSuggestion.placeId] (from [placeAutocomplete]) to the
  /// city/state/coordinates this app actually stores.
  Future<ResolvedPlace> placeDetails(String placeId);

  /// Files a report against another user. Reports are deduplicated
  /// server-side by reporter, so repeat calls from this user overwrite
  /// rather than pile up. At 5 distinct reports the target's account is
  /// automatically placed under review.
  Future<void> reportUser({
    required String reportedUid,
    required String reason,
    String details,
  });

  /// Blocks another user — mutually invisible in Discover/Likes/Matches
  /// afterward, in both directions.
  Future<void> blockUser(String blockedUid);

  /// Registers this device's push token so Cloud Functions can notify it
  /// of new matches/likes/messages — see sendPushToUser in
  /// functions/index.js. Safe to call repeatedly with the same token.
  Future<void> registerFcmToken(String token);

  /// Called on sign-out so a shared/reused device stops receiving this
  /// account's pushes once someone else signs in on it.
  Future<void> unregisterFcmToken(String token);

  /// Whether the signed-in user is in adminConfig's reviewerUids list —
  /// gates whether the Review Queue is shown at all. Checked server-side on
  /// every review action too, so this is purely a UI-visibility check, not
  /// itself a security boundary.
  Future<bool> checkReviewerStatus();

  /// Every account currently flagged (auto-flagged or already
  /// suspended/banned) for a reviewer to act on. Throws if the caller isn't
  /// a reviewer.
  Future<List<ReviewEntry>> getReviewQueue();

  /// Applies a moderation decision to targetUid — 'permanent' ban,
  /// 'temporary' suspension (requires durationDays), or 'clear' to restore
  /// access. Throws if the caller isn't a reviewer.
  Future<void> banUser({
    required String targetUid,
    required String action,
    int? durationDays,
  });
}

class FirebaseAuthController extends AuthController {
  FirebaseAuthController({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _functions = functions ?? FirebaseFunctions.instance {
    _isSignedIn = _firebaseAuth.currentUser != null;
    _authSubscription = _firebaseAuth.authStateChanges().listen((user) {
      final signedIn = user != null;
      if (_isSignedIn == signedIn) return;

      _isSignedIn = signedIn;
      notifyListeners();
    });
  }

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;
  late final StreamSubscription<User?> _authSubscription;
  late bool _isSignedIn;

  @override
  bool get isSignedIn => _isSignedIn;

  @override
  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  @override
  Future<PhoneVerificationSession> sendPhoneVerificationCode({
    required String phoneNumber,
    int? forceResendingToken,
    FutureOr<void> Function()? onAutomaticVerification,
  }) async {
    final completer = Completer<PhoneVerificationSession>();

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      forceResendingToken: forceResendingToken,
      verificationCompleted: (credential) async {
        try {
          await _firebaseAuth.signInWithCredential(credential);
          await onAutomaticVerification?.call();

          if (!completer.isCompleted) {
            completer.complete(
              const PhoneVerificationSession.automaticallyVerified(),
            );
          }
        } catch (error, stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        }
      },
      verificationFailed: (error) {
        if (!completer.isCompleted) {
          completer.completeError(
            error,
            error.stackTrace ?? StackTrace.current,
          );
        }
      },
      codeSent: (verificationId, resendToken) {
        if (!completer.isCompleted) {
          completer.complete(
            PhoneVerificationSession(
              verificationId: verificationId,
              resendToken: resendToken,
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );

    return completer.future;
  }

  @override
  Future<void> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    await _firebaseAuth.signInWithCredential(credential);
  }

  @override
  Future<void> signOut() async {
    // Best-effort — a shared/reused device shouldn't keep getting this
    // account's pushes after sign-out, but a failure here must never block
    // the actual sign-out.
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await unregisterFcmToken(token);
    } catch (error) {
      debugPrint('Could not unregister push token on sign-out: $error');
    }

    await _firebaseAuth.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    final callable = _functions.httpsCallable('deleteAccount');
    await callable.call<Map<String, dynamic>>();
    await _firebaseAuth.signOut();
  }

  @override
  Stream<Map<String, dynamic>?> watchProfile() {
    final uid = currentUserId;
    if (uid == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  @override
  Future<ProfilePhoto> uploadProfilePhoto(File file) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('No signed-in user.');

    final extension = file.path.split('.').last.toLowerCase();
    final path =
        'profile_photos/$uid/${DateTime.now().microsecondsSinceEpoch}.$extension';

    final reference = _storage.ref().child(path);
    await reference.putFile(file);
    final url = await reference.getDownloadURL();
    return ProfilePhoto(url: url, storagePath: path);
  }

  @override
  Future<bool> moderatePhoto(String storagePath) async {
    final callable = _functions.httpsCallable('moderatePhoto');
    final result = await callable.call<Map<String, dynamic>>({
      'storagePath': storagePath,
    });
    return result.data['approved'] == true;
  }

  @override
  Future<void> deleteProfilePhoto(String storagePath) async {
    try {
      await _storage.ref().child(storagePath).delete();
    } catch (error) {
      // Already gone, or a transient error — either way don't block the
      // profile save over a file that's not there anymore.
      debugPrint('Could not delete profile photo $storagePath: $error');
    }
  }

  @override
  Future<void> saveProfile({
    required String name,
    required DateTime birthDate,
    required String gender,
    required String interestedIn,
    required List<ProfilePhoto> photos,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('No signed-in user.');

    final docRef = _firestore.collection('users').doc(uid);
    final existing = await docRef.get();

    await docRef.set({
      'name': name.trim(),
      'birthDate': Timestamp.fromDate(birthDate),
      'gender': gender,
      'interestedIn': interestedIn,
      'photos': photos.map((photo) => photo.toMap()).toList(),
      'primaryPhotoUrl': photos.isEmpty ? '' : photos.first.url,
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    try {
      await _firebaseAuth.currentUser?.updateDisplayName(name.trim());
    } catch (error) {
      debugPrint('Could not save Firebase display name: $error');
    }
  }

  @override
  Future<void> updateInterestedIn(String interestedIn) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('No signed-in user.');

    await _firestore.collection('users').doc(uid).set({
      'interestedIn': interestedIn,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setAccountPaused(bool paused) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('No signed-in user.');

    await _firestore.collection('users').doc(uid).set({
      'paused': paused,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setNotificationPrefs(Map<String, bool> prefs) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('No signed-in user.');

    await _firestore.collection('users').doc(uid).set({
      'notificationPrefs': prefs,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> submitPhotoForScoring(String storagePath) async {
    final callable = _functions.httpsCallable('scorePhoto');
    // The function writes the result straight to Firestore; callers watch
    // watchProfile() rather than relying on this return value.
    await callable.call<Map<String, dynamic>>({'storagePath': storagePath});
  }

  @override
  Future<DailyMatches> getDailyMatches() async {
    final callable = _functions.httpsCallable('getDailyMatches');
    final result = await callable.call<Map<dynamic, dynamic>>();
    return DailyMatches.fromMap(Map<String, dynamic>.from(result.data));
  }

  @override
  Future<bool> recordMatchDecision({
    required String candidateUid,
    required String decision,
  }) async {
    final callable = _functions.httpsCallable('recordMatchDecision');
    final result = await callable.call<Map<String, dynamic>>({
      'candidateUid': candidateUid,
      'decision': decision,
    });
    return result.data['status'] == 'matched';
  }

  @override
  Future<LikesResult> getLikes() async {
    final callable = _functions.httpsCallable('getLikes');
    final result = await callable.call<Map<dynamic, dynamic>>();
    return LikesResult.fromMap(Map<String, dynamic>.from(result.data));
  }

  @override
  Future<void> respondToLike({
    required String likerUid,
    required bool accept,
  }) async {
    final callable = _functions.httpsCallable('respondToLike');
    await callable.call<Map<String, dynamic>>({
      'likerUid': likerUid,
      'accept': accept,
    });
  }

  @override
  Future<void> cancelSentLike(String candidateUid) async {
    final callable = _functions.httpsCallable('cancelSentLike');
    await callable.call<Map<String, dynamic>>({'candidateUid': candidateUid});
  }

  @override
  Future<List<MatchConnection>> getMatches() async {
    final callable = _functions.httpsCallable('getMatches');
    final result = await callable.call<Map<dynamic, dynamic>>();
    final rawMatches = result.data['matches'];
    if (rawMatches is! List) return const [];

    return rawMatches.whereType<Map>().map(MatchConnection.fromMap).toList();
  }

  @override
  Stream<List<ChatMessageEntry>> watchMessages(String connectionId) {
    return _firestore
        .collection('connections')
        .doc(connectionId)
        .collection('messages')
        .orderBy('sentAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ChatMessageEntry(
                  id: doc.id,
                  senderId: (doc.data()['senderId'] ?? '').toString(),
                  text: (doc.data()['text'] ?? '').toString(),
                  sentAt: (doc.data()['sentAt'] as Timestamp?)?.toDate(),
                  heartedByUids: List<String>.from(
                    doc.data()['heartedByUids'] ?? const [],
                  ),
                ),
              )
              .toList(),
        );
  }

  @override
  Future<void> sendMessage({
    required String connectionId,
    required String text,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('No signed-in user.');

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _firestore
        .collection('connections')
        .doc(connectionId)
        .collection('messages')
        .add({
          'senderId': uid,
          'text': trimmed,
          'sentAt': FieldValue.serverTimestamp(),
        });
  }

  @override
  Future<void> toggleMessageReaction({
    required String connectionId,
    required String messageId,
    required bool addReaction,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('No signed-in user.');

    await _firestore
        .collection('connections')
        .doc(connectionId)
        .collection('messages')
        .doc(messageId)
        .update({
          'heartedByUids': addReaction
              ? FieldValue.arrayUnion([uid])
              : FieldValue.arrayRemove([uid]),
        });
  }

  @override
  Stream<ProfileDetails> watchProfileDetails() {
    final uid = currentUserId;
    if (uid == null) return Stream.value(const ProfileDetails());

    return _firestore
        .collection('profileDetails')
        .doc(uid)
        .snapshots()
        .map((snapshot) => ProfileDetails.fromMap(snapshot.data()));
  }

  @override
  Future<void> saveProfileDetails(ProfileDetails details) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('No signed-in user.');

    await _firestore.collection('profileDetails').doc(uid).set({
      ...details.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updateLocation({
    required double lat,
    required double lng,
  }) async {
    final callable = _functions.httpsCallable('updateLocation');
    await callable.call<Map<String, dynamic>>({'lat': lat, 'lng': lng});
  }

  @override
  Future<List<PlaceSuggestion>> placeAutocomplete(String input) async {
    final callable = _functions.httpsCallable('placeAutocomplete');
    final result = await callable.call<Map<String, dynamic>>({'input': input});
    final rawPredictions = result.data['predictions'];
    return rawPredictions is List
        ? rawPredictions.whereType<Map>().map(PlaceSuggestion.fromMap).toList()
        : const <PlaceSuggestion>[];
  }

  @override
  Future<ResolvedPlace> placeDetails(String placeId) async {
    final callable = _functions.httpsCallable('placeDetails');
    final result = await callable.call<Map<String, dynamic>>({
      'placeId': placeId,
    });
    return ResolvedPlace.fromMap(result.data);
  }

  @override
  Future<void> reportUser({
    required String reportedUid,
    required String reason,
    String details = '',
  }) async {
    final callable = _functions.httpsCallable('reportUser');
    await callable.call<Map<String, dynamic>>({
      'reportedUid': reportedUid,
      'reason': reason,
      'details': details,
    });
  }

  @override
  Future<void> blockUser(String blockedUid) async {
    final callable = _functions.httpsCallable('blockUser');
    await callable.call<Map<String, dynamic>>({'blockedUid': blockedUid});
  }

  @override
  Future<void> registerFcmToken(String token) async {
    final callable = _functions.httpsCallable('registerFcmToken');
    await callable.call<Map<String, dynamic>>({'token': token});
  }

  @override
  Future<void> unregisterFcmToken(String token) async {
    final callable = _functions.httpsCallable('unregisterFcmToken');
    await callable.call<Map<String, dynamic>>({'token': token});
  }

  @override
  Future<bool> checkReviewerStatus() async {
    final callable = _functions.httpsCallable('checkReviewerStatus');
    final result = await callable.call<Map<String, dynamic>>();
    return result.data['isReviewer'] == true;
  }

  @override
  Future<List<ReviewEntry>> getReviewQueue() async {
    final callable = _functions.httpsCallable('getReviewQueue');
    final result = await callable.call<Map<dynamic, dynamic>>();
    final rawEntries = result.data['entries'];
    if (rawEntries is! List) return const [];
    return rawEntries.whereType<Map>().map(ReviewEntry.fromMap).toList();
  }

  @override
  Future<void> banUser({
    required String targetUid,
    required String action,
    int? durationDays,
  }) async {
    final callable = _functions.httpsCallable('banUser');
    await callable.call<Map<String, dynamic>>({
      'targetUid': targetUid,
      'action': action,
      if (durationDays != null) 'durationDays': durationDays,
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}

String authErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'unauthenticated' => 'Please sign in again and retry.',
      'invalid-argument' => 'That couldn\'t be used. Please try again.',
      'not-found' => 'That couldn\'t be found. Please try again.',
      'failed-precondition' => error.message ?? 'That\'s no longer available.',
      _ => 'Something went wrong. Please try again.',
    };
  }

  if (error is! FirebaseAuthException) {
    return 'Something went wrong. Please try again.';
  }

  final firebaseMessage = (error.message ?? '').toLowerCase();
  if (firebaseMessage.contains('region enabled') ||
      firebaseMessage.contains('sms region') ||
      firebaseMessage.contains('sms unable to be sent')) {
    return 'SMS is not allowed for this phone number\'s region yet. '
        'Enable the region in Firebase Authentication settings.';
  }

  return switch (error.code) {
    'user-disabled' => 'This account has been disabled.',
    'invalid-credential' => 'That sign-in wasn\'t valid. Please try again.',
    'invalid-phone-number' => 'Enter a valid phone number.',
    'invalid-verification-code' => 'That verification code is incorrect.',
    'session-expired' => 'That code expired. Request a new one.',
    'too-many-requests' =>
      'Too many attempts were made. Please wait and try again.',
    'quota-exceeded' =>
      'The SMS limit has been reached. Please try again later.',
    'network-request-failed' => 'Check your internet connection and try again.',
    'operation-not-allowed' =>
      'This sign-in method has not been enabled in Firebase yet.',
    'app-not-authorized' || 'missing-client-identifier' =>
      'This app is not authorized for phone sign-in yet.',
    'captcha-check-failed' =>
      'App verification failed. Please try sending the code again.',
    _ => error.message ?? 'Authentication failed. Please try again.',
  };
}
