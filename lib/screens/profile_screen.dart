import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/network_avatar.dart';
import '../widgets/sign_out_dialog.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onSignOut});

  final Future<void> Function() onSignOut;

  static const String _myPhoto = 'https://i.pravatar.cc/600?img=68';
  static const List<String> _myPhotos = [
    'https://i.pravatar.cc/600?img=68',
    'https://i.pravatar.cc/600?img=60',
    'https://i.pravatar.cc/600?img=65',
  ];

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
          'Profile',
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: () =>
                confirmSignOut(context: context, onSignOut: onSignOut),
            icon: Icon(Icons.logout_rounded, color: colors.headerIconColor),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () {},
            icon: Icon(Icons.settings_outlined, color: colors.headerIconColor),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Center(
            child: Stack(
              children: [
                NetworkAvatar(url: _myPhoto, radius: 56),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.primaryButtonBackground,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.pageBackground,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      color: colors.primaryButtonText,
                      size: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'You',
              style: TextStyle(
                color: colors.headerPrimaryText,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Complete your profile to improve your LooksMatch score.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.headerSecondaryText,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.scoreBackground,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.accent.withOpacity(0.30)),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.pageBackground,
                    border: Border.all(color: colors.accent, width: 2.5),
                  ),
                  child: Text(
                    '91',
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your LooksMatch Score',
                        style: TextStyle(
                          color: colors.headerPrimaryText,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Top 12% in your area this week.',
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
          const SizedBox(height: 22),
          Text(
            'Photos',
            style: TextStyle(
              color: colors.headerPrimaryText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _myPhotos.length + 1,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              if (index == _myPhotos.length) {
                return DottedAddTile(colors: colors);
              }
              return NetworkPhoto(url: _myPhotos[index], borderRadius: 16);
            },
          ),
          const SizedBox(height: 24),
          _menuTile(
            colors: colors,
            icon: Icons.person_outline_rounded,
            label: 'Edit Profile',
          ),
          _menuTile(
            colors: colors,
            icon: Icons.tune_rounded,
            label: 'Match Preferences',
          ),
          _menuTile(
            colors: colors,
            icon: Icons.shield_outlined,
            label: 'Privacy & Safety',
          ),
          _menuTile(
            colors: colors,
            icon: Icons.help_outline_rounded,
            label: 'Help & Support',
          ),
          const SizedBox(height: 14),
          _menuTile(
            colors: colors,
            icon: Icons.logout_rounded,
            label: 'Log Out',
            destructive: true,
            onTap: () => confirmSignOut(context: context, onSignOut: onSignOut),
          ),
        ],
      ),
    );
  }

  Widget _menuTile({
    required LooksMatchColors colors,
    required IconData icon,
    required String label,
    bool destructive = false,
    VoidCallback? onTap,
  }) {
    final color = destructive ? colors.deleteBackground : colors.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: destructive
              ? colors.deleteBackground.withOpacity(0.35)
              : colors.cardBorder,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: TextStyle(
            color: destructive
                ? colors.deleteBackground
                : colors.headerPrimaryText,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        trailing: destructive
            ? null
            : Icon(
                Icons.chevron_right_rounded,
                color: colors.headerSecondaryText,
              ),
        onTap: onTap ?? () {},
      ),
    );
  }
}

class DottedAddTile extends StatelessWidget {
  const DottedAddTile({super.key, required this.colors});

  final LooksMatchColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withOpacity(0.45), width: 1.4),
      ),
      child: Icon(Icons.add_a_photo_outlined, color: colors.accent),
    );
  }
}
