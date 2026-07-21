import 'package:flutter/material.dart';

import '../services/auth_controller.dart';
import '../services/profile_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/network_avatar.dart';
import 'admin_review_screen.dart';
import 'edit_profile_screen.dart';
import 'preferences_screen.dart';
import 'scoring_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.auth,
    required this.profileCache,
  });

  final AuthController auth;
  final ProfileCache profileCache;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AuthController get auth => widget.auth;

  // Checked once per mount rather than inline in build() — this screen's
  // body rebuilds on every watchProfile() emission (a live Firestore
  // listener), and re-firing the reviewer-status call on every single one
  // of those meant the FutureBuilder could spend most of its time stuck
  // back in the "waiting" state, hiding the tile, instead of ever settling
  // long enough to show it.
  late final Future<bool> _reviewerStatus = auth.checkReviewerStatus();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.headerBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Text(
          'Profile',
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  auth: auth,
                  profileCache: widget.profileCache,
                ),
              ),
            ),
            icon: Icon(Icons.settings_outlined, color: colors.headerIconColor),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.profileCache,
        builder: (context, _) {
          final profile = widget.profileCache.profile;
          final name = (profile?['name'] as String?)?.trim();
          final rawPhotos = profile?['photos'];
          final photos = rawPhotos is List
              ? rawPhotos.whereType<Map>().toList()
              : const <Map>[];
          final primaryPhotoUrl = photos.isEmpty
              ? ''
              : (photos.first['url'] ?? '').toString();
          final status = profile?['scoringStatus'] as String?;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(
                        auth: auth,
                        profileCache: widget.profileCache,
                      ),
                    ),
                  ),
                  child: Stack(
                    children: [
                      if (primaryPhotoUrl.isEmpty)
                        CircleAvatar(
                          radius: 56,
                          backgroundColor: colors.inputBackground,
                          child: Icon(
                            Icons.person_rounded,
                            color: colors.headerSecondaryText,
                            size: 48,
                          ),
                        )
                      else
                        NetworkAvatar(url: primaryPhotoUrl, radius: 56),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colors.primaryButtonBackground,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.pageBackground,
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            color: colors.primaryButtonText,
                            size: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  (name == null || name.isEmpty) ? 'You' : name,
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Complete your profile to start getting matched.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.headerSecondaryText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _ScoreCard(
                colors: colors,
                status: status,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScoringScreen(
                      auth: auth,
                      profileCache: widget.profileCache,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Photos',
                style: TextStyle(
                  color: colors.headerPrimaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: photos.length + 1,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 9,
                  mainAxisSpacing: 9,
                  childAspectRatio: 0.78,
                ),
                itemBuilder: (context, index) {
                  if (index == photos.length) {
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfileScreen(
                            auth: auth,
                            profileCache: widget.profileCache,
                          ),
                        ),
                      ),
                      child: DottedAddTile(colors: colors),
                    );
                  }
                  final url = (photos[index]['url'] ?? '').toString();
                  return NetworkPhoto(url: url, borderRadius: 16);
                },
              ),
              const SizedBox(height: 24),
              _menuTile(
                colors: colors,
                icon: Icons.person_outline_rounded,
                label: 'Edit Profile',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(
                      auth: auth,
                      profileCache: widget.profileCache,
                    ),
                  ),
                ),
              ),
              _menuTile(
                colors: colors,
                icon: Icons.tune_rounded,
                label: 'Match Preferences',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PreferencesScreen(
                      auth: auth,
                      profileCache: widget.profileCache,
                    ),
                  ),
                ),
              ),
              _menuTile(
                colors: colors,
                icon: Icons.shield_outlined,
                label: 'Privacy & Safety',
              ),
              _menuTile(
                colors: colors,
                icon: Icons.help_outline_rounded,
                label: 'Help & Support',
              ),
              // Only reviewers (adminConfig.reviewerUids — see
              // functions/index.js) see this at all; every action inside
              // the screen it opens is re-verified server-side regardless.
              FutureBuilder<bool>(
                future: _reviewerStatus,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    // Surfaced rather than silently hidden — a failed
                    // reviewer check used to look identical to "not a
                    // reviewer", which made this impossible to debug from
                    // the UI alone.
                    debugPrint('checkReviewerStatus failed: ${snapshot.error}');
                    return const SizedBox.shrink();
                  }
                  if (snapshot.data != true) return const SizedBox.shrink();
                  return _menuTile(
                    colors: colors,
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Review Queue',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminReviewScreen(auth: auth),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _menuTile({
    required LooksMatchColors colors,
    required IconData icon,
    required String label,
    bool destructive = false,
    VoidCallback? onTap,
  }) {
    final color = destructive ? colors.deleteBackground : colors.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: destructive
              ? colors.deleteBackground.withOpacity(0.35)
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
        trailing: destructive
            ? null
            : Icon(
                Icons.chevron_right_rounded,
                color: colors.headerSecondaryText,
              ),
        onTap: onTap ?? () {},
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.colors,
    required this.status,
    required this.onTap,
  });

  final LooksMatchColors colors;
  final String? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String subtitle;
    final Widget badge;

    // Deliberately no number anywhere here — the score itself never
    // reaches the client, only this status flag. Matching happens
    // server-side; this card is just an entry point into ScoringScreen.
    if (status == 'scored') {
      title = 'You\'re Being Matched';
      subtitle = 'We\'re using your photo to find your best matches.';
      badge = Icon(Icons.favorite_rounded, color: colors.accent);
    } else if (status == 'rejected') {
      title = 'We couldn\'t use your last photo';
      subtitle = 'Tap to try a different photo.';
      badge = Icon(Icons.priority_high_rounded, color: colors.deleteBackground);
    } else {
      title = 'Get Discovered';
      subtitle = 'Submit a photo so we can start finding your matches.';
      badge = Icon(Icons.auto_awesome_rounded, color: colors.accent);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.scoreBackground,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.accent.withOpacity(0.30)),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.pageBackground,
                  border: Border.all(color: colors.accent, width: 2.5),
                ),
                child: badge,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.headerPrimaryText,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
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
    );
  }
}

class DottedAddTile extends StatelessWidget {
  const DottedAddTile({super.key, required this.colors});

  final LooksMatchColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withOpacity(0.45), width: 1.4),
      ),
      child: Icon(Icons.add_a_photo_outlined, color: colors.accent),
    );
  }
}
