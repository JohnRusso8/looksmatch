import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:looksmatch/models/discover_candidate.dart';
import 'package:looksmatch/models/likes_and_matches.dart';
import 'package:looksmatch/models/profile_details.dart';
import 'package:looksmatch/models/review_entry.dart';
import 'package:looksmatch/screens/auth_gate.dart';
import 'package:looksmatch/services/auth_controller.dart';
import 'package:looksmatch/theme/app_theme.dart';

class _FakeAuthController extends AuthController {
  @override
  bool get isSignedIn => false;

  @override
  String? get currentUserId => null;

  @override
  Future<PhoneVerificationSession> sendPhoneVerificationCode({
    required String phoneNumber,
    int? forceResendingToken,
    FutureOr<void> Function()? onAutomaticVerification,
  }) async {
    return const PhoneVerificationSession(
      verificationId: 'test-verification-id',
      resendToken: null,
    );
  }

  @override
  Future<void> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  Stream<Map<String, dynamic>?> watchProfile() => Stream.value(null);

  @override
  Future<ProfilePhoto> uploadProfilePhoto(File file) async =>
      const ProfilePhoto(url: '', storagePath: '');

  @override
  Future<bool> moderatePhoto(String storagePath) async => true;

  @override
  Future<void> deleteProfilePhoto(String storagePath) async {}

  @override
  Future<void> saveProfile({
    required String name,
    required DateTime birthDate,
    required String gender,
    required String interestedIn,
    required List<ProfilePhoto> photos,
  }) async {}

  @override
  Future<void> updateInterestedIn(String interestedIn) async {}

  @override
  Future<void> setAccountPaused(bool paused) async {}

  @override
  Future<void> setNotificationPrefs(Map<String, bool> prefs) async {}

  @override
  Future<void> submitPhotoForScoring(String storagePath) async {}

  @override
  Future<DailyMatches> getDailyMatches() async =>
      const DailyMatches(candidates: [], decisions: {}, hasMore: false);

  @override
  Future<bool> recordMatchDecision({
    required String candidateUid,
    required String decision,
  }) async => false;

  @override
  Future<LikesResult> getLikes() async =>
      const LikesResult(received: [], sent: []);

  @override
  Future<void> respondToLike({
    required String likerUid,
    required bool accept,
  }) async {}

  @override
  Future<void> cancelSentLike(String candidateUid) async {}

  @override
  Future<List<MatchConnection>> getMatches() async => [];

  @override
  Stream<List<ChatMessageEntry>> watchMessages(String connectionId) =>
      Stream.value(const []);

  @override
  Future<void> sendMessage({
    required String connectionId,
    required String text,
  }) async {}

  @override
  Future<void> toggleMessageReaction({
    required String connectionId,
    required String messageId,
    required bool addReaction,
  }) async {}

  @override
  Stream<ProfileDetails> watchProfileDetails() =>
      Stream.value(const ProfileDetails());

  @override
  Future<void> saveProfileDetails(ProfileDetails details) async {}

  @override
  Future<void> updateLocation({
    required double lat,
    required double lng,
  }) async {}

  @override
  Future<List<PlaceSuggestion>> placeAutocomplete(String input) async => [];

  @override
  Future<ResolvedPlace> placeDetails(String placeId) async =>
      const ResolvedPlace(city: '', state: '', lat: 0, lng: 0);

  @override
  Future<void> reportUser({
    required String reportedUid,
    required String reason,
    String details = '',
  }) async {}

  @override
  Future<void> blockUser(String blockedUid) async {}

  @override
  Future<void> registerFcmToken(String token) async {}

  @override
  Future<void> unregisterFcmToken(String token) async {}

  @override
  Future<bool> checkReviewerStatus() async => false;

  @override
  Future<List<ReviewEntry>> getReviewQueue() async => [];

  @override
  Future<void> banUser({
    required String targetUid,
    required String action,
    int? durationDays,
  }) async {}
}

void main() {
  testWidgets('LooksMatch app launches to the account gate', (
    WidgetTester tester,
  ) async {
    final auth = _FakeAuthController();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: AuthGate(auth: auth),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LooksMatch'), findsOneWidget);
    expect(find.text('Continue with Phone'), findsOneWidget);
    expect(find.text('Discover'), findsNothing);
  });
}
