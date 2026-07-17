/// A prompt this person chose plus the answer they wrote for it.
class ProfilePrompt {
  const ProfilePrompt({required this.prompt, required this.answer});

  factory ProfilePrompt.fromMap(Map<dynamic, dynamic> map) {
    return ProfilePrompt(
      prompt: (map['prompt'] ?? '').toString(),
      answer: (map['answer'] ?? '').toString(),
    );
  }

  final String prompt;
  final String answer;

  Map<String, dynamic> toMap() => {'prompt': prompt, 'answer': answer};
}

/// The bio/prompts/traits + distance shown alongside a person elsewhere in
/// the app (Discover, Likes, Matches). Every field here is optional and may
/// simply be absent — the server already strips out anything that person
/// chose to hide, so a missing field just means "not shown", not "loading".
class ProfileExtras {
  const ProfileExtras({
    this.bio = '',
    this.prompts = const [],
    this.interests = const [],
    this.ethnicity,
    this.relationshipType,
    this.datingIntention,
    this.heightInches,
    this.drinking,
    this.smoking,
    this.educationLevel,
    this.college,
    this.distanceMiles,
    this.compatibilityPercent,
  });

  factory ProfileExtras.fromMap(Map<dynamic, dynamic> map) {
    final rawPrompts = map['prompts'];
    final prompts = rawPrompts is List
        ? rawPrompts.whereType<Map>().map(ProfilePrompt.fromMap).toList()
        : const <ProfilePrompt>[];

    final rawInterests = map['interests'];
    final interests = rawInterests is List
        ? rawInterests.map((i) => i.toString()).where((i) => i.isNotEmpty).toList()
        : const <String>[];

    return ProfileExtras(
      bio: (map['bio'] ?? '').toString(),
      prompts: prompts,
      interests: interests,
      ethnicity: map['ethnicity'] as String?,
      relationshipType: map['relationshipType'] as String?,
      datingIntention: map['datingIntention'] as String?,
      heightInches: (map['height'] as num?)?.toInt(),
      drinking: map['drinking'] as String?,
      smoking: map['smoking'] as String?,
      educationLevel: map['educationLevel'] as String?,
      college: map['college'] as String?,
      distanceMiles: (map['distanceMiles'] as num?)?.toInt(),
      compatibilityPercent: (map['compatibilityPercent'] as num?)?.toInt(),
    );
  }

  final String bio;
  final List<ProfilePrompt> prompts;
  final List<String> interests;
  final String? ethnicity;
  final String? relationshipType;
  final String? datingIntention;
  final int? heightInches;
  final String? drinking;
  final String? smoking;
  final String? educationLevel;
  final String? college;
  final int? distanceMiles;

  /// 0-100, only present when both people had enough mutually-visible
  /// fields set to compute anything meaningful from — see
  /// computeCompatibility in functions/index.js.
  final int? compatibilityPercent;

  String get heightLabel {
    final inches = heightInches;
    if (inches == null) return '';
    return '${inches ~/ 12}\'${inches % 12}"';
  }

  bool get hasAnyInfo =>
      bio.isNotEmpty ||
      prompts.isNotEmpty ||
      interests.isNotEmpty ||
      ethnicity != null ||
      relationshipType != null ||
      datingIntention != null ||
      heightInches != null ||
      drinking != null ||
      smoking != null ||
      educationLevel != null ||
      (college?.isNotEmpty ?? false);
}
