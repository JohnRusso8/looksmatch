import 'package:flutter/material.dart';

import '../models/discover_candidate.dart';
import '../models/likes_and_matches.dart';
import '../services/auth_controller.dart';
import '../services/profile_cache.dart';
import '../theme/app_theme.dart';
import '../widgets/network_avatar.dart';
import 'match_profile_screen.dart';

const List<String> _kMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatDateHeader(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final day = DateTime(date.year, date.month, date.day);

  final String dayLabel;
  if (day == today) {
    dayLabel = 'Today';
  } else if (day == yesterday) {
    dayLabel = 'Yesterday';
  } else {
    dayLabel = '${_kMonths[date.month - 1]} ${date.day}';
  }

  final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final ampm = date.hour < 12 ? 'AM' : 'PM';
  return '$dayLabel at $hour12:$minute$ampm';
}

String _formatMatchDate(DateTime date) {
  final year2 = (date.year % 100).toString().padLeft(2, '0');
  return '${date.month}/${date.day}/$year2';
}

/// One row in the chat, in chronological order before being reversed for
/// display — a match header, a date separator between groups of messages
/// sent on different days, or a message itself.
sealed class _ChatListItem {
  const _ChatListItem(this.key);
  final String key;
}

class _MatchHeaderItem extends _ChatListItem {
  _MatchHeaderItem({
    required this.name,
    required this.connectedAt,
    required this.hasMessages,
  }) : super('header');
  final String name;
  final DateTime? connectedAt;
  final bool hasMessages;
}

class _DateSeparatorItem extends _ChatListItem {
  _DateSeparatorItem(this.date) : super('date-${date.toIso8601String()}');
  final DateTime date;
}

class _MessageItem extends _ChatListItem {
  _MessageItem(this.message) : super('msg-${message.id}');
  final ChatMessageEntry message;
}

// Chronological in, reversed out — pairs with ListView(reverse: true) so a
// short conversation sits at the bottom of the screen and grows upward
// exactly like iMessage/Hinge, with no manual scroll-to-bottom bookkeeping:
// index 0 of a reversed list is always the newest content, which is what a
// reversed ListView shows at rest.
List<_ChatListItem> _buildChatItems(
  List<ChatMessageEntry> messages,
  MatchConnection match,
) {
  final items = <_ChatListItem>[
    _MatchHeaderItem(
      name: match.name,
      connectedAt: match.connectedAt,
      hasMessages: messages.isNotEmpty,
    ),
  ];

  DateTime? lastDay;
  for (final message in messages) {
    final sentAt = message.sentAt;
    if (sentAt != null) {
      final day = DateTime(sentAt.year, sentAt.month, sentAt.day);
      if (lastDay == null || day != lastDay) {
        items.add(_DateSeparatorItem(sentAt));
        lastDay = day;
      }
    }
    items.add(_MessageItem(message));
  }

  return items.reversed.toList();
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.auth,
    required this.profileCache,
    required this.match,
  });

  final AuthController auth;
  final ProfileCache profileCache;
  final MatchConnection match;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();

    try {
      await widget.auth.sendMessage(
        connectionId: widget.match.connectionId,
        text: text,
      );
    } catch (error) {
      if (!mounted) return;
      _controller.text = text;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              authErrorMessage(error),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleReaction(ChatMessageEntry message) async {
    final myUid = widget.auth.currentUserId;
    if (myUid == null) return;

    try {
      await widget.auth.toggleMessageReaction(
        connectionId: widget.match.connectionId,
        messageId: message.id,
        addReaction: !message.heartedByUids.contains(myUid),
      );
    } catch (error) {
      // Best-effort — a failed tapback isn't worth interrupting the chat
      // with an error banner.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final myUid = widget.auth.currentUserId;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.headerBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: colors.headerIconColor),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MatchProfileScreen(
                auth: widget.auth,
                profileCache: widget.profileCache,
                candidate: DiscoverCandidate(
                  uid: widget.match.uid,
                  name: widget.match.name,
                  age: widget.match.age,
                  primaryPhotoUrl: widget.match.primaryPhotoUrl,
                  photoUrls: widget.match.photoUrls,
                  extras: widget.match.extras,
                ),
              ),
            ),
          ),
          child: Row(
            children: [
              NetworkAvatar(url: widget.match.primaryPhotoUrl, radius: 18),
              const SizedBox(width: 10),
              Text(
                widget.match.name,
                style: TextStyle(
                  color: colors.headerPrimaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessageEntry>>(
              stream: widget.auth.watchMessages(widget.match.connectionId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? const <ChatMessageEntry>[];

                if (snapshot.connectionState == ConnectionState.waiting &&
                    messages.isEmpty) {
                  return Center(
                    child: CircularProgressIndicator(color: colors.accent),
                  );
                }

                final items = _buildChatItems(messages, widget.match);

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return KeyedSubtree(
                      key: ValueKey(item.key),
                      child: switch (item) {
                        _MatchHeaderItem() => _MatchHeaderWidget(
                          colors: colors,
                          name: item.name,
                          connectedAt: item.connectedAt,
                          hasMessages: item.hasMessages,
                        ),
                        _DateSeparatorItem() => _DateSeparatorWidget(
                          colors: colors,
                          date: item.date,
                        ),
                        _MessageItem() => _AnimatedMessageBubble(
                          message: item.message,
                          fromMe: item.message.senderId == myUid,
                          colors: colors,
                          onDoubleTap: () => _toggleReaction(item.message),
                        ),
                      },
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: colors.headerBackground,
                border: Border(top: BorderSide(color: colors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(
                        color: colors.headerPrimaryText,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Send a message',
                        hintStyle: TextStyle(color: colors.inputHint),
                        filled: true,
                        fillColor: colors.inputBackground,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: colors.primaryButtonBackground,
                      foregroundColor: colors.primaryButtonText,
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchHeaderWidget extends StatelessWidget {
  const _MatchHeaderWidget({
    required this.colors,
    required this.name,
    required this.connectedAt,
    required this.hasMessages,
  });

  final LooksMatchColors colors;
  final String name;
  final DateTime? connectedAt;
  final bool hasMessages;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 8),
      child: Column(
        children: [
          Text(
            connectedAt != null
                ? 'You matched with $name on ${_formatMatchDate(connectedAt!)}'
                : 'You matched with $name',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.headerSecondaryText,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!hasMessages) ...[
            const SizedBox(height: 6),
            Text(
              'Say hi 👋',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.headerSecondaryText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateSeparatorWidget extends StatelessWidget {
  const _DateSeparatorWidget({required this.colors, required this.date});

  final LooksMatchColors colors;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          _formatDateHeader(date),
          style: TextStyle(
            color: colors.headerSecondaryText,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// A message bubble that fades + slides in once, on first insertion — since
/// list items are keyed by message id (see ChatScreen), an existing bubble
/// keeps the same Element/State across rebuilds and never replays this,
/// only a genuinely new message does. That's what avoids the whole list
/// flashing/rebuilding on every incoming message.
class _AnimatedMessageBubble extends StatefulWidget {
  const _AnimatedMessageBubble({
    required this.message,
    required this.fromMe,
    required this.colors,
    required this.onDoubleTap,
  });

  final ChatMessageEntry message;
  final bool fromMe;
  final LooksMatchColors colors;
  final VoidCallback onDoubleTap;

  @override
  State<_AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<_AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.15),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final fromMe = widget.fromMe;
    final hearted = widget.message.heartedByUids.isNotEmpty;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Align(
            alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
            child: GestureDetector(
              onDoubleTap: widget.onDoubleTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    decoration: BoxDecoration(
                      color: fromMe
                          ? colors.messageBubbleMeBackground
                          : colors.messageBubbleOtherBackground,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(fromMe ? 16 : 4),
                        bottomRight: Radius.circular(fromMe ? 4 : 16),
                      ),
                    ),
                    child: Text(
                      widget.message.text,
                      style: TextStyle(
                        color: fromMe
                            ? colors.messageBubbleMeText
                            : colors.messageBubbleOtherText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (hearted)
                    Positioned(
                      top: -12,
                      right: fromMe ? null : -6,
                      left: fromMe ? -6 : null,
                      child: _HeartBadge(colors: colors),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeartBadge extends StatelessWidget {
  const _HeartBadge({required this.colors});

  final LooksMatchColors colors;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.elasticOut,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.deleteBackground,
          border: Border.all(color: colors.pageBackground, width: 2),
        ),
        child: const Icon(
          Icons.favorite_rounded,
          size: 12,
          color: Colors.white,
        ),
      ),
    );
  }
}
