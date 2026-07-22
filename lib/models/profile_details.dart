import 'profile_extras.dart';

/// Preset prompts a user can pick up to 3 of and answer in their own words.
const List<String> kPromptOptions = [
  'A perfect first date is...',
  'The way to win me over is...',
  'I\'m weirdly competitive about...',
  'My most controversial opinion is...',
  'I\'ll know it\'s time to leave the party when...',
  'Two truths and a lie...',
  'My simple pleasures are...',
  'The key to my heart is...',
  'I go crazy for...',
  'A shower thought I recently had...',
  'My love language is...',
  'Together, we could...',
  'I\'m looking for someone who...',
  'My friends would describe me as...',
  'The best travel story I have...',
  'I geek out on...',
  'Ask me about...',
  'A non-negotiable for me is...',
];

const List<String> kEthnicityOptions = [
  'Black/African Descent',
  'East Asian',
  'South Asian',
  'Southeast Asian',
  'Hispanic/Latino',
  'Middle Eastern',
  'Native American',
  'Pacific Islander',
  'White/Caucasian',
  'Multiracial',
  'Other',
  'Prefer not to say',
];

const List<String> kRelationshipTypeOptions = [
  'Monogamy',
  'Non-monogamy',
  'Figuring out my relationship type',
  'Prefer not to say',
];

const List<String> kDatingIntentionOptions = [
  'Life partner',
  'Long-term relationship',
  'Long-term, open to short',
  'Short-term, open to long',
  'Short-term fun',
  'New friends',
  'Still figuring it out',
];

const List<String> kFrequencyOptions = [
  'Yes',
  'Sometimes',
  'No',
  'Prefer not to say',
];

const List<String> kEducationOptions = [
  'High school',
  'In college',
  'Bachelor\'s degree',
  'Master\'s degree',
  'PhD',
  'Trade/vocational school',
  'Prefer not to say',
];

/// Preset interests a user can multi-select from — also the basis for the
/// shared-interests portion of the compatibility score computed server-side
/// (see computeCompatibility in functions/index.js).
const List<String> kInterestOptions = [
  'Bar hopping',
  'Reading',
  'Hiking',
  'Cooking',
  'Traveling',
  'Fitness',
  'Yoga',
  'Movies & TV',
  'Live music',
  'Gaming',
  'Photography',
  'Art & museums',
  'Foodie',
  'Coffee',
  'Wine tasting',
  'Dancing',
  'Running',
  'Cycling',
  'Camping',
  'Beach days',
  'Board games',
  'Concerts',
  'Volunteering',
  'Pets',
  'Fashion',
  'Tech',
  'Sports',
  'Meditation',
  'Writing',
  'Comedy shows',
  'Karaoke',
];

/// Preset personal values a user can multi-select from — same overlap-based
/// compatibility treatment as interests (see computeCompatibility in
/// functions/index.js).
const List<String> kValuesOptions = [
  'Family-oriented',
  'Career-driven',
  'Spirituality',
  'Adventurous',
  'Environmentally conscious',
  'Community-minded',
  'Financially responsible',
  'Creativity',
  'Honesty',
  'Loyalty',
  'Personal growth',
  'Independence',
  'Health & wellness',
  'Open-mindedness',
  'Traditional values',
  'Social justice',
  'Education',
  'Humor',
  'Ambition',
  'Stability',
];

const List<String> kMusicGenreOptions = [
  'Pop',
  'Hip-Hop/Rap',
  'R&B',
  'Rock',
  'Indie',
  'Alternative',
  'Country',
  'EDM/Electronic',
  'Jazz',
  'Classical',
  'Latin',
  'K-Pop',
  'Reggae/Reggaeton',
  'Metal',
  'Folk/Acoustic',
  'Punk',
  'Soul/Funk',
  'Gospel/Christian',
  'Afrobeats',
  'Musical theatre',
];

const List<String> kFavoriteFoodOptions = [
  'Italian',
  'Mexican',
  'Chinese',
  'Japanese/Sushi',
  'Thai',
  'Indian',
  'Korean',
  'Mediterranean',
  'American/BBQ',
  'French',
  'Vietnamese',
  'Middle Eastern',
  'Spanish/Tapas',
  'Caribbean',
  'Vegan/Vegetarian',
  'Southern/Soul food',
  'Greek',
  'Ethiopian',
  'Seafood',
  'Desserts/Sweets',
];

/// Preset stances on having/wanting children — shown as a self-description
/// trait (with its own visibility toggle) and usable as a preference filter
/// (see preferredFamilyPlans below and matchesTraitPreferences in
/// functions/index.js).
const List<String> kFamilyPlansOptions = [
  'Don\'t want children',
  'Want children someday',
  'Open to children',
  'Have children',
  'Not sure yet',
];

/// Every profile-detail field that has its own show/hide toggle. Keys match
/// the Firestore field names in profileDetails/{uid}.fieldVisibility.
const List<String> kVisibilityFields = [
  'bio',
  'prompts',
  'interests',
  'values',
  'musicGenres',
  'favoriteFoods',
  'ethnicity',
  'relationshipType',
  'datingIntention',
  'height',
  'drinking',
  'smoking',
  'educationLevel',
  'college',
  'familyPlans',
];

/// This user's own bio/prompts/traits, their per-field visibility choices,
/// and their private matching preferences (age range, max distance). Read
/// and written only for the signed-in user's own profileDetails/{uid} doc —
/// what other people see of this is the filtered ProfileExtras a Cloud
/// Function hands back, not this class.
class ProfileDetails {
  const ProfileDetails({
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
    this.college = '',
    this.city = '',
    this.state,
    this.ageRangeMin,
    this.ageRangeMax,
    this.maxDistanceMiles,
    this.preferredEthnicities = const [],
    this.minHeightInches,
    this.maxHeightInches,
    this.preferredRelationshipTypes = const [],
    this.preferredFamilyPlans = const [],
    this.preferredEducationLevels = const [],
    this.hiddenFields = const {},
  });

  factory ProfileDetails.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ProfileDetails();

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
    // accept either shape so any already-saved single value still shows up
    // instead of silently disappearing.
    List<String> parseMultiOrLegacySingle(dynamic raw) {
      if (raw is List) {
        return raw.map((i) => i.toString()).where((i) => i.isNotEmpty).toList();
      }
      if (raw is String && raw.isNotEmpty) return [raw];
      return const <String>[];
    }

    // datingIntention briefly became multi-select and then reverted back to
    // single-select — some already-saved profiles may still have a one-item
    // list from that window, so accept either shape and just take the
    // first value.
    String? parseSingleOrLegacyList(dynamic raw) {
      if (raw is List) {
        return raw.isNotEmpty ? raw.first.toString() : null;
      }
      if (raw is String && raw.isNotEmpty) return raw;
      return null;
    }

    final interests = parseStringList(map['interests']);
    final values = parseStringList(map['values']);
    final musicGenres = parseStringList(map['musicGenres']);
    final favoriteFoods = parseStringList(map['favoriteFoods']);
    final ethnicities = parseMultiOrLegacySingle(map['ethnicity']);
    final datingIntention = parseSingleOrLegacyList(map['datingIntention']);
    final preferredEthnicities = parseStringList(map['preferredEthnicities']);
    final preferredRelationshipTypes = parseStringList(
      map['preferredRelationshipTypes'],
    );
    final preferredFamilyPlans = parseStringList(map['preferredFamilyPlans']);
    final preferredEducationLevels = parseStringList(
      map['preferredEducationLevels'],
    );

    final rawVisibility = map['fieldVisibility'];
    final hidden = <String>{};
    if (rawVisibility is Map) {
      rawVisibility.forEach((key, value) {
        if (value == false) hidden.add(key.toString());
      });
    }

    return ProfileDetails(
      bio: (map['bio'] ?? '').toString(),
      prompts: prompts,
      interests: interests,
      values: values,
      musicGenres: musicGenres,
      favoriteFoods: favoriteFoods,
      ethnicities: ethnicities,
      relationshipType: map['relationshipType'] as String?,
      datingIntention: datingIntention,
      heightInches: (map['height'] as num?)?.toInt(),
      drinking: map['drinking'] as String?,
      smoking: map['smoking'] as String?,
      educationLevel: map['educationLevel'] as String?,
      familyPlans: map['familyPlans'] as String?,
      college: (map['college'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      state: map['state'] as String?,
      ageRangeMin: (map['ageRangeMin'] as num?)?.toInt(),
      ageRangeMax: (map['ageRangeMax'] as num?)?.toInt(),
      maxDistanceMiles: (map['maxDistanceMiles'] as num?)?.toInt(),
      preferredEthnicities: preferredEthnicities,
      minHeightInches: (map['minHeightInches'] as num?)?.toInt(),
      maxHeightInches: (map['maxHeightInches'] as num?)?.toInt(),
      preferredRelationshipTypes: preferredRelationshipTypes,
      preferredFamilyPlans: preferredFamilyPlans,
      preferredEducationLevels: preferredEducationLevels,
      hiddenFields: hidden,
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
  final String college;

  /// The city/state typed into the location field — kept only so the edit
  /// screen can show what was last set. Never shown to other users; the
  /// coordinates geocoded from it live separately in the admin-only
  /// locations/{uid} doc, and only a rounded distance is ever shared.
  final String city;
  final String? state;

  final int? ageRangeMin;
  final int? ageRangeMax;
  final int? maxDistanceMiles;

  /// Matching preferences below — private, never shown on this user's
  /// profile, used only server-side to filter who shows up in Discover
  /// (see matchesTraitPreferences in functions/index.js). An empty list or
  /// unset range means "no preference" — nobody gets excluded on that
  /// dimension until the user actively sets one.
  final List<String> preferredEthnicities;
  final int? minHeightInches;
  final int? maxHeightInches;
  final List<String> preferredRelationshipTypes;
  final List<String> preferredFamilyPlans;
  final List<String> preferredEducationLevels;

  final Set<String> hiddenFields;

  bool isHidden(String field) => hiddenFields.contains(field);

  ProfileDetails copyWith({
    String? bio,
    List<ProfilePrompt>? prompts,
    List<String>? interests,
    List<String>? values,
    List<String>? musicGenres,
    List<String>? favoriteFoods,
    List<String>? ethnicities,
    String? relationshipType,
    String? datingIntention,
    int? heightInches,
    String? drinking,
    String? smoking,
    String? educationLevel,
    String? familyPlans,
    String? college,
    String? city,
    String? state,
    int? ageRangeMin,
    int? ageRangeMax,
    int? maxDistanceMiles,
    List<String>? preferredEthnicities,
    int? minHeightInches,
    int? maxHeightInches,
    List<String>? preferredRelationshipTypes,
    List<String>? preferredFamilyPlans,
    List<String>? preferredEducationLevels,
    Set<String>? hiddenFields,
  }) {
    return ProfileDetails(
      bio: bio ?? this.bio,
      prompts: prompts ?? this.prompts,
      interests: interests ?? this.interests,
      values: values ?? this.values,
      musicGenres: musicGenres ?? this.musicGenres,
      favoriteFoods: favoriteFoods ?? this.favoriteFoods,
      ethnicities: ethnicities ?? this.ethnicities,
      relationshipType: relationshipType ?? this.relationshipType,
      datingIntention: datingIntention ?? this.datingIntention,
      heightInches: heightInches ?? this.heightInches,
      drinking: drinking ?? this.drinking,
      smoking: smoking ?? this.smoking,
      educationLevel: educationLevel ?? this.educationLevel,
      familyPlans: familyPlans ?? this.familyPlans,
      college: college ?? this.college,
      city: city ?? this.city,
      state: state ?? this.state,
      ageRangeMin: ageRangeMin ?? this.ageRangeMin,
      ageRangeMax: ageRangeMax ?? this.ageRangeMax,
      maxDistanceMiles: maxDistanceMiles ?? this.maxDistanceMiles,
      preferredEthnicities: preferredEthnicities ?? this.preferredEthnicities,
      minHeightInches: minHeightInches ?? this.minHeightInches,
      maxHeightInches: maxHeightInches ?? this.maxHeightInches,
      preferredRelationshipTypes:
          preferredRelationshipTypes ?? this.preferredRelationshipTypes,
      preferredFamilyPlans: preferredFamilyPlans ?? this.preferredFamilyPlans,
      preferredEducationLevels:
          preferredEducationLevels ?? this.preferredEducationLevels,
      hiddenFields: hiddenFields ?? this.hiddenFields,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bio': bio,
      'prompts': prompts.map((p) => p.toMap()).toList(),
      'interests': interests,
      'values': values,
      'musicGenres': musicGenres,
      'favoriteFoods': favoriteFoods,
      'ethnicity': ethnicities,
      'relationshipType': relationshipType,
      'datingIntention': datingIntention,
      'height': heightInches,
      'drinking': drinking,
      'smoking': smoking,
      'educationLevel': educationLevel,
      'familyPlans': familyPlans,
      'college': college,
      'city': city,
      'state': state,
      'ageRangeMin': ageRangeMin,
      'ageRangeMax': ageRangeMax,
      'maxDistanceMiles': maxDistanceMiles,
      'preferredEthnicities': preferredEthnicities,
      'minHeightInches': minHeightInches,
      'maxHeightInches': maxHeightInches,
      'preferredRelationshipTypes': preferredRelationshipTypes,
      'preferredFamilyPlans': preferredFamilyPlans,
      'preferredEducationLevels': preferredEducationLevels,
      'fieldVisibility': {
        for (final field in kVisibilityFields)
          field: !hiddenFields.contains(field),
      },
    };
  }
}
