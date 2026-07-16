import 'package:flutter/material.dart';

import '../models/match_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/match_card.dart';
import 'match_profile_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final List<MatchProfile> _profiles = List.of(sampleDiscoverProfiles);

  void _removeProfile(MatchProfile profile) {
    setState(() => _profiles.removeWhere((p) => p.id == profile.id));
  }

  void _handleConnect(MatchProfile profile) {
    _removeProfile(profile);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Connection request sent to ${profile.name}.',
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
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            Icon(Icons.favorite_rounded, color: colors.accent, size: 22),
            const SizedBox(width: 7),
            Text(
              'LooksMatch',
              style: TextStyle(
                color: colors.headerPrimaryText,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.tune_rounded, color: colors.headerIconColor),
          ),
        ],
      ),
      body: _profiles.isEmpty
          ? _EmptyState(onReset: () {
              setState(() => _profiles.addAll(sampleDiscoverProfiles));
            })
          : RefreshIndicator(
              color: colors.accent,
              onRefresh: () async {
                setState(() {});
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _IntroBanner(colors: colors),
                  const SizedBox(height: 14),
                  ..._profiles.map(
                    (profile) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: MatchCard(
                        profile: profile,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MatchProfileScreen(
                              profile: profile,
                              onConnect: () => _handleConnect(profile),
                              onPass: () => _removeProfile(profile),
                            ),
                          ),
                        ),
                        onPass: () => _removeProfile(profile),
                        onConnect: () => _handleConnect(profile),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _IntroBanner extends StatelessWidget {
  const _IntroBanner({required this.colors});

  final LooksMatchColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.scoreBackground,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: colors.accent.withOpacity(0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: colors.accent),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'No swiping. Your LooksMatch score curates who you see, ranked by compatibility.',
              style: TextStyle(
                color: colors.headerPrimaryText,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: colors.scoreBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: colors.accent,
                size: 36,
              ),
            ),
            const SizedBox(height: 17),
            Text(
              'You\'re all caught up',
              style: TextStyle(
                color: colors.headerPrimaryText,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New curated matches will appear here as more people join.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.headerSecondaryText,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onReset,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primaryButtonBackground,
                foregroundColor: colors.primaryButtonText,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                'Refresh',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
