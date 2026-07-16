import 'package:flutter/material.dart';

import '../services/auth_controller.dart';
import 'auth/welcome_screen.dart';
import 'home_shell.dart';

/// Gates the app behind [AuthController.isSignedIn] — nothing past this
/// widget is reachable until sign-in or account creation completes.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        return auth.isSignedIn
            ? HomeShell(onSignOut: auth.signOut)
            : WelcomeScreen(auth: auth);
      },
    );
  }
}
