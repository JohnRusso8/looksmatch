import 'package:flutter/material.dart';

import '../models/match_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/network_avatar.dart';
import 'chat_screen.dart';

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final conversations = sampleConversations;
    final newMatches =
        conversations.where((c) => c.isNewMatch).toList(growable: false);
    final others =
        conversations.where((c) => !c.isNewMatch).toList(growable: false);

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
      body: ListView(
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
                  final conversation = newMatches[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(profile: conversation.profile),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.accent, width: 2),
                          ),
                          child: NetworkAvatar(
                            url: conversation.profile.photoUrl,
                            radius: 30,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          conversation.profile.name,
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
          if (others.isEmpty && newMatches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
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
            )
          else
            ...others.map(
              (conversation) => _ConversationTile(conversation: conversation),
            ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final MatchConversation conversation;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(profile: conversation.profile),
        ),
      ),
      leading: NetworkAvatar(url: conversation.profile.photoUrl, radius: 27),
      title: Text(
        conversation.profile.name,
        style: TextStyle(
          color: colors.headerPrimaryText,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        conversation.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: conversation.unread
              ? colors.headerPrimaryText
              : colors.headerSecondaryText,
          fontSize: 12.5,
          fontWeight: conversation.unread ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            conversation.timeAgo,
            style: TextStyle(
              color: colors.headerSecondaryText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (conversation.unread) ...[
            const SizedBox(height: 6),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: colors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
