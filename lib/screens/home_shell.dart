import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'discover_screen.dart';
import 'likes_screen.dart';
import 'matches_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  late final List<Widget> _tabs = [
    const DiscoverScreen(),
    const LikesScreen(),
    const MatchesScreen(),
    ProfileScreen(onSignOut: widget.onSignOut),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      body: IndexedStack(index: _index, children: _tabs),
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
                _navItem(colors, 2, Icons.chat_bubble_outline_rounded, 'Matches'),
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
    final color =
        selected ? colors.bottomNavSelectedIcon : colors.bottomNavUnselectedIcon;

    return InkWell(
      onTap: () => setState(() => _index = index),
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
