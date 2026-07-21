import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Renders a static legal document (Privacy Policy, Terms of Service) as
/// plain paragraphs. Placeholder copy only — see kPrivacyPolicyText /
/// kTermsOfServiceText below.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.updatedLabel,
    required this.body,
  });

  final String title;
  final String updatedLabel;
  final String body;

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
          title,
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Text(
              updatedLabel,
              style: TextStyle(
                color: colors.headerSecondaryText,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              body,
              style: TextStyle(
                color: colors.headerPrimaryText,
                fontSize: 14.5,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const String kPrivacyPolicyUpdatedLabel = 'Placeholder — not yet reviewed by counsel';

const String kPrivacyPolicyText = '''
This Privacy Policy describes how LooksMatch collects, uses, and protects your information.

Information We Collect
We collect the information you provide directly, including your name, birth date, phone number, photos, and any profile details, prompts, and preferences you choose to add. We also collect your approximate location (to show distance to other members) and usage data such as who you view, like, or match with.

How We Use Your Information
We use your information to operate the matching and Discover features, to keep the app safe (including reviewing reports and blocks), to send you push notifications you've opted into, and to improve the service.

Sharing
We do not sell your personal information. Limited data is shared with service providers (such as our cloud hosting and analytics providers) strictly to operate the app.

Your Choices
You can edit or delete your profile information, control your notification preferences, pause your account, or permanently delete your account at any time from Settings.

Data Retention
When you delete your account, we remove your profile, photos, matches, and messages from our active systems.

Contact
Questions about this policy can be sent to the support address listed in Contact Support.
''';

const String kTermsOfServiceUpdatedLabel = 'Placeholder — not yet reviewed by counsel';

const String kTermsOfServiceText = '''
These Terms of Service govern your use of LooksMatch.

Eligibility
You must be at least 18 years old and able to form a binding contract to use LooksMatch. Accounts are verified via phone number, and one phone number may be linked to only one account.

Your Conduct
You agree not to harass, threaten, or misrepresent yourself to other members, and to comply with all applicable laws. Accounts found violating these terms may be suspended or permanently banned, at our discretion, following our review process.

Content
You retain ownership of the photos and content you upload, but grant LooksMatch a license to display it to other members as part of the service.

Termination
You may delete your account at any time. We may suspend or terminate accounts that violate these terms or that we determine pose a safety risk to other members.

Disclaimers
LooksMatch is provided "as is." We do not guarantee matches, compatibility, or the accuracy of information other members provide about themselves.

Changes
We may update these terms from time to time. Continued use of the app after changes take effect constitutes acceptance of the updated terms.
''';
