import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/sign_out_dialog.dart';
import 'contact_support_screen.dart';

/// Shown by AuthGate instead of HomeShell whenever accountStatus is set on
/// the signed-in user's profile. accountStatus/accountStatusMessage/
/// accountStatusReason/suspensionUntil/restrictionUntil are all written
/// only by Cloud Functions (see reportUser in functions/index.js and
/// firestore.rules) — a flagged or banned account can't clear its own
/// status client-side to get back in.
class AccountStatusScreen extends StatelessWidget {
  const AccountStatusScreen({
    super.key,
    required this.auth,
    required this.accountStatus,
    required this.message,
    required this.reason,
    this.suspensionUntil,
    this.restrictionUntil,
  });

  final AuthController auth;
  final String accountStatus;
  final String message;
  final String reason;
  final Timestamp? suspensionUntil;
  final Timestamp? restrictionUntil;

  String _title() {
    switch (accountStatus) {
      case 'under_review':
        return 'Account Under Review';
      case 'restricted':
        return 'Account Restricted';
      case 'suspended':
        return 'Account Suspended';
      case 'banned':
        return 'Account Banned';
      default:
        return 'Account Notice';
    }
  }

  String _defaultMessage() {
    switch (accountStatus) {
      case 'under_review':
        return 'Your account is currently under review by our team.';
      case 'restricted':
        return 'Some account features are temporarily restricted.';
      case 'suspended':
        return 'Your account is temporarily suspended.';
      case 'banned':
        return 'Your account has been banned from LooksMatch.';
      default:
        return 'There is an issue with your account.';
    }
  }

  String? _untilText() {
    final ts = suspensionUntil ?? restrictionUntil;
    if (ts == null) return null;

    final date = ts.toDate();
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final until = _untilText();

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.headerBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text(
          _title(),
          style: TextStyle(color: colors.headerPrimaryText, fontWeight: FontWeight.w900),
        ),
        iconTheme: IconThemeData(color: colors.headerIconColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.cardBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_person_rounded,
                  size: 52,
                  color: colors.deleteBackground,
                ),
                const SizedBox(height: 16),
                Text(
                  _title(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message.trim().isNotEmpty ? message : _defaultMessage(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.headerSecondaryText,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                if (reason.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Reason: $reason',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.headerPrimaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (until != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Ends on: $until',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.headerPrimaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContactSupportScreen()),
                  ),
                  icon: const Icon(Icons.contact_support_rounded),
                  label: const Text('Contact Support'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: colors.primaryButtonBackground,
                    foregroundColor: colors.primaryButtonText,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () =>
                      confirmSignOut(context: context, onSignOut: auth.signOut),
                  child: Text(
                    'Log Out',
                    style: TextStyle(
                      color: colors.headerSecondaryText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
