import 'profile_extras.dart';

/// A person who liked you (Received) or that you liked (Sent) — resolved
/// server-side, same "no score field" shape as DiscoverCandidate.
class LikeEntry {
  const LikeEntry({
    required this.uid,
    required this.name,
    required this.age,
    required this.primaryPhotoUrl,
    this.photoUrls = const [],
    this.extras = const ProfileExtras(),
    this.likedAt,
  });

  factory LikeEntry.fromMap(Map<dynamic, dynamic> map) {
    return LikeEntry(
      uid: (map['uid'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      age: (map['age'] as num?)?.toInt(),
      primaryPhotoUrl: (map['primaryPhotoUrl'] ?? '').toString(),
      photoUrls: _parsePhotoUrls(map['photoUrls']),
      extras: ProfileExtras.fromMap(map),
      likedAt: DateTime.tryParse((map['likedAt'] ?? '').toString()),
    );
  }

  final String uid;
  final String name;
  final int? age;
  final String primaryPhotoUrl;
  final List<String> photoUrls;
  final ProfileExtras extras;
  final DateTime? likedAt;
}

List<String> _parsePhotoUrls(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((url) => url.toString()).where((url) => url.isNotEmpty).toList();
}

class LikesResult {
  const LikesResult({required this.received, required this.sent});

  factory LikesResult.fromMap(Map<String, dynamic> map) {
    List<LikeEntry> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw.whereType<Map>().map(LikeEntry.fromMap).toList();
    }

    return LikesResult(
      received: parseList(map['received']),
      sent: parseList(map['sent']),
    );
  }

  final List<LikeEntry> received;
  final List<LikeEntry> sent;
}

/// A mutual match — the other person's info plus the chat preview.
class MatchConnection {
  const MatchConnection({
    required this.connectionId,
    required this.uid,
    required this.name,
    required this.age,
    required this.primaryPhotoUrl,
    this.photoUrls = const [],
    this.extras = const ProfileExtras(),
    required this.lastMessage,
    this.lastMessageAt,
    this.connectedAt,
  });

  factory MatchConnection.fromMap(Map<dynamic, dynamic> map) {
    return MatchConnection(
      connectionId: (map['connectionId'] ?? '').toString(),
      uid: (map['uid'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      age: (map['age'] as num?)?.toInt(),
      primaryPhotoUrl: (map['primaryPhotoUrl'] ?? '').toString(),
      photoUrls: _parsePhotoUrls(map['photoUrls']),
      extras: ProfileExtras.fromMap(map),
      lastMessage: (map['lastMessage'] ?? '').toString(),
      lastMessageAt: DateTime.tryParse((map['lastMessageAt'] ?? '').toString()),
      connectedAt: DateTime.tryParse((map['connectedAt'] ?? '').toString()),
    );
  }

  final String connectionId;
  final String uid;
  final String name;
  final int? age;
  final String primaryPhotoUrl;
  final List<String> photoUrls;
  final ProfileExtras extras;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final DateTime? connectedAt;

  bool get isNewMatch => lastMessage.isEmpty;
}

/// A single message within a connection's chat.
class ChatMessageEntry {
  const ChatMessageEntry({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime? sentAt;
}
