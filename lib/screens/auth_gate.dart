import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/auth_controller.dart';
import '../theme/app_theme.dart';
import 'account_status_screen.dart';
import 'auth/profile_setup_screen.dart';
import 'auth/welcome_screen.dart';
import 'home_shell.dart';

/// Gates the app behind [AuthController.isSignedIn] and, once signed in,
/// behind profile completion and account status — nothing past this widget
/// (i.e. [HomeShell]) is reachable until all three are satisfied. A flagged
/// or banned account (accountStatus set — see reportUser in
/// functions/index.js) sees [AccountStatusScreen] instead, checked ahead of
/// profile completion so it applies even mid-onboarding.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        if (!auth.isSignedIn) {
          return WelcomeScreen(auth: auth);
        }

        return StreamBuilder<Map<String, dynamic>?>(
          stream: auth.watchProfile(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _GateLoadingScreen();
            }

            final profile = snapshot.data;
            final accountStatus = profile?['accountStatus'] as String?;
            final suspensionUntil = profile?['suspensionUntil'] as Timestamp?;

            // A timed suspension lifts itself once it passes — no reviewer
            // action needed to restore access. The Firestore fields are
            // left in place (harmless) rather than cleared client-side;
            // banUser's Admin SDK write is the only thing allowed to touch
            // accountStatus anyway.
            final suspensionExpired = accountStatus == 'suspended' &&
                suspensionUntil != null &&
                suspensionUntil.toDate().isBefore(DateTime.now());

            if (accountStatus != null && accountStatus.isNotEmpty && !suspensionExpired) {
              return AccountStatusScreen(
                auth: auth,
                accountStatus: accountStatus,
                message: (profile?['accountStatusMessage'] ?? '').toString(),
                reason: (profile?['accountStatusReason'] ?? '').toString(),
                suspensionUntil: suspensionUntil,
                restrictionUntil: profile?['restrictionUntil'] as Timestamp?,
              );
            }

            return profile?['profileCompleted'] == true
                ? HomeShell(auth: auth)
                : ProfileSetupScreen(auth: auth);
          },
        );
      },
    );
  }
}

class _GateLoadingScreen extends StatelessWidget {
  const _GateLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      body: Center(
        child: CircularProgressIndicator(color: colors.accent),
      ),
    );
  }
}
