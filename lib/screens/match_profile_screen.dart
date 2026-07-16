import 'package:flutter/material.dart';

import '../models/match_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/network_avatar.dart';

class MatchProfileScreen extends StatelessWidget {
  const MatchProfileScreen({
    super.key,
    required this.profile,
    this.onConnect,
    this.onPass,
  });

  final MatchProfile profile;
  final VoidCallback? onConnect;
  final VoidCallback? onPass;

  Widget _chipWrap(BuildContext context, List<String> items) {
    final colors = context.colors;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.chipUnselectedBackground,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.chipBorder),
              ),
              child: Text(
                item,
                style: TextStyle(
                  color: colors.chipUnselectedText,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          )
          .toList(),
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
              child: NetworkPhoto(url: profile.photoUrl, borderRadius: 24),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${profile.name}, ${profile.age}',
                              style: TextStyle(
                                color: colors.headerPrimaryText,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (profile.verified) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.verified_rounded,
                              color: colors.accent,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.scoreBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${profile.looksMatchScore}%',
                            style: TextStyle(
                              color: colors.scoreText,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'match',
                            style: TextStyle(
                              color: colors.headerSecondaryText,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: colors.headerSecondaryText,
                      size: 15,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${profile.distanceMiles.toStringAsFixed(1)} miles away',
                      style: TextStyle(
                        color: colors.headerSecondaryText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  profile.bio,
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.scoreBackground,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.accent.withOpacity(0.30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: colors.accent),
                    const SizedBox(width: 10),
                    Text(
                      'Why you match',
                      style: TextStyle(
                        color: colors.headerPrimaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...profile.reasons.map(
                  (reason) => Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: colors.accent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reason,
                            style: TextStyle(
                              color: colors.headerPrimaryText,
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Text(
              'Interests',
              style: TextStyle(
                color: colors.headerPrimaryText,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _chipWrap(context, profile.interests),
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
