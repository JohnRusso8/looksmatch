import 'package:flutter/material.dart';

import '../models/discover_candidate.dart';
import '../models/profile_details.dart';
import '../models/profile_extras.dart';
import '../services/auth_controller.dart';
import '../services/profile_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/network_avatar.dart';

/// Must match REPORT_REASONS in functions/index.js — the server rejects
/// any reason string outside this set.
const List<String> kReportReasons = [
  'Inappropriate photos',
  'Harassment or abuse',
  'Fake profile',
  'Spam or scam',
  'Underage user',
  'Other',
];

void _showSnack(BuildContext context, String message) {
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

/// A single fact for the horizontal stat strip just under the photo —
/// LooksMatch's own take on the "basics" row every dating app shows, styled
/// as small vertical cards rather than a plain scrolling list.
class _StatItem {
  const _StatItem(this.icon, this.label);

  final IconData icon;
  final String label;
}

List<_StatItem> _statItems(ProfileExtras extras) {
  return [
    if (extras.heightInches != null)
      _StatItem(Icons.height_rounded, extras.heightLabel),
    if (extras.relationshipType != null)
      _StatItem(Icons.favorite_border_rounded, extras.relationshipType!),
    if (extras.datingIntention != null)
      _StatItem(Icons.explore_outlined, extras.datingIntention!),
    if (extras.educationLevel != null)
      _StatItem(Icons.school_outlined, extras.educationLevel!),
    if (extras.college?.isNotEmpty ?? false)
      _StatItem(Icons.account_balance_outlined, extras.college!),
    if (extras.drinking != null)
      _StatItem(Icons.local_bar_outlined, extras.drinking!),
    if (extras.smoking != null)
      _StatItem(Icons.smoking_rooms_outlined, extras.smoking!),
  ];
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.colors, required this.items});

  final LooksMatchColors colors;
  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            width: 82,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: colors.scoreBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.accent.withOpacity(0.22)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, color: colors.accent, size: 20),
                const SizedBox(height: 8),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A single chip within one interests/values/music/food category. `matched`
/// means the viewer's own profile has this same item — those chips render
/// filled instead of outlined so shared ground stands out at a glance.
class _InfoChip {
  const _InfoChip(this.label, {required this.matched});

  final String label;
  final bool matched;
}

List<_InfoChip> _categoryChips(List<String> theirs, List<String> mine) {
  final mineSet = mine.map((i) => i.toLowerCase()).toSet();
  return theirs
      .map(
        (item) =>
            _InfoChip(item, matched: mineSet.contains(item.toLowerCase())),
      )
      .toList();
}

/// One category's worth of chips — a small caption label above its own
/// Wrap, rather than every category dumped into one undifferentiated pile.
class _InfoCategorySection extends StatelessWidget {
  const _InfoCategorySection({
    required this.colors,
    required this.label,
    required this.icon,
    required this.chips,
  });

  final LooksMatchColors colors;
  final String label;
  final IconData icon;
  final List<_InfoChip> chips;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.headerSecondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map(
                  (chip) =>
                      _InfoChipPill(colors: colors, icon: icon, chip: chip),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _InfoChipPill extends StatelessWidget {
  const _InfoChipPill({
    required this.colors,
    required this.icon,
    required this.chip,
  });

  final LooksMatchColors colors;
  final IconData icon;
  final _InfoChip chip;

  @override
  Widget build(BuildContext context) {
    final matched = chip.matched;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: matched ? colors.accent : colors.chipUnselectedBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: matched ? colors.accent : colors.chipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: matched ? colors.primaryButtonText : colors.accent,
          ),
          const SizedBox(width: 6),
          Text(
            chip.label,
            style: TextStyle(
              color: matched
                  ? colors.primaryButtonText
                  : colors.chipUnselectedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tagged "hobby" or "food" photo, called out as its own small card
/// (Pinterest-style visual variety) instead of just blending into the main
/// photo gallery like every other photo.
class _MomentCard extends StatelessWidget {
  const _MomentCard({
    required this.colors,
    required this.url,
    required this.icon,
    required this.label,
  });

  final LooksMatchColors colors;
  final String url;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            NetworkPhoto(url: url),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 22, 10, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.68),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The actual profile content — photo header, stat strip, compatibility
/// card (when present), bio, hobby/food moment cards, categorized chips,
/// and prompts. Shared between [MatchProfileScreen] (viewing someone else)
/// and ProfileScreen's own self-preview, so "how others see your profile"
/// and "how you see theirs" can never silently drift apart.
class ProfileContentView extends StatelessWidget {
  const ProfileContentView({
    super.key,
    required this.candidate,
    required this.myDetails,
  });

  final DiscoverCandidate candidate;

  /// Used only to highlight which of the candidate's interests/values/
  /// music/food overlap with these — pass an empty ProfileDetails() to
  /// suppress highlighting entirely (e.g. previewing your own profile,
  /// where "matching yourself" isn't meaningful).
  final ProfileDetails myDetails;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 4 / 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _PhotoGallery(
                    urls: candidate.photoUrls.isNotEmpty
                        ? candidate.photoUrls
                        : [candidate.primaryPhotoUrl],
                  ),
                  // IgnorePointer so this purely-informational overlay
                  // never steals the swipe gesture from the gallery
                  // underneath it.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(18, 46, 18, 18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.75),
                            ],
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                candidate.age == null
                                    ? candidate.name
                                    : '${candidate.name}, ${candidate.age}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (candidate.extras.distanceMiles != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${candidate.extras.distanceMiles} mi',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _StatStrip(colors: colors, items: _statItems(candidate.extras)),
        if (candidate.extras.compatibilityPercent != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.scoreBackground,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.accent.withOpacity(0.30)),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.pageBackground,
                    border: Border.all(color: colors.accent, width: 2.5),
                  ),
                  child: Text(
                    '${candidate.extras.compatibilityPercent}%',
                    style: TextStyle(
                      color: colors.accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compatibility',
                        style: TextStyle(
                          color: colors.headerPrimaryText,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Based on shared interests and what you\'re both '
                        'looking for.',
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
              ],
            ),
          ),
        if (candidate.extras.ethnicities.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.cardBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.public_rounded, size: 18, color: colors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    candidate.extras.ethnicities.join(', '),
                    style: TextStyle(
                      color: colors.headerPrimaryText,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (candidate.extras.bio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(
              candidate.extras.bio,
              style: TextStyle(
                color: colors.headerPrimaryText,
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (candidate.extras.hobbyPhotoUrl != null ||
            candidate.extras.foodPhotoUrl != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Row(
              children: [
                if (candidate.extras.hobbyPhotoUrl != null)
                  Expanded(
                    child: _MomentCard(
                      colors: colors,
                      url: candidate.extras.hobbyPhotoUrl!,
                      icon: Icons.hiking_rounded,
                      label: 'Hobby',
                    ),
                  ),
                if (candidate.extras.hobbyPhotoUrl != null &&
                    candidate.extras.foodPhotoUrl != null)
                  const SizedBox(width: 12),
                if (candidate.extras.foodPhotoUrl != null)
                  Expanded(
                    child: _MomentCard(
                      colors: colors,
                      url: candidate.extras.foodPhotoUrl!,
                      icon: Icons.restaurant_rounded,
                      label: 'Food',
                    ),
                  ),
              ],
            ),
          ),
        _InfoCategorySection(
          colors: colors,
          label: 'Interests',
          icon: Icons.star_border_rounded,
          chips: _categoryChips(
            candidate.extras.interests,
            myDetails.interests,
          ),
        ),
        _InfoCategorySection(
          colors: colors,
          label: 'Values',
          icon: Icons.emoji_objects_outlined,
          chips: _categoryChips(candidate.extras.values, myDetails.values),
        ),
        _InfoCategorySection(
          colors: colors,
          label: 'Music',
          icon: Icons.music_note_rounded,
          chips: _categoryChips(
            candidate.extras.musicGenres,
            myDetails.musicGenres,
          ),
        ),
        _InfoCategorySection(
          colors: colors,
          label: 'Food',
          icon: Icons.restaurant_outlined,
          chips: _categoryChips(
            candidate.extras.favoriteFoods,
            myDetails.favoriteFoods,
          ),
        ),
        ...candidate.extras.prompts.map(
          (prompt) => Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prompt.prompt,
                  style: TextStyle(
                    color: colors.headerSecondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  prompt.answer,
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MatchProfileScreen extends StatelessWidget {
  const MatchProfileScreen({
    super.key,
    required this.auth,
    required this.candidate,
    required this.profileCache,
    this.onConnect,
    this.onPass,
  });

  final AuthController auth;
  final DiscoverCandidate candidate;

  /// The viewer's own profile — used only to highlight which of the
  /// candidate's interests/values/music/food overlap with the viewer's own,
  /// never mutated here.
  final ProfileCache profileCache;
  final VoidCallback? onConnect;
  final VoidCallback? onPass;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final myDetails = profileCache.details;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.headerBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: colors.headerIconColor),
        title: Text(
          'LooksMatch Profile',
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showMoreOptions(context),
            icon: Icon(Icons.more_vert_rounded, color: colors.headerIconColor),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          ProfileContentView(candidate: candidate, myDetails: myDetails),
        ],
      ),
      bottomNavigationBar: (onConnect == null && onPass == null)
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                decoration: BoxDecoration(
                  color: colors.headerBackground,
                  border: Border(top: BorderSide(color: colors.divider)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          onPass?.call();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Pass'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.headerSecondaryText,
                          side: BorderSide(color: colors.outlineButtonBorder),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          onConnect?.call();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.favorite_rounded),
                        label: const Text('Connect'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primaryButtonBackground,
                          foregroundColor: colors.primaryButtonText,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _showMoreOptions(BuildContext context) async {
    final colors = context.colors;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: colors.pageBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(
                  Icons.flag_outlined,
                  color: colors.headerPrimaryText,
                ),
                title: Text(
                  'Report ${candidate.name}',
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => Navigator.pop(sheetContext, 'report'),
              ),
              ListTile(
                leading: Icon(
                  Icons.block_rounded,
                  color: colors.deleteBackground,
                ),
                title: Text(
                  'Block ${candidate.name}',
                  style: TextStyle(
                    color: colors.deleteBackground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => Navigator.pop(sheetContext, 'block'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted || action == null) return;

    if (action == 'report') {
      await _reportFlow(context);
    } else if (action == 'block') {
      await _blockFlow(context);
    }
  }

  Future<void> _reportFlow(BuildContext context) async {
    final colors = context.colors;

    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: colors.pageBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Why are you reporting ${candidate.name}?',
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...kReportReasons.map(
                (reason) => ListTile(
                  title: Text(
                    reason,
                    style: TextStyle(
                      color: colors.headerPrimaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => Navigator.pop(sheetContext, reason),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted || reason == null) return;

    final detailsController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.dialogBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Report ${candidate.name}?',
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reason: $reason',
              style: TextStyle(
                color: colors.headerSecondaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailsController,
              maxLines: 3,
              maxLength: 500,
              style: TextStyle(color: colors.headerPrimaryText),
              decoration: InputDecoration(
                hintText: 'Add details (optional)',
                hintStyle: TextStyle(color: colors.inputHint),
                filled: true,
                fillColor: colors.inputBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
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
              'Submit Report',
              style: TextStyle(
                color: colors.deleteBackground,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await auth.reportUser(
        reportedUid: candidate.uid,
        reason: reason,
        details: detailsController.text.trim(),
      );
      if (!context.mounted) return;
      _showSnack(context, 'Report submitted. Thanks for letting us know.');
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, 'Could not submit report. Please try again.');
    }
  }

  Future<void> _blockFlow(BuildContext context) async {
    final colors = context.colors;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.dialogBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Block ${candidate.name}?',
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          'You won\'t see each other in Discover, Likes, or Matches anymore.',
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
              'Block',
              style: TextStyle(
                color: colors.deleteBackground,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await auth.blockUser(candidate.uid);
      if (!context.mounted) return;
      _showSnack(context, '${candidate.name} has been blocked.');
      Navigator.pop(context);
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, 'Could not block. Please try again.');
    }
  }
}

class _PhotoGallery extends StatefulWidget {
  const _PhotoGallery({required this.urls});

  final List<String> urls;

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.urls.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) =>
                NetworkPhoto(url: widget.urls[index]),
          ),
          if (widget.urls.length > 1)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: List.generate(widget.urls.length, (index) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: index == _page
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
