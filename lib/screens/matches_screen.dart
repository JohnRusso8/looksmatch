import 'package:flutter/material.dart';

import '../models/likes_and_matches.dart';
import '../services/auth_controller.dart';
import '../services/profile_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/network_avatar.dart';
import 'chat_screen.dart';

String _relativeTime(DateTime? value) {
  if (value == null) return '';

  final difference = DateTime.now().difference(value);
  if (difference.inMinutes < 1) return 'Now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return '${value.month}/${value.day}/${value.year}';
}

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({
    super.key,
    required this.auth,
    required this.profileCache,
    this.refreshToken = 0,
  });

  final AuthController auth;
  final ProfileCache profileCache;

  /// Bump this (e.g. from the host shell) to force a reload — used right
  /// after a fresh match so this tab shows it without needing a relaunch.
  final int refreshToken;

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  bool _loading = true;
  // Once we've shown real data, a tab-switch or pull-to-refresh reload
  // fetches quietly in the background instead of wiping the list back to a
  // full-screen spinner — only the true first load ever blocks like that.
  bool _hasLoadedOnce = false;
  List<MatchConnection> _matches = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MatchesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!_hasLoadedOnce) setState(() => _loading = true);

    try {
      final matches = await widget.auth.getMatches();
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _loading = false;
        _hasLoadedOnce = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _hasLoadedOnce = true;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Could not load matches. Pull down to retry.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );
    }
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
        title: Text(
          'Matches',
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.accent))
          : RefreshIndicator(
              color: colors.accent,
              onRefresh: _load,
              child: _buildBody(colors),
            ),
    );
  }

  Widget _buildBody(LooksMatchColors colors) {
    final newMatches = _matches.where((m) => m.isNewMatch).toList();
    final others = _matches.where((m) => !m.isNewMatch).toList();

    if (_matches.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Text(
                'No matches yet. Keep exploring Discover!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.headerSecondaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
      children: [
        if (newMatches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'New matches',
              style: TextStyle(
                color: colors.headerSecondaryText,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: newMatches.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final match = newMatches[index];
                return GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          auth: widget.auth,
                          profileCache: widget.profileCache,
                          match: match,
                        ),
                      ),
                    );
                    if (!mounted) return;
                    _load();
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.accent, width: 2),
                        ),
                        child: NetworkAvatar(
                          url: match.primaryPhotoUrl,
                          radius: 30,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        match.name,
                        style: TextStyle(
                          color: colors.headerPrimaryText,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: colors.divider),
        ],
        const SizedBox(height: 6),
        ...others.map(
          (match) => _ConversationTile(
            auth: widget.auth,
            profileCache: widget.profileCache,
            match: match,
            onOpened: _load,
          ),
        ),
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.auth,
    required this.profileCache,
    required this.match,
    required this.onOpened,
  });

  final AuthController auth;
  final ProfileCache profileCache;
  final MatchConnection match;
  final VoidCallback onOpened;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              auth: auth,
              profileCache: profileCache,
              match: match,
            ),
          ),
        );
        onOpened();
      },
      leading: NetworkAvatar(url: match.primaryPhotoUrl, radius: 27),
      title: Text(
        match.name,
        style: TextStyle(
          color: colors.headerPrimaryText,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        match.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.headerSecondaryText,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Text(
        _relativeTime(match.lastMessageAt),
        style: TextStyle(
          color: colors.headerSecondaryText,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
