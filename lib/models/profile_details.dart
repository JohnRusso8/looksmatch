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

const List<String> kFrequencyOptions = ['Yes', 'Sometimes', 'No', 'Prefer not to say'];

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

const List<String> kUsStates = [
  'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
  'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
  'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
  'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
  'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY',
  'DC',
];

/// Every profile-detail field that has its own show/hide toggle. Keys match
/// the Firestore field names in profileDetails/{uid}.fieldVisibility.
const List<String> kVisibilityFields = [
  'bio',
  'prompts',
  'interests',
  'ethnicity',
  'relationshipType',
  'datingIntention',
  'height',
  'drinking',
  'smoking',
  'educationLevel',
  'college',
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
    this.ethnicity,
    this.relationshipType,
    this.datingIntention,
    this.heightInches,
    this.drinking,
    this.smoking,
    this.educationLevel,
    this.college = '',
    this.city = '',
    this.state,
    this.ageRangeMin,
    this.ageRangeMax,
    this.maxDistanceMiles,
    this.hiddenFields = const {},
  });

  factory ProfileDetails.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ProfileDetails();

    final rawPrompts = map['prompts'];
    final prompts = rawPrompts is List
        ? rawPrompts.whereType<Map>().map(ProfilePrompt.fromMap).toList()
        : const <ProfilePrompt>[];

    final rawInterests = map['interests'];
    final interests = rawInterests is List
        ? rawInterests.map((i) => i.toString()).where((i) => i.isNotEmpty).toList()
        : const <String>[];

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
      ethnicity: map['ethnicity'] as String?,
      relationshipType: map['relationshipType'] as String?,
      datingIntention: map['datingIntention'] as String?,
      heightInches: (map['height'] as num?)?.toInt(),
      drinking: map['drinking'] as String?,
      smoking: map['smoking'] as String?,
      educationLevel: map['educationLevel'] as String?,
      college: (map['college'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      state: map['state'] as String?,
      ageRangeMin: (map['ageRangeMin'] as num?)?.toInt(),
      ageRangeMax: (map['ageRangeMax'] as num?)?.toInt(),
      maxDistanceMiles: (map['maxDistanceMiles'] as num?)?.toInt(),
      hiddenFields: hidden,
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
  final Set<String> hiddenFields;

  bool isHidden(String field) => hiddenFields.contains(field);

  ProfileDetails copyWith({
    String? bio,
    List<ProfilePrompt>? prompts,
    List<String>? interests,
    String? ethnicity,
    String? relationshipType,
    String? datingIntention,
    int? heightInches,
    String? drinking,
    String? smoking,
    String? educationLevel,
    String? college,
    String? city,
    String? state,
    int? ageRangeMin,
    int? ageRangeMax,
    int? maxDistanceMiles,
    Set<String>? hiddenFields,
  }) {
    return ProfileDetails(
      bio: bio ?? this.bio,
      prompts: prompts ?? this.prompts,
      interests: interests ?? this.interests,
      ethnicity: ethnicity ?? this.ethnicity,
      relationshipType: relationshipType ?? this.relationshipType,
      datingIntention: datingIntention ?? this.datingIntention,
      heightInches: heightInches ?? this.heightInches,
      drinking: drinking ?? this.drinking,
      smoking: smoking ?? this.smoking,
      educationLevel: educationLevel ?? this.educationLevel,
      college: college ?? this.college,
      city: city ?? this.city,
      state: state ?? this.state,
      ageRangeMin: ageRangeMin ?? this.ageRangeMin,
      ageRangeMax: ageRangeMax ?? this.ageRangeMax,
      maxDistanceMiles: maxDistanceMiles ?? this.maxDistanceMiles,
      hiddenFields: hiddenFields ?? this.hiddenFields,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bio': bio,
      'prompts': prompts.map((p) => p.toMap()).toList(),
      'interests': interests,
      'ethnicity': ethnicity,
      'relationshipType': relationshipType,
      'datingIntention': datingIntention,
      'height': heightInches,
      'drinking': drinking,
      'smoking': smoking,
      'educationLevel': educationLevel,
      'college': college,
      'city': city,
      'state': state,
      'ageRangeMin': ageRangeMin,
      'ageRangeMax': ageRangeMax,
      'maxDistanceMiles': maxDistanceMiles,
      'fieldVisibility': {
        for (final field in kVisibilityFields) field: !hiddenFields.contains(field),
      },
    };
  }
}
