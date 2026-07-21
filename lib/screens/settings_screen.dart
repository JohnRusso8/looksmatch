import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';

import '../services/auth_controller.dart';
import '../services/profile_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/delete_account_dialog.dart';
import '../widgets/sign_out_dialog.dart';
import 'legal_document_screen.dart';
import 'premium_screen.dart';

/// Notification categories a user can toggle, in display order. Keys match
/// NOTIFICATION_CATEGORIES in functions/index.js exactly — sendPushToUser
/// reads notificationPrefs[category] server-side using these same strings.
const List<(String key, String label)> _kNotificationCategories = [
  ('like', 'New Likes'),
  ('match', 'New Matches'),
  ('message', 'Messages'),
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.auth,
    required this.profileCache,
  });

  final AuthController auth;
  final ProfileCache profileCache;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AuthController get auth => widget.auth;
  ProfileCache get _cache => widget.profileCache;

  // Seeded synchronously from the cache — by the time this screen is
  // reachable (via the Profile tab), HomeShell has already been warming
  // the cache, so this is a real value, not a placeholder, in the
  // overwhelming majority of opens. See ProfileCache for why.
  late bool _paused = _cache.profile?['paused'] == true;
  late Map<String, bool> _prefs = _prefsFromProfile(_cache.profile);

  static Map<String, bool> _prefsFromProfile(Map<String, dynamic>? profile) {
    final rawPrefs = profile?['notificationPrefs'];
    final storedPrefs = rawPrefs is Map
        ? rawPrefs.map((key, value) => MapEntry(key.toString(), value == true))
        : const <String, bool>{};
    // Missing keys default to enabled — matches sendPushToUser's server-side
    // default (see functions/index.js), so an unset key never reads as muted.
    return {
      for (final c in _kNotificationCategories) c.$1: storedPrefs[c.$1] ?? true,
    };
  }

  @override
  void initState() {
    super.initState();
    // Covers only the rare cold case where this screen somehow opens before
    // the cache's first emission lands — corrects the optimistic defaults
    // above once the real value arrives, instead of blocking on a spinner.
    if (!_cache.hasProfile) {
      _cache.addListener(_onCacheReady);
    }
  }

  void _onCacheReady() {
    if (!_cache.hasProfile) return;
    _cache.removeListener(_onCacheReady);
    if (!mounted) return;
    setState(() {
      _paused = _cache.profile?['paused'] == true;
      _prefs = _prefsFromProfile(_cache.profile);
    });
  }

  @override
  void dispose() {
    _cache.removeListener(_onCacheReady);
    super.dispose();
  }

  Future<void> _setPaused(bool value) async {
    final previous = _paused;
    setState(() => _paused = value);
    try {
      await auth.setAccountPaused(value);
    } catch (error) {
      if (!mounted) return;
      setState(() => _paused = previous);
      _showMessage('Couldn\'t update that. Please try again.');
    }
  }

  Future<void> _setPrefs(Map<String, bool> next) async {
    final previous = _prefs;
    setState(() => _prefs = next);
    try {
      await auth.setNotificationPrefs(next);
    } catch (error) {
      if (!mounted) return;
      setState(() => _prefs = previous);
      _showMessage('Couldn\'t update that. Please try again.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
  }

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
          'Settings',
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            _groupLabel(colors, 'Account'),
            const SizedBox(height: 10),
            _switchTile(
              colors: colors,
              icon: Icons.pause_circle_outline_rounded,
              label: 'Pause Account',
              subtitle:
                  'Hide your profile from Discover. Your matches and '
                  'messages stay active.',
              value: _paused,
              onChanged: _setPaused,
            ),
            const SizedBox(height: 4),
            _actionTile(
              colors: colors,
              icon: Icons.logout_rounded,
              label: 'Log Out',
              destructive: true,
              onTap: () =>
                  confirmSignOut(context: context, onSignOut: auth.signOut),
            ),
            _actionTile(
              colors: colors,
              icon: Icons.delete_forever_rounded,
              label: 'Delete Account',
              destructive: true,
              onTap: () => confirmDeleteAccount(
                context: context,
                onDelete: auth.deleteAccount,
              ),
            ),
            const SizedBox(height: 24),
            _groupLabel(colors, 'Notifications'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _quickActionButton(
                    colors: colors,
                    label: 'Enable All',
                    onTap: () => _setPrefs({
                      for (final c in _kNotificationCategories) c.$1: true,
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quickActionButton(
                    colors: colors,
                    label: 'Mute All',
                    onTap: () => _setPrefs({
                      for (final c in _kNotificationCategories) c.$1: false,
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final category in _kNotificationCategories)
              _switchTile(
                colors: colors,
                icon: switch (category.$1) {
                  'like' => Icons.favorite_border_rounded,
                  'match' => Icons.favorite_rounded,
                  _ => Icons.chat_bubble_outline_rounded,
                },
                label: category.$2,
                value: _prefs[category.$1] ?? true,
                onChanged: (v) => _setPrefs({..._prefs, category.$1: v}),
              ),
            const SizedBox(height: 24),
            _groupLabel(colors, 'Premium'),
            const SizedBox(height: 10),
            _navTile(
              colors: colors,
              icon: Icons.auto_awesome_rounded,
              label: 'Subscribe to LooksMatch',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              ),
            ),
            const SizedBox(height: 24),
            _groupLabel(colors, 'Preferences'),
            const SizedBox(height: 10),
            _navTile(
              colors: colors,
              icon: Icons.language_rounded,
              label: 'Change Language',
              onTap: () => AppSettings.openAppSettings(),
            ),
            const SizedBox(height: 24),
            _groupLabel(colors, 'Legal'),
            const SizedBox(height: 10),
            _navTile(
              colors: colors,
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LegalDocumentScreen(
                    title: 'Privacy Policy',
                    updatedLabel: kPrivacyPolicyUpdatedLabel,
                    body: kPrivacyPolicyText,
                  ),
                ),
              ),
            ),
            _navTile(
              colors: colors,
              icon: Icons.description_outlined,
              label: 'Terms of Service',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LegalDocumentScreen(
                    title: 'Terms of Service',
                    updatedLabel: kTermsOfServiceUpdatedLabel,
                    body: kTermsOfServiceText,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupLabel(LooksMatchColors colors, String label) {
    return Text(
      label,
      style: TextStyle(
        color: colors.headerPrimaryText,
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _quickActionButton({
    required LooksMatchColors colors,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.scoreBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: colors.accent,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _switchTile({
    required LooksMatchColors colors,
    required IconData icon,
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.scoreBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: colors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: colors.headerPrimaryText,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.headerSecondaryText,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: colors.accent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _navTile({
    required LooksMatchColors colors,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.scoreBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: colors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colors.headerPrimaryText,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.headerSecondaryText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionTile({
    required LooksMatchColors colors,
    required IconData icon,
    required String label,
    bool destructive = false,
    required VoidCallback onTap,
  }) {
    final color = destructive ? colors.deleteBackground : colors.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: destructive
              ? colors.deleteBackground.withValues(alpha: 0.35)
              : colors.cardBorder,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: TextStyle(
            color: destructive
                ? colors.deleteBackground
                : colors.headerPrimaryText,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
