import 'package:flutter/material.dart';

import '../models/discover_candidate.dart';
import '../models/profile_extras.dart';
import '../theme/app_theme.dart';
import '../widgets/network_avatar.dart';

class _Trait {
  const _Trait(this.icon, this.label);

  final IconData icon;
  final String label;
}

List<_Trait> _traits(ProfileExtras extras) {
  return [
    if (extras.ethnicity != null) _Trait(Icons.public_rounded, extras.ethnicity!),
    if (extras.relationshipType != null)
      _Trait(Icons.favorite_border_rounded, extras.relationshipType!),
    if (extras.datingIntention != null)
      _Trait(Icons.explore_outlined, extras.datingIntention!),
    if (extras.heightInches != null)
      _Trait(Icons.height_rounded, extras.heightLabel),
    if (extras.drinking != null) _Trait(Icons.local_bar_outlined, 'Drinks: ${extras.drinking}'),
    if (extras.smoking != null) _Trait(Icons.smoking_rooms_outlined, 'Smokes: ${extras.smoking}'),
    if (extras.educationLevel != null)
      _Trait(Icons.school_outlined, extras.educationLevel!),
    if (extras.college?.isNotEmpty ?? false)
      _Trait(Icons.account_balance_outlined, extras.college!),
  ];
}

class _TraitChip extends StatelessWidget {
  const _TraitChip({required this.colors, required this.trait});

  final LooksMatchColors colors;
  final _Trait trait;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: colors.chipUnselectedBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.chipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(trait.icon, size: 15, color: colors.accent),
          const SizedBox(width: 6),
          Text(
            trait.label,
            style: TextStyle(
              color: colors.chipUnselectedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class MatchProfileScreen extends StatelessWidget {
  const MatchProfileScreen({
    super.key,
    required this.candidate,
    this.onConnect,
    this.onPass,
  });

  final DiscoverCandidate candidate;
  final VoidCallback? onConnect;
  final VoidCallback? onPass;

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
          'LooksMatch Profile',
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.more_vert_rounded, color: colors.headerIconColor),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _PhotoGallery(
                urls: candidate.photoUrls.isNotEmpty
                    ? candidate.photoUrls
                    : [candidate.primaryPhotoUrl],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    candidate.age == null
                        ? candidate.name
                        : '${candidate.name}, ${candidate.age}',
                    style: TextStyle(
                      color: colors.headerPrimaryText,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (candidate.extras.distanceMiles != null)
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: colors.headerSecondaryText,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${candidate.extras.distanceMiles} mi',
                        style: TextStyle(
                          color: colors.headerSecondaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
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
          if (candidate.extras.bio.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.cardBorder),
              ),
              child: Text(
                candidate.extras.bio,
                style: TextStyle(
                  color: colors.headerPrimaryText,
                  fontSize: 14.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (candidate.extras.interests.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: candidate.extras.interests
                    .map(
                      (interest) => _TraitChip(
                        colors: colors,
                        trait: _Trait(Icons.star_border_rounded, interest),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (_traits(candidate.extras).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _traits(candidate.extras)
                    .map((trait) => _TraitChip(colors: colors, trait: trait))
                    .toList(),
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
                          textStyle: const TextStyle(fontWeight: FontWeight.w900),
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
                          textStyle: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
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
