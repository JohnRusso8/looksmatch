import 'package:flutter/material.dart';

import '../models/match_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/network_avatar.dart';
import 'match_profile_screen.dart';

class LikesScreen extends StatefulWidget {
  const LikesScreen({super.key});

  @override
  State<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends State<LikesScreen> {
  bool _showReceived = true;
  final List<LikeRequest> _received = List.of(sampleReceivedLikes);
  final List<LikeRequest> _sent = List.of(sampleSentLikes);

  void _respond(LikeRequest request, bool accept) {
    setState(() => _received.removeWhere(
        (r) => r.profile.id == request.profile.id));

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            accept
                ? 'You matched with ${request.profile.name}!'
                : 'Request declined.',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
  }

  void _cancel(LikeRequest request) {
    setState(
        () => _sent.removeWhere((r) => r.profile.id == request.profile.id));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final list = _showReceived ? _received : _sent;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.headerBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Text(
          'Likes',
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.inputBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.inputBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _segmentButton(
                      colors: colors,
                      label: 'Received (${_received.length})',
                      selected: _showReceived,
                      onTap: () => setState(() => _showReceived = true),
                    ),
                  ),
                  Expanded(
                    child: _segmentButton(
                      colors: colors,
                      label: 'Sent (${_sent.length})',
                      selected: !_showReceived,
                      onTap: () => setState(() => _showReceived = false),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(
                      _showReceived
                          ? 'No likes yet. Keep your profile active!'
                          : 'You haven\'t sent any requests yet.',
                      style: TextStyle(
                        color: colors.headerSecondaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 11),
                    itemBuilder: (context, index) {
                      final request = list[index];
                      return _LikeCard(
                        request: request,
                        onAccept: _showReceived
                            ? () => _respond(request, true)
                            : null,
                        onDecline: _showReceived
                            ? () => _respond(request, false)
                            : null,
                        onCancel:
                            !_showReceived ? () => _cancel(request) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _segmentButton({
    required LooksMatchColors colors,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? colors.accent.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? colors.accent : colors.headerSecondaryText,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _LikeCard extends StatelessWidget {
  const _LikeCard({
    required this.request,
    this.onAccept,
    this.onDecline,
    this.onCancel,
  });

  final LikeRequest request;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final profile = request.profile;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MatchProfileScreen(profile: profile),
                  ),
                ),
                child: NetworkAvatar(url: profile.photoUrl, radius: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profile.name}, ${profile.age}',
                      style: TextStyle(
                        color: colors.headerPrimaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.timeAgo,
                      style: TextStyle(
                        color: colors.headerSecondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.scoreBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${profile.looksMatchScore}%',
                  style: TextStyle(
                    color: colors.scoreText,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (onAccept != null || onDecline != null || onCancel != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onDecline != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDecline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.deleteBackground,
                        side: BorderSide(
                          color: colors.deleteBackground.withOpacity(0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Decline',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                if (onDecline != null && onAccept != null)
                  const SizedBox(width: 8),
                if (onAccept != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primaryButtonBackground,
                        foregroundColor: colors.primaryButtonText,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Accept',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                if (onCancel != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.deleteBackground,
                        side: BorderSide(
                          color: colors.deleteBackground.withOpacity(0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel Request',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
