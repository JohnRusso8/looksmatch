import 'package:flutter/material.dart';

import '../models/discover_candidate.dart';
import '../services/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/match_card.dart';
import 'match_profile_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    required this.auth,
    this.onMatched,
    this.refreshToken = 0,
  });

  final AuthController auth;

  /// Called when a decision results in an immediate mutual match, so the
  /// host shell can surface the Matches tab.
  final VoidCallback? onMatched;

  /// Bump this (e.g. from the host shell, on every switch to this tab) to
  /// force a reload — otherwise IndexedStack keeps this screen's stale
  /// data around indefinitely, e.g. after finally getting scored.
  final int refreshToken;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  bool _loading = true;
  List<DiscoverCandidate> _candidates = [];
  final Map<String, String> _decisions = {};
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DiscoverScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final result = await widget.auth.getDailyMatches();

      if (!mounted) return;
      setState(() {
        _candidates = result.candidates;
        _decisions
          ..clear()
          ..addAll(result.decisions);
        _hasMore = result.hasMore;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Could not load today\'s matches. Pull down to retry.');
    }
  }

  List<DiscoverCandidate> get _undecided =>
      _candidates.where((c) => !_decisions.containsKey(c.uid)).toList();

  Future<void> _decide(DiscoverCandidate candidate, String decision) async {
    setState(() => _decisions[candidate.uid] = decision);

    bool matched = false;
    try {
      matched = await widget.auth.recordMatchDecision(
        candidateUid: candidate.uid,
        decision: decision,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _decisions.remove(candidate.uid));
      _showMessage('Could not save that. Please try again.');
      return;
    }

    if (!mounted || decision != 'liked') return;

    if (matched) {
      _showMessage('It\'s a match with ${candidate.name}!');
      widget.onMatched?.call();
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Connection request sent to ${candidate.name}.',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
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
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(LooksMatchColors colors) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: colors.accent));
    }

    final undecided = _undecided;

    if (undecided.isEmpty) {
      return RefreshIndicator(
        color: colors.accent,
        onRefresh: _load,
        child: _candidates.isEmpty
            ? _NoCandidatesState(colors: colors)
            : _DoneForTodayState(colors: colors, hasMore: _hasMore),
      );
    }

    return RefreshIndicator(
      color: colors.accent,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _IntroBanner(colors: colors, remaining: undecided.length),
          const SizedBox(height: 14),
          ...undecided.map(
            (candidate) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: MatchCard(
                candidate: candidate,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MatchProfileScreen(
                      candidate: candidate,
                      onConnect: () => _decide(candidate, 'liked'),
                      onPass: () => _decide(candidate, 'passed'),
                    ),
                  ),
                ),
                onPass: () => _decide(candidate, 'passed'),
                onConnect: () => _decide(candidate, 'liked'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroBanner extends StatelessWidget {
  const _IntroBanner({required this.colors, required this.remaining});

  final LooksMatchColors colors;
  final int remaining;

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
              'No swiping. $remaining curated ${remaining == 1 ? 'match' : 'matches'} '
              'for you today.',
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

class _NoCandidatesState extends StatelessWidget {
  const _NoCandidatesState({required this.colors});

  final LooksMatchColors colors;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
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
                  'No matches yet',
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check back soon — new curated matches appear here as '
                  'more people join.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.headerSecondaryText,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
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

class _DoneForTodayState extends StatelessWidget {
  const _DoneForTodayState({required this.colors, required this.hasMore});

  final LooksMatchColors colors;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.62,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasMore) _HiddenCardStack(colors: colors),
                if (!hasMore)
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: colors.scoreBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: colors.accent,
                      size: 36,
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'You\'re all caught up for today',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasMore
                      ? 'There are more people waiting for you — 3 new '
                            'matches unlock tomorrow.'
                      : '3 new matches will be ready for you tomorrow.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.headerSecondaryText,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
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

/// Purely decorative — a peek of card edges stacked behind the "done for
/// today" message, hinting more people are available beyond today's cap.
/// Not interactive; this app doesn't swipe.
class _HiddenCardStack extends StatelessWidget {
  const _HiddenCardStack({required this.colors});

  final LooksMatchColors colors;

  @override
  Widget build(BuildContext context) {
    Widget ghostCard({
      required double width,
      required double height,
      required double rotationTurns,
      required double opacity,
    }) {
      return Transform.rotate(
        angle: rotationTurns,
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: colors.inputBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.cardBorder),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ghostCard(width: 96, height: 120, rotationTurns: -0.16, opacity: 0.35),
          ghostCard(width: 96, height: 120, rotationTurns: 0.16, opacity: 0.5),
          Container(
            width: 96,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.scoreBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.accent.withOpacity(0.45)),
            ),
            child: Icon(Icons.lock_clock_rounded, color: colors.accent, size: 30),
          ),
        ],
      ),
    );
  }
}
