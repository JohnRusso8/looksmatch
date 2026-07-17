import 'profile_extras.dart';

/// A person shown in today's Discover deck. Deliberately has no score/band
/// field at all — matching happens server-side and is never exposed to any
/// client, so there's nothing here to accidentally render.
class DiscoverCandidate {
  const DiscoverCandidate({
    required this.uid,
    required this.name,
    required this.age,
    required this.primaryPhotoUrl,
    this.photoUrls = const [],
    this.extras = const ProfileExtras(),
  });

  factory DiscoverCandidate.fromMap(Map<dynamic, dynamic> map) {
    return DiscoverCandidate(
      uid: (map['uid'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      age: (map['age'] as num?)?.toInt(),
      primaryPhotoUrl: (map['primaryPhotoUrl'] ?? '').toString(),
      photoUrls: _parsePhotoUrls(map['photoUrls']),
      extras: ProfileExtras.fromMap(map),
    );
  }

  final String uid;
  final String name;
  final int? age;
  final String primaryPhotoUrl;
  final List<String> photoUrls;
  final ProfileExtras extras;
}

List<String> _parsePhotoUrls(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((url) => url.toString()).where((url) => url.isNotEmpty).toList();
}

/// The result of a getDailyMatches call: today's (up to daily-limit)
/// candidates, which of them this user has already decided on, and whether
/// more eligible people existed beyond today's allocation.
class DailyMatches {
  const DailyMatches({
    required this.candidates,
    required this.decisions,
    required this.hasMore,
  });

  factory DailyMatches.fromMap(Map<String, dynamic> map) {
    final rawCandidates = map['candidates'];
    final candidates = rawCandidates is List
        ? rawCandidates
              .whereType<Map>()
              .map(DiscoverCandidate.fromMap)
              .toList()
        : const <DiscoverCandidate>[];

    final rawDecisions = map['decisions'];
    final decisions = rawDecisions is Map
        ? rawDecisions.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : const <String, String>{};

    return DailyMatches(
      candidates: candidates,
      decisions: decisions,
      hasMore: map['hasMore'] == true,
    );
  }

  final List<DiscoverCandidate> candidates;
  final Map<String, String> decisions;
  final bool hasMore;

  List<DiscoverCandidate> get undecided =>
      candidates.where((c) => !decisions.containsKey(c.uid)).toList();
}
