import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

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

  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  });

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

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

  /// Whether the signed-in user has finished the required profile fields
  /// (name, birth date, gender, interested-in, at least one photo). Drives
  /// whether [AuthGate] shows profile setup or the home screen.
  Stream<bool> watchProfileCompleted();

  Future<String> uploadProfilePhoto(File file);

  Future<void> saveProfile({
    required String name,
    required DateTime birthDate,
    required String gender,
    required String interestedIn,
    required List<String> photoUrls,
  });
}

class FirebaseAuthController extends AuthController {
  FirebaseAuthController({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance {
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
  late final StreamSubscription<User?> _authSubscription;
  late bool _isSignedIn;

  @override
  bool get isSignedIn => _isSignedIn;

  @override
  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  @override
  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  }) async {
    await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

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
  Future<void> signOut() => _firebaseAuth.signOut();

  @override
  Stream<bool> watchProfileCompleted() {
    final uid = currentUserId;
    if (uid == null) return Stream.value(false);

    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.data()?['profileCompleted'] == true);
  }

  @override
  Future<String> uploadProfilePhoto(File file) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('No signed-in user.');

    final extension = file.path.split('.').last.toLowerCase();
    final path =
        'profile_photos/$uid/${DateTime.now().microsecondsSinceEpoch}.$extension';

    final reference = _storage.ref().child(path);
    await reference.putFile(file);
    return reference.getDownloadURL();
  }

  @override
  Future<void> saveProfile({
    required String name,
    required DateTime birthDate,
    required String gender,
    required String interestedIn,
    required List<String> photoUrls,
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
      'photoUrls': photoUrls,
      'primaryPhotoUrl': photoUrls.isEmpty ? '' : photoUrls.first,
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
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}

String authErrorMessage(Object error) {
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
    'email-already-in-use' =>
      'An account already exists for that email address.',
    'invalid-email' => 'Enter a valid email address.',
    'weak-password' => 'Use a stronger password and try again.',
    'user-disabled' => 'This account has been disabled.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'The email or password is incorrect.',
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
