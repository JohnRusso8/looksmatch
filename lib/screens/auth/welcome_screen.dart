import 'package:flutter/material.dart';

import '../../services/auth_controller.dart';
import '../../theme/app_theme.dart';
import 'phone_auth_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: colors.scoreBackground,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.accent.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: colors.accent,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'LooksMatch',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.headerPrimaryText,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Curated matches based on your LooksMatch score. No swiping.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.headerSecondaryText,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(flex: 4),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PhoneAuthScreen(auth: auth),
                  ),
                ),
                icon: const Icon(Icons.phone_iphone_rounded),
                label: const Text('Continue with Phone'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primaryButtonBackground,
                  foregroundColor: colors.primaryButtonText,
                  minimumSize: const Size.fromHeight(52),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'By continuing, you agree to our Terms of Service and Privacy Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.headerSecondaryText,
                  fontSize: 11,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
