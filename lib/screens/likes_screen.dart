import 'package:flutter/material.dart';

import '../models/discover_candidate.dart';
import '../models/likes_and_matches.dart';
import '../services/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/network_avatar.dart';
import 'match_profile_screen.dart';

class LikesScreen extends StatefulWidget {
  const LikesScreen({
    super.key,
    required this.auth,
    this.onMatched,
    this.refreshToken = 0,
  });

  final AuthController auth;

  /// Called when accepting a received like creates a match, so the host
  /// shell can surface the Matches tab.
  final VoidCallback? onMatched;

  /// Bump this (e.g. from the host shell, on every switch to this tab) to
  /// force a reload — otherwise IndexedStack keeps this screen's stale
  /// data around indefinitely.
  final int refreshToken;

  @override
  State<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends State<LikesScreen> {
  bool _showReceived = true;
  bool _loading = true;
  // Once we've shown real data, a tab-switch or pull-to-refresh reload
  // fetches quietly in the background instead of wiping the list back to a
  // full-screen spinner — only the true first load ever blocks like that.
  bool _hasLoadedOnce = false;
  List<LikeEntry> _received = [];
  List<LikeEntry> _sent = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LikesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!_hasLoadedOnce) setState(() => _loading = true);

    try {
      final result = await widget.auth.getLikes();
      if (!mounted) return;
      setState(() {
        _received = result.received;
        _sent = result.sent;
        _loading = false;
        _hasLoadedOnce = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _hasLoadedOnce = true;
      _showMessage('Could not load likes. Pull down to retry.');
    }
  }

  Future<void> _respond(LikeEntry entry, bool accept) async {
    setState(() => _received.removeWhere((r) => r.uid == entry.uid));

    try {
      await widget.auth.respondToLike(likerUid: entry.uid, accept: accept);
    } catch (error) {
      if (!mounted) return;
      setState(() => _received.insert(0, entry));
      _showMessage(authErrorMessage(error));
      return;
    }

    if (!mounted) return;

    if (accept) {
      _showMessage('You matched with ${entry.name}!');
      widget.onMatched?.call();
    } else {
      _showMessage('Request declined.');
    }
  }

  Future<void> _cancel(LikeEntry entry) async {
    setState(() => _sent.removeWhere((r) => r.uid == entry.uid));

    try {
      await widget.auth.cancelSentLike(entry.uid);
    } catch (error) {
      if (!mounted) return;
      setState(() => _sent.insert(0, entry));
      _showMessage(authErrorMessage(error));
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
            child: _loading
                ? Center(child: CircularProgressIndicator(color: colors.accent))
                : RefreshIndicator(
                    color: colors.accent,
                    onRefresh: _load,
                    child: list.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.5,
                                child: Center(
                                  child: Text(
                                    _showReceived
                                        ? 'No likes yet. Keep your profile active!'
                                        : 'You haven\'t sent any requests yet.',
                                    style: TextStyle(
                                      color: colors.headerSecondaryText,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                            itemCount: list.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 11),
                            itemBuilder: (context, index) {
                              final entry = list[index];
                              return _LikeCard(
                                auth: widget.auth,
                                entry: entry,
                                onAccept: _showReceived
                                    ? () => _respond(entry, true)
                                    : null,
                                onDecline: _showReceived
                                    ? () => _respond(entry, false)
                                    : null,
                                onCancel: !_showReceived
                                    ? () => _cancel(entry)
                                    : null,
                              );
                            },
                          ),
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
    required this.auth,
    required this.entry,
    this.onAccept,
    this.onDecline,
    this.onCancel,
  });

  final AuthController auth;
  final LikeEntry entry;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
                    builder: (_) => MatchProfileScreen(
                      auth: auth,
                      candidate: DiscoverCandidate(
                        uid: entry.uid,
                        name: entry.name,
                        age: entry.age,
                        primaryPhotoUrl: entry.primaryPhotoUrl,
                        photoUrls: entry.photoUrls,
                        extras: entry.extras,
                      ),
                    ),
                  ),
                ),
                child: NetworkAvatar(url: entry.primaryPhotoUrl, radius: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.age == null ? entry.name : '${entry.name}, ${entry.age}',
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontSize: 15,
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
