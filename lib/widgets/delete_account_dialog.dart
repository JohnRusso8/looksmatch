import 'package:flutter/material.dart';

import '../services/auth_controller.dart';
import '../theme/app_theme.dart';

Future<void> confirmDeleteAccount({
  required BuildContext context,
  required Future<void> Function() onDelete,
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
          'Delete your account?',
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          'This permanently deletes your profile, photos, matches, and '
          'messages. This can\'t be undone.',
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
              'Delete Account',
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
    await onDelete();
    if (!context.mounted) return;
    // Same reasoning as confirmSignOut — AuthGate swapping to Welcome
    // underneath doesn't pop anything stacked on top of it.
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
