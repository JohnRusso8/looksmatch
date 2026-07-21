import 'package:flutter/material.dart';

import '../models/discover_candidate.dart';
import '../models/profile_details.dart';
import '../models/profile_extras.dart';
import '../services/auth_controller.dart';
import '../services/profile_cache.dart';
import '../theme/app_theme.dart';
import 'admin_review_screen.dart';
import 'edit_profile_screen.dart';
import 'match_profile_screen.dart';
import 'preferences_screen.dart';
import 'scoring_screen.dart';
import 'settings_screen.dart';

DateTime? _parseBirthDate(dynamic value) {
  if (value == null) return null;
  // Firestore Timestamp — avoid importing cloud_firestore here just for
  // this by duck-typing the toDate() call, same as EditProfileScreen.
  try {
    return (value as dynamic).toDate() as DateTime;
  } catch (_) {
    return null;
  }
}

int? _calculateAge(DateTime? birthDate) {
  if (birthDate == null) return null;
  final now = DateTime.now();
  var age = now.year - birthDate.year;
  final hadBirthdayThisYear =
      now.month > birthDate.month ||
      (now.month == birthDate.month && now.day >= birthDate.day);
  if (!hadBirthdayThisYear) age--;
  return age;
}

/// Builds the same shape of candidate a match would see of you, so the
/// Profile tab can render through the exact same ProfileContentView used
/// for everyone else's profile — "how others see you" and "how you see
/// them" can never silently drift apart. Built entirely from data already
/// in the cache; hobbyPhotoUrl/foodPhotoUrl are computed locally from the
/// raw photos array instead of waiting on a server round-trip, since it's
/// the same data summarizeUserDoc would derive server-side for anyone else.
DiscoverCandidate _selfPreviewCandidate(
  AuthController auth,
  Map<String, dynamic>? profile,
  ProfileDetails details,
) {
  final rawPhotos = profile?['photos'];
  final photos = rawPhotos is List
      ? rawPhotos.whereType<Map>().toList()
      : const <Map>[];
  final photoUrls = photos
      .map((photo) => (photo['url'] ?? '').toString())
      .where((url) => url.isNotEmpty)
      .toList();

  String? categoryPhotoUrl(String category) {
    for (final photo in photos) {
      if (photo['category'] == category) {
        final url = (photo['url'] ?? '').toString();
        if (url.isNotEmpty) return url;
      }
    }
    return null;
  }

  return DiscoverCandidate(
    uid: auth.currentUserId ?? '',
    name: (profile?['name'] ?? '').toString(),
    age: _calculateAge(_parseBirthDate(profile?['birthDate'])),
    primaryPhotoUrl: photoUrls.isEmpty ? '' : photoUrls.first,
    photoUrls: photoUrls,
    extras: ProfileExtras(
      bio: details.bio,
      prompts: details.prompts,
      interests: details.interests,
      values: details.values,
      musicGenres: details.musicGenres,
      favoriteFoods: details.favoriteFoods,
      ethnicities: details.ethnicities,
      relationshipType: details.relationshipType,
      datingIntention: details.datingIntention,
      heightInches: details.heightInches,
      drinking: details.drinking,
      smoking: details.smoking,
      educationLevel: details.educationLevel,
      familyPlans: details.familyPlans,
      college: details.college,
      hobbyPhotoUrl: categoryPhotoUrl('hobby'),
      foodPhotoUrl: categoryPhotoUrl('food'),
    ),
  );
}

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
            tooltip: 'Edit Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditProfileScreen(
                  auth: auth,
                  profileCache: widget.profileCache,
                ),
              ),
            ),
            icon: Icon(Icons.edit_outlined, color: colors.headerIconColor),
          ),
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
          final details = widget.profileCache.details;
          final status = profile?['scoringStatus'] as String?;
          final candidate = _selfPreviewCandidate(auth, profile, details);

          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
            children: [
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PreferencesScreen(
                        auth: auth,
                        profileCache: widget.profileCache,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: colors.accent,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        details.city.isNotEmpty && details.state != null
                            ? '${details.city}, ${details.state}'
                            : 'Set your location',
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // This is exactly what a match sees of you — same
              // ProfileContentView as MatchProfileScreen, with an empty
              // ProfileDetails() so nothing renders as "matched" (comparing
              // yourself to yourself isn't meaningful). Tap the pencil icon
              // in the app bar to edit.
              ProfileContentView(
                candidate: candidate,
                myDetails: const ProfileDetails(),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ScoreCard(
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
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
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
                          debugPrint(
                            'checkReviewerStatus failed: ${snapshot.error}',
                          );
                          return const SizedBox.shrink();
                        }
                        if (snapshot.data != true)
                          return const SizedBox.shrink();
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
                ),
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
