import 'package:flutter/material.dart';

import '../models/discover_candidate.dart';
import '../models/likes_and_matches.dart';
import '../services/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/network_avatar.dart';
import 'match_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.auth, required this.match});

  final AuthController auth;
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

                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'You matched with ${widget.match.name}! Say hi 👋',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.headerSecondaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final fromMe = message.senderId == myUid;

                    return Align(
                      alignment: fromMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
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
                          message.text,
                          style: TextStyle(
                            color: fromMe
                                ? colors.messageBubbleMeText
                                : colors.messageBubbleOtherText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
