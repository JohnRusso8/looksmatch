import 'package:flutter/material.dart';

import '../models/discover_candidate.dart';
import '../theme/app_theme.dart';
import 'network_avatar.dart';

class MatchCard extends StatelessWidget {
  const MatchCard({
    super.key,
    required this.candidate,
    required this.onTap,
    required this.onPass,
    required this.onConnect,
  });

  final DiscoverCandidate candidate;
  final VoidCallback onTap;
  final VoidCallback onPass;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 5,
                  child: NetworkPhoto(url: candidate.primaryPhotoUrl),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.55),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Text(
                    candidate.age == null
                        ? candidate.name
                        : '${candidate.name}, ${candidate.age}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPass,
                    icon: const Icon(Icons.close_rounded, size: 19),
                    label: const Text('Pass'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.headerSecondaryText,
                      side: BorderSide(color: colors.outlineButtonBorder),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: onConnect,
                    icon: const Icon(Icons.favorite_rounded, size: 18),
                    label: const Text('Connect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primaryButtonBackground,
                      foregroundColor: colors.primaryButtonText,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
