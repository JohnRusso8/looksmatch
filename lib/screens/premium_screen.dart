import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Placeholder landing page for a future paid tier — no in-app purchase is
/// wired up yet, this just gives Settings somewhere to send people who tap
/// "Subscribe" today.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.headerBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: colors.headerIconColor),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.scoreBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome_rounded, size: 38, color: colors.accent),
            ),
            const SizedBox(height: 22),
            Text(
              'LooksMatch Premium',
              style: TextStyle(
                color: colors.headerPrimaryText,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Premium is coming soon. We\'ll let you know as soon as it\'s ready.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.headerSecondaryText,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
