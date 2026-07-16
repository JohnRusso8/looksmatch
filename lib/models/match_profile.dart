/// Placeholder in-memory models. These mirror the shape the eventual
/// Firestore documents will take, so wiring up Firebase later is mostly a
/// matter of swapping the sample lists below for real queries.
class MatchProfile {
  const MatchProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.photoUrl,
    required this.looksMatchScore,
    required this.distanceMiles,
    required this.bio,
    required this.reasons,
    required this.interests,
    this.verified = false,
  });

  final String id;
  final String name;
  final int age;
  final String photoUrl;
  final int looksMatchScore;
  final double distanceMiles;
  final String bio;
  final List<String> reasons;
  final List<String> interests;
  final bool verified;
}

class LikeRequest {
  const LikeRequest({
    required this.profile,
    required this.direction,
    required this.timeAgo,
  });

  final MatchProfile profile;

  /// 'received' or 'sent'
  final String direction;
  final String timeAgo;
}

class MatchConversation {
  const MatchConversation({
    required this.profile,
    required this.lastMessage,
    required this.timeAgo,
    this.unread = false,
    this.isNewMatch = false,
  });

  final MatchProfile profile;
  final String lastMessage;
  final String timeAgo;
  final bool unread;
  final bool isNewMatch;
}

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.fromMe,
  });

  final String text;
  final bool fromMe;
}

const List<MatchProfile> sampleDiscoverProfiles = [
  MatchProfile(
    id: 'p1',
    name: 'Avery',
    age: 27,
    photoUrl: 'https://i.pravatar.cc/600?img=47',
    looksMatchScore: 94,
    distanceMiles: 2.1,
    bio: 'Coffee snob, weekend hiker, still figuring out sourdough.',
    reasons: [
      'Your LooksMatch scores are highly compatible',
      'Both listed as active and open to meeting this week',
      'Similar taste in profile photo style',
    ],
    interests: ['Hiking', 'Coffee', 'Photography'],
    verified: true,
  ),
  MatchProfile(
    id: 'p2',
    name: 'Jordan',
    age: 29,
    photoUrl: 'https://i.pravatar.cc/600?img=12',
    looksMatchScore: 89,
    distanceMiles: 4.6,
    bio: 'Trying every taco truck in the city, one at a time.',
    reasons: [
      'Your LooksMatch scores are highly compatible',
      'Overlapping interests in food and live music',
    ],
    interests: ['Live Music', 'Food', 'Travel'],
  ),
  MatchProfile(
    id: 'p3',
    name: 'Riley',
    age: 25,
    photoUrl: 'https://i.pravatar.cc/600?img=33',
    looksMatchScore: 87,
    distanceMiles: 1.3,
    bio: 'Dog mom, gym regular, always down for a road trip.',
    reasons: [
      'Your LooksMatch scores are highly compatible',
      'Both within your preferred age and distance range',
    ],
    interests: ['Fitness', 'Dogs', 'Road Trips'],
    verified: true,
  ),
  MatchProfile(
    id: 'p4',
    name: 'Morgan',
    age: 31,
    photoUrl: 'https://i.pravatar.cc/600?img=15',
    looksMatchScore: 82,
    distanceMiles: 6.8,
    bio: 'Architect by day, amateur chef by night.',
    reasons: [
      'Your LooksMatch scores are highly compatible',
      'Shared interest in design and cooking',
    ],
    interests: ['Cooking', 'Design', 'Wine'],
  ),
];

const List<LikeRequest> sampleReceivedLikes = [
  LikeRequest(
    profile: MatchProfile(
      id: 'r1',
      name: 'Casey',
      age: 28,
      photoUrl: 'https://i.pravatar.cc/600?img=25',
      looksMatchScore: 91,
      distanceMiles: 3.2,
      bio: 'Beach volleyball on weekends.',
      reasons: ['Your LooksMatch scores are highly compatible'],
      interests: ['Volleyball', 'Beach', 'Brunch'],
      verified: true,
    ),
    direction: 'received',
    timeAgo: '2h ago',
  ),
  LikeRequest(
    profile: MatchProfile(
      id: 'r2',
      name: 'Taylor',
      age: 26,
      photoUrl: 'https://i.pravatar.cc/600?img=32',
      looksMatchScore: 85,
      distanceMiles: 5.4,
      bio: 'Bookstore wanderer and film nerd.',
      reasons: ['Your LooksMatch scores are highly compatible'],
      interests: ['Books', 'Film', 'Coffee'],
    ),
    direction: 'received',
    timeAgo: '1d ago',
  ),
];

const List<LikeRequest> sampleSentLikes = [
  LikeRequest(
    profile: MatchProfile(
      id: 's1',
      name: 'Sam',
      age: 30,
      photoUrl: 'https://i.pravatar.cc/600?img=51',
      looksMatchScore: 88,
      distanceMiles: 2.9,
      bio: 'Runs marathons, terribly, but happily.',
      reasons: ['Your LooksMatch scores are highly compatible'],
      interests: ['Running', 'Fitness'],
    ),
    direction: 'sent',
    timeAgo: '3h ago',
  ),
];

final List<MatchConversation> sampleConversations = [
  MatchConversation(
    profile: sampleDiscoverProfiles[0],
    lastMessage: 'You matched! Say hi 👋',
    timeAgo: 'Now',
    isNewMatch: true,
  ),
  MatchConversation(
    profile: sampleDiscoverProfiles[2],
    lastMessage: 'Haha yes, that trail is brutal in summer',
    timeAgo: '10m ago',
    unread: true,
  ),
  MatchConversation(
    profile: sampleDiscoverProfiles[3],
    lastMessage: 'You: Sounds good, see you then!',
    timeAgo: '1d ago',
  ),
];
