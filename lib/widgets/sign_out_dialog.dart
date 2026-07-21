import 'package:flutter/material.dart';

import '../services/auth_controller.dart';
import '../theme/app_theme.dart';

Future<void> confirmSignOut({
  required BuildContext context,
  required Future<void> Function() onSignOut,
}) async {
  final colors = context.colors;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: colors.dialogBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Log out?',
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          'You\'ll need to sign back in to continue.',
          style: TextStyle(
            color: colors.headerSecondaryText,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: colors.headerSecondaryText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Log Out',
              style: TextStyle(
                color: colors.deleteBackground,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await onSignOut();
    if (!context.mounted) return;
    // Signing out swaps what AuthGate renders underneath (Welcome instead
    // of HomeShell), but that alone doesn't clear whatever's been pushed
    // on top of it (Settings, Preferences, etc.) — without this, the user
    // stays stuck looking at the screen they signed out from.
    Navigator.of(context).popUntil((route) => route.isFirst);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            authErrorMessage(error),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
  }
}
