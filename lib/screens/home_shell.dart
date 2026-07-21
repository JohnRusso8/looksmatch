import 'package:flutter/material.dart';

import '../services/auth_controller.dart';
import '../services/notification_router.dart';
import '../services/profile_cache.dart';
import '../theme/app_theme.dart';
import 'discover_screen.dart';
import 'likes_screen.dart';
import 'matches_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.auth});

  final AuthController auth;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _discoverRefreshToken = 0;
  int _likesRefreshToken = 0;
  int _matchesRefreshToken = 0;

  // Lives for the whole signed-in session (same lifetime as this shell) so
  // Profile/Settings/Preferences/Edit Profile/Scoring can all read the
  // user's own profile instantly instead of each re-fetching it.
  late final ProfileCache _profileCache = ProfileCache(widget.auth);

  // IndexedStack keeps every tab's State alive for the whole session, so
  // each tab's initState only ever runs once — switching back to a tab
  // (e.g. Discover after finally getting scored, or Matches after sending
  // a message) doesn't re-fetch on its own. Bumping that tab's refresh
  // token on every switch to it makes tab data self-refresh instead of
  // relying on the user to pull-to-refresh.
  void _selectTab(int index) {
    setState(() {
      _index = index;
      switch (index) {
        case 0:
          _discoverRefreshToken++;
          break;
        case 1:
          _likesRefreshToken++;
          break;
        case 2:
          _matchesRefreshToken++;
          break;
      }
    });
  }

  // A match can happen from Discover or Likes; jump straight to Matches
  // with a fresh load so the new match shows up immediately.
  void _goToMatches() => _selectTab(2);

  @override
  void initState() {
    super.initState();
    // Listener, not just a one-time check — a notification tapped while
    // terminated resolves asynchronously (getInitialMessage) and may set
    // this after HomeShell has already mounted, so the listener has to stay
    // registered rather than only checking once here. The initial check
    // itself is deferred a frame since _selectTab calls setState, which
    // initState can't do synchronously.
    NotificationRouter.pendingTab.addListener(_onNotificationTabRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onNotificationTabRequest());
  }

  void _onNotificationTabRequest() {
    final tab = NotificationRouter.pendingTab.value;
    if (tab == null) return;
    NotificationRouter.consume();

    if (tab == 'matches') {
      _selectTab(2);
    } else if (tab == 'likes') {
      _selectTab(1);
    }
  }

  @override
  void dispose() {
    NotificationRouter.pendingTab.removeListener(_onNotificationTabRequest);
    _profileCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final tabs = [
      DiscoverScreen(
        auth: widget.auth,
        profileCache: _profileCache,
        onMatched: _goToMatches,
        refreshToken: _discoverRefreshToken,
      ),
      LikesScreen(
        auth: widget.auth,
        onMatched: _goToMatches,
        refreshToken: _likesRefreshToken,
      ),
      MatchesScreen(auth: widget.auth, refreshToken: _matchesRefreshToken),
      ProfileScreen(auth: widget.auth, profileCache: _profileCache),
    ];

    return Scaffold(
      backgroundColor: colors.pageBackground,
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.bottomNavBackground,
          boxShadow: [
            BoxShadow(
              color: colors.bottomNavShadow,
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(colors, 0, Icons.auto_awesome_rounded, 'Discover'),
                _navItem(colors, 1, Icons.favorite_border_rounded, 'Likes'),
                _navItem(
                  colors,
                  2,
                  Icons.chat_bubble_outline_rounded,
                  'Matches',
                ),
                _navItem(colors, 3, Icons.person_outline_rounded, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    LooksMatchColors colors,
    int index,
    IconData icon,
    String label,
  ) {
    final selected = _index == index;
    final color = selected
        ? colors.bottomNavSelectedIcon
        : colors.bottomNavUnselectedIcon;

    return InkWell(
      onTap: () => _selectTab(index),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
