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
    this.values = const [],
    this.musicGenres = const [],
    this.favoriteFoods = const [],
    this.ethnicities = const [],
    this.relationshipType,
    this.datingIntention,
    this.heightInches,
    this.drinking,
    this.smoking,
    this.educationLevel,
    this.familyPlans,
    this.college,
    this.distanceMiles,
    this.compatibilityPercent,
    this.hobbyPhotoUrl,
    this.foodPhotoUrl,
  });

  factory ProfileExtras.fromMap(Map<dynamic, dynamic> map) {
    final rawPrompts = map['prompts'];
    final prompts = rawPrompts is List
        ? rawPrompts.whereType<Map>().map(ProfilePrompt.fromMap).toList()
        : const <ProfilePrompt>[];

    List<String> parseStringList(dynamic raw) {
      return raw is List
          ? raw.map((i) => i.toString()).where((i) => i.isNotEmpty).toList()
          : const <String>[];
    }

    // ethnicity used to be a single string before it became multi-select —
    // accept either shape so an already-saved single value still shows up
    // instead of silently disappearing.
    List<String> parseMultiOrLegacySingle(dynamic raw) {
      if (raw is List) {
        return raw.map((i) => i.toString()).where((i) => i.isNotEmpty).toList();
      }
      if (raw is String && raw.isNotEmpty) return [raw];
      return const <String>[];
    }

    // datingIntention briefly became multi-select and then reverted — some
    // already-saved profiles may still have a one-item list from that
    // window, so accept either shape and just take the first value.
    String? parseSingleOrLegacyList(dynamic raw) {
      if (raw is List) {
        return raw.isNotEmpty ? raw.first.toString() : null;
      }
      if (raw is String && raw.isNotEmpty) return raw;
      return null;
    }

    return ProfileExtras(
      bio: (map['bio'] ?? '').toString(),
      prompts: prompts,
      interests: parseStringList(map['interests']),
      values: parseStringList(map['values']),
      musicGenres: parseStringList(map['musicGenres']),
      favoriteFoods: parseStringList(map['favoriteFoods']),
      ethnicities: parseMultiOrLegacySingle(map['ethnicity']),
      relationshipType: map['relationshipType'] as String?,
      datingIntention: parseSingleOrLegacyList(map['datingIntention']),
      heightInches: (map['height'] as num?)?.toInt(),
      drinking: map['drinking'] as String?,
      smoking: map['smoking'] as String?,
      educationLevel: map['educationLevel'] as String?,
      familyPlans: map['familyPlans'] as String?,
      college: map['college'] as String?,
      distanceMiles: (map['distanceMiles'] as num?)?.toInt(),
      compatibilityPercent: (map['compatibilityPercent'] as num?)?.toInt(),
      hobbyPhotoUrl: (map['hobbyPhotoUrl'] as String?)?.isNotEmpty == true
          ? map['hobbyPhotoUrl'] as String
          : null,
      foodPhotoUrl: (map['foodPhotoUrl'] as String?)?.isNotEmpty == true
          ? map['foodPhotoUrl'] as String
          : null,
    );
  }

  final String bio;
  final List<ProfilePrompt> prompts;
  final List<String> interests;
  final List<String> values;
  final List<String> musicGenres;
  final List<String> favoriteFoods;
  final List<String> ethnicities;
  final String? relationshipType;
  final String? datingIntention;
  final int? heightInches;
  final String? drinking;
  final String? smoking;
  final String? educationLevel;
  final String? familyPlans;
  final String? college;
  final int? distanceMiles;

  /// 0-100, only present when both people had enough mutually-visible
  /// fields set to compute anything meaningful from — see
  /// computeCompatibility in functions/index.js.
  final int? compatibilityPercent;

  /// The one photo (if any) this person tagged as "doing a hobby" / "food"
  /// in EditProfileScreen — see summarizeUserDoc in functions/index.js.
  final String? hobbyPhotoUrl;
  final String? foodPhotoUrl;

  String get heightLabel {
    final inches = heightInches;
    if (inches == null) return '';
    return '${inches ~/ 12}\'${inches % 12}"';
  }

  bool get hasAnyInfo =>
      bio.isNotEmpty ||
      prompts.isNotEmpty ||
      interests.isNotEmpty ||
      values.isNotEmpty ||
      musicGenres.isNotEmpty ||
      favoriteFoods.isNotEmpty ||
      ethnicities.isNotEmpty ||
      relationshipType != null ||
      datingIntention != null ||
      heightInches != null ||
      drinking != null ||
      smoking != null ||
      educationLevel != null ||
      familyPlans != null ||
      (college?.isNotEmpty ?? false);
}
