import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:looksmatch/screens/auth_gate.dart';
import 'package:looksmatch/services/auth_controller.dart';
import 'package:looksmatch/theme/app_theme.dart';

class _FakeAuthController extends AuthController {
  @override
  bool get isSignedIn => false;

  @override
  String? get currentUserId => null;

  @override
  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {}

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
  Stream<bool> watchProfileCompleted() => Stream.value(false);

  @override
  Future<String> uploadProfilePhoto(File file) async => '';

  @override
  Future<void> saveProfile({
    required String name,
    required DateTime birthDate,
    required String gender,
    required String interestedIn,
    required List<String> photoUrls,
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
    expect(find.text('Continue with Email'), findsOneWidget);
    expect(find.text('Discover'), findsNothing);
  });
}
