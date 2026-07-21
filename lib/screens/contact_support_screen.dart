import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// TODO: point this at wherever support requests should actually land.
const String kSupportEmail = 'support@looksmatch.app';

class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

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
        title: Text(
          'Contact Support',
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Need help with your account?',
              style: TextStyle(
                color: colors.headerPrimaryText,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Email us and we\'ll get back to you as soon as we can.',
              style: TextStyle(
                color: colors.headerSecondaryText,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.email_outlined, color: colors.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SelectableText(
                      kSupportEmail,
                      style: TextStyle(
                        color: colors.headerPrimaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
