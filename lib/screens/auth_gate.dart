import 'package:flutter/material.dart';

import '../services/auth_controller.dart';
import '../theme/app_theme.dart';
import 'auth/profile_setup_screen.dart';
import 'auth/welcome_screen.dart';
import 'home_shell.dart';

/// Gates the app behind [AuthController.isSignedIn] and, once signed in,
/// behind [AuthController.watchProfileCompleted] — nothing past this widget
/// (i.e. [HomeShell]) is reachable until both are satisfied.
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

        return StreamBuilder<bool>(
          stream: auth.watchProfileCompleted(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _GateLoadingScreen();
            }

            return snapshot.data == true
                ? HomeShell(onSignOut: auth.signOut)
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
