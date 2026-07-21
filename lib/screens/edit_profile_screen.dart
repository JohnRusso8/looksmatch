import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/profile_details.dart';
import '../models/profile_extras.dart';
import '../services/auth_controller.dart';
import '../services/profile_cache.dart';
import '../theme/app_theme.dart';
import 'prompt_edit_screen.dart';

/// One of the up-to-6 tiles shown in the photo grid — either an already
/// uploaded photo (has a URL + storagePath) or a freshly picked one still
/// waiting to be uploaded on save (has a local File).
class _PhotoSlot {
  _PhotoSlot.existing(this.photo) : file = null, category = photo!.category;
  _PhotoSlot.newFile(this.file) : photo = null, category = '';

  final ProfilePhoto? photo;
  final File? file;

  /// '' (untagged), 'hobby', or 'food' — mutable so the tag picker can
  /// update it in place without rebuilding the whole slot list. At most one
  /// slot may hold each non-empty value; see _setCategory.
  String category;

  bool get isExisting => photo != null;
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.auth,
    required this.profileCache,
  });

  final AuthController auth;
  final ProfileCache profileCache;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const int _maxPhotos = 6;
  static const List<String> _genderOptions = ['Man', 'Woman', 'Nonbinary'];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _collegeController = TextEditingController();
  final _picker = ImagePicker();

  final List<_PhotoSlot> _slots = [];
  final List<String> _removedStoragePaths = [];
  DateTime? _birthDate;
  String? _gender;
  String? _interestedIn;

  List<ProfilePrompt> _prompts = [];
  List<String> _interests = [];
  List<String> _values = [];
  List<String> _musicGenres = [];
  List<String> _favoriteFoods = [];
  List<String> _ethnicities = [];
  String? _relationshipType;
  List<String> _datingIntentions = [];
  String? _drinking;
  String? _smoking;
  String? _educationLevel;
  String? _familyPlans;
  int? _heightFeet;
  int? _heightRemainderInches;
  final Set<String> _hidden = {};

  // Loaded once and never edited directly by this screen — used as the
  // base for copyWith on save, so fields this screen doesn't manage (age
  // range, max distance, and every match-preference field, all owned by
  // PreferencesScreen) don't get silently wiped back to their defaults.
  ProfileDetails _originalDetails = const ProfileDetails();

  bool _pickingPhotos = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Seeded synchronously from the shared cache instead of awaiting a
    // fresh watchProfile()/watchProfileDetails() round-trip — the cache is
    // already warm by the time this screen is reachable in the overwhelming
    // majority of opens (see ProfileCache), so this renders real data on
    // the very first frame rather than a spinner.
    _applyLoaded(widget.profileCache.profile, widget.profileCache.details);
    if (!widget.profileCache.isReady) {
      widget.profileCache.addListener(_onCacheReady);
    }
  }

  @override
  void dispose() {
    widget.profileCache.removeListener(_onCacheReady);
    _nameController.dispose();
    _bioController.dispose();
    _collegeController.dispose();
    super.dispose();
  }

  void _onCacheReady() {
    if (!widget.profileCache.isReady) return;
    widget.profileCache.removeListener(_onCacheReady);
    if (!mounted) return;
    setState(
      () => _applyLoaded(
        widget.profileCache.profile,
        widget.profileCache.details,
      ),
    );
  }

  void _applyLoaded(Map<String, dynamic>? profile, ProfileDetails details) {
    final rawPhotos = profile?['photos'];
    final photos = rawPhotos is List
        ? rawPhotos.whereType<Map>().map((map) {
            return ProfilePhoto(
              url: (map['url'] ?? '').toString(),
              storagePath: (map['storagePath'] ?? '').toString(),
            );
          }).toList()
        : const <ProfilePhoto>[];

    _nameController.text = (profile?['name'] ?? '').toString();
    _gender = (profile?['gender'] as String?)?.isNotEmpty == true
        ? profile!['gender'] as String
        : null;
    _interestedIn = (profile?['interestedIn'] as String?)?.isNotEmpty == true
        ? profile!['interestedIn'] as String
        : null;
    _birthDate = _parseBirthDate(profile?['birthDate']);
    _slots
      ..clear()
      ..addAll(photos.map(_PhotoSlot.existing));

    _originalDetails = details;
    _bioController.text = details.bio;
    _collegeController.text = details.college;
    _prompts = List.of(details.prompts);
    _interests = List.of(details.interests);
    _values = List.of(details.values);
    _musicGenres = List.of(details.musicGenres);
    _favoriteFoods = List.of(details.favoriteFoods);
    _ethnicities = List.of(details.ethnicities);
    _relationshipType = details.relationshipType;
    _datingIntentions = List.of(details.datingIntentions);
    _drinking = details.drinking;
    _smoking = details.smoking;
    _educationLevel = details.educationLevel;
    _familyPlans = details.familyPlans;
    if (details.heightInches != null) {
      _heightFeet = details.heightInches! ~/ 12;
      _heightRemainderInches = details.heightInches! % 12;
    }
    _hidden.addAll(details.hiddenFields);
  }

  void _toggleHidden(String field) {
    setState(() {
      if (_hidden.contains(field)) {
        _hidden.remove(field);
      } else {
        _hidden.add(field);
      }
    });
  }

  Future<void> _addOrEditPrompt({int? existingIndex}) async {
    final usedPrompts = <String>{
      for (var i = 0; i < _prompts.length; i++)
        if (i != existingIndex) _prompts[i].prompt,
    };
    final available = kPromptOptions
        .where((p) => !usedPrompts.contains(p))
        .toList();
    final initialPrompt = existingIndex != null
        ? _prompts[existingIndex].prompt
        : null;
    // Keep the prompt currently assigned to this slot selectable even
    // though it's technically "in use" — by this same slot.
    final pickerOptions =
        initialPrompt != null && !available.contains(initialPrompt)
        ? [initialPrompt, ...available]
        : available;

    final result = await Navigator.push<ProfilePrompt>(
      context,
      MaterialPageRoute(
        builder: (_) => PromptEditScreen(
          availablePrompts: pickerOptions,
          initialPrompt: initialPrompt,
          initialAnswer: existingIndex != null
              ? _prompts[existingIndex].answer
              : '',
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      if (existingIndex != null) {
        _prompts[existingIndex] = result;
      } else {
        _prompts.add(result);
      }
    });
  }

  void _removePrompt(int index) {
    setState(() => _prompts.removeAt(index));
  }

  static const int _maxMultiSelect = 10;
  // Ethnicity/dating intentions have far fewer, more mutually-exclusive-ish
  // options than interests/values — a lower cap keeps the selection
  // meaningful instead of letting someone pick nearly every option.
  static const int _maxTraitMultiSelect = 3;

  void _toggleInList(
    List<String> list,
    String value, {
    int max = _maxMultiSelect,
  }) {
    setState(() {
      if (list.contains(value)) {
        list.remove(value);
      } else if (list.length < max) {
        list.add(value);
      }
    });
  }

  DateTime? _parseBirthDate(dynamic value) {
    if (value == null) return null;
    // Firestore Timestamp — avoid importing cloud_firestore here just for
    // this by duck-typing the toDate() call.
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickPhotos() async {
    if (_pickingPhotos || _slots.length >= _maxPhotos) return;

    setState(() => _pickingPhotos = true);

    try {
      final remaining = _maxPhotos - _slots.length;
      final picked = await _picker.pickMultiImage(imageQuality: 85);

      if (!mounted || picked.isEmpty) return;

      setState(() {
        _slots.addAll(
          picked
              .take(remaining)
              .map((file) => _PhotoSlot.newFile(File(file.path))),
        );
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not open your photos.');
    } finally {
      if (mounted) setState(() => _pickingPhotos = false);
    }
  }

  void _removeSlot(int index) {
    final slot = _slots[index];
    if (slot.isExisting) {
      _removedStoragePaths.add(slot.photo!.storagePath);
    }
    setState(() => _slots.removeAt(index));
  }

  // At most one photo per non-empty category — setting one clears it from
  // whichever other slot previously held it, mirroring how EditProfileScreen
  // treats every other single-value field.
  void _setCategory(int index, String category) {
    setState(() {
      if (category.isNotEmpty) {
        for (final slot in _slots) {
          if (slot.category == category) slot.category = '';
        }
      }
      _slots[index].category = category;
    });
  }

  Future<void> _pickPhotoTag(int index) async {
    final colors = context.colors;
    final current = _slots[index].category;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: colors.pageBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Tag this photo',
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Tagged photos get called out on your profile — one per tag.',
                  style: TextStyle(
                    color: colors.headerSecondaryText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.hiking_rounded, color: colors.accent),
                title: Text(
                  'Doing a hobby',
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: current == 'hobby'
                    ? Icon(Icons.check_rounded, color: colors.accent)
                    : null,
                onTap: () => Navigator.pop(sheetContext, 'hobby'),
              ),
              ListTile(
                leading: Icon(Icons.restaurant_rounded, color: colors.accent),
                title: Text(
                  'Food',
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: current == 'food'
                    ? Icon(Icons.check_rounded, color: colors.accent)
                    : null,
                onTap: () => Navigator.pop(sheetContext, 'food'),
              ),
              if (current.isNotEmpty)
                ListTile(
                  leading: Icon(
                    Icons.close_rounded,
                    color: colors.headerSecondaryText,
                  ),
                  title: Text(
                    'Remove tag',
                    style: TextStyle(
                      color: colors.headerSecondaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => Navigator.pop(sheetContext, ''),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;
    // Tapping the already-selected option is treated as "no change" rather
    // than clearing it — only the explicit "Remove tag" row clears.
    if (selected == current) return;
    _setCategory(index, selected);
  }

  Future<void> _chooseBirthDate() async {
    final now = DateTime.now();
    final maxBirthDate = DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: maxBirthDate,
      helpText: 'Select your birth date',
    );

    if (picked == null || !mounted) return;
    setState(() => _birthDate = picked);
  }

  String _formatDate(DateTime value) {
    const months = [
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
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }

  String? _validateForm() {
    if (_formKey.currentState?.validate() != true) {
      return 'Fill in your name to continue.';
    }
    if (_slots.isEmpty) {
      return 'Add at least one photo to continue.';
    }
    if (_birthDate == null) {
      return 'Add your birth date to continue.';
    }
    if (_gender == null) {
      return 'Choose your gender to continue.';
    }
    return null;
  }

  Future<void> _submit() async {
    final validationMessage = _validateForm();
    if (validationMessage != null) {
      _showMessage(validationMessage);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      final uploadedRaw = await Future.wait(
        _slots.map(
          (slot) => slot.isExisting
              ? Future.value(slot.photo!)
              : widget.auth.uploadProfilePhoto(slot.file!),
        ),
      );
      // uploadProfilePhoto returns a category-less ProfilePhoto (it doesn't
      // know about tagging), and an existing slot's stored category may
      // have changed this session — apply each slot's current category
      // in both cases rather than trusting what was already on the object.
      final uploaded = [
        for (var i = 0; i < uploadedRaw.length; i++)
          ProfilePhoto(
            url: uploadedRaw[i].url,
            storagePath: uploadedRaw[i].storagePath,
            category: _slots[i].category,
          ),
      ];

      await widget.auth.saveProfile(
        name: _nameController.text,
        birthDate: _birthDate!,
        gender: _gender!,
        // Not editable from this screen anymore — see PreferencesScreen —
        // but saveProfile requires it, so pass through whatever was
        // already set during onboarding.
        interestedIn: _interestedIn ?? 'Everyone',
        photos: uploaded,
      );

      final heightInches =
          (_heightFeet != null && _heightRemainderInches != null)
          ? _heightFeet! * 12 + _heightRemainderInches!
          : null;

      // copyWith rather than a fresh ProfileDetails(...) — this screen only
      // manages the fields below; age range / max distance / location /
      // every match-preference field belongs to PreferencesScreen, and
      // building from scratch here would silently wipe them back to their
      // defaults on every save.
      await widget.auth.saveProfileDetails(
        _originalDetails.copyWith(
          bio: _bioController.text.trim(),
          prompts: _prompts,
          interests: _interests,
          values: _values,
          musicGenres: _musicGenres,
          favoriteFoods: _favoriteFoods,
          ethnicities: _ethnicities,
          relationshipType: _relationshipType,
          datingIntentions: _datingIntentions,
          heightInches: heightInches,
          drinking: _drinking,
          smoking: _smoking,
          educationLevel: _educationLevel,
          familyPlans: _familyPlans,
          college: _collegeController.text.trim(),
          hiddenFields: _hidden,
        ),
      );

      // Only clean up removed Storage files after the new list has saved
      // successfully — if saveProfile had failed, the old photos are still
      // referenced and shouldn't be deleted out from under the profile.
      for (final storagePath in _removedStoragePaths) {
        unawaited(widget.auth.deleteProfilePhoto(storagePath));
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not save your profile. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.headerBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: colors.headerIconColor),
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: Text(
              _submitting ? 'Saving...' : 'Save',
              style: TextStyle(
                color: _submitting ? colors.headerSecondaryText : colors.accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionLabel(colors, 'Photos'),
                const SizedBox(height: 9),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount:
                      _slots.length + (_slots.length < _maxPhotos ? 1 : 0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 9,
                    mainAxisSpacing: 9,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, index) {
                    if (index == _slots.length) {
                      return _addPhotoTile(colors);
                    }
                    return _photoTile(colors, index);
                  },
                ),
                const SizedBox(height: 20),
                _sectionLabel(colors, 'Full name'),
                const SizedBox(height: 9),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Your name',
                    hintStyle: TextStyle(
                      color: colors.inputHint,
                      fontWeight: FontWeight.w600,
                    ),
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: colors.accent,
                    ),
                    filled: true,
                    fillColor: colors.inputBackground,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: colors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: colors.accent, width: 1.5),
                    ),
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Enter your name' : null,
                ),
                const SizedBox(height: 20),
                _sectionLabel(colors, 'Birth date'),
                const SizedBox(height: 9),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _chooseBirthDate,
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colors.inputBackground,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: colors.inputBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cake_outlined, color: colors.accent),
                          const SizedBox(width: 11),
                          Text(
                            _birthDate == null
                                ? 'Select your birth date'
                                : _formatDate(_birthDate!),
                            style: TextStyle(
                              color: _birthDate == null
                                  ? colors.inputHint
                                  : colors.headerPrimaryText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _sectionLabel(colors, 'I am a'),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _genderOptions
                      .map(
                        (option) => _choiceChip(
                          colors: colors,
                          label: option,
                          selected: _gender == option,
                          onTap: () => setState(() => _gender = option),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 28),
                Divider(color: colors.divider),
                const SizedBox(height: 8),
                Text(
                  'About you',
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'All optional — hide anything you\'d rather keep private.',
                  style: TextStyle(
                    color: colors.headerSecondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                _sectionHeader(colors, 'Bio', 'bio'),
                const SizedBox(height: 9),
                TextFormField(
                  controller: _bioController,
                  maxLength: 300,
                  maxLines: 4,
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tell people a bit about yourself',
                    hintStyle: TextStyle(color: colors.inputHint),
                    filled: true,
                    fillColor: colors.inputBackground,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: colors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: colors.accent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _sectionHeader(colors, 'Prompts', 'prompts'),
                const SizedBox(height: 4),
                Text(
                  'Choose up to 3.',
                  style: TextStyle(
                    color: colors.headerSecondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 9),
                ..._prompts.asMap().entries.map(
                  (entry) => _promptCard(colors, entry.key, entry.value),
                ),
                if (_prompts.length < 3)
                  OutlinedButton.icon(
                    onPressed: () => _addOrEditPrompt(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add a prompt'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.accent,
                      side: BorderSide(color: colors.accent.withOpacity(0.5)),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                const SizedBox(height: 20),
                _multiChoiceSection(
                  colors: colors,
                  label: 'Interests',
                  fieldKey: 'interests',
                  subtitle:
                      'Choose up to $_maxMultiSelect — shared answers boost '
                      'your compatibility with matches.',
                  options: kInterestOptions,
                  selected: _interests,
                  onToggle: (v) => _toggleInList(_interests, v),
                ),
                const SizedBox(height: 20),
                _multiChoiceSection(
                  colors: colors,
                  label: 'Values',
                  fieldKey: 'values',
                  subtitle: 'Choose up to $_maxMultiSelect.',
                  options: kValuesOptions,
                  selected: _values,
                  onToggle: (v) => _toggleInList(_values, v),
                ),
                const SizedBox(height: 20),
                _multiChoiceSection(
                  colors: colors,
                  label: 'Music taste',
                  fieldKey: 'musicGenres',
                  subtitle: 'Choose up to $_maxMultiSelect.',
                  options: kMusicGenreOptions,
                  selected: _musicGenres,
                  onToggle: (v) => _toggleInList(_musicGenres, v),
                ),
                const SizedBox(height: 20),
                _multiChoiceSection(
                  colors: colors,
                  label: 'Favorite food',
                  fieldKey: 'favoriteFoods',
                  subtitle: 'Choose up to $_maxMultiSelect.',
                  options: kFavoriteFoodOptions,
                  selected: _favoriteFoods,
                  onToggle: (v) => _toggleInList(_favoriteFoods, v),
                ),
                const SizedBox(height: 20),
                _multiChoiceSection(
                  colors: colors,
                  label: 'Ethnicity',
                  fieldKey: 'ethnicity',
                  subtitle: 'Choose up to $_maxTraitMultiSelect.',
                  options: kEthnicityOptions,
                  selected: _ethnicities,
                  onToggle: (v) =>
                      _toggleInList(_ethnicities, v, max: _maxTraitMultiSelect),
                ),
                const SizedBox(height: 20),
                _choiceSection(
                  colors: colors,
                  label: 'Relationship type',
                  fieldKey: 'relationshipType',
                  options: kRelationshipTypeOptions,
                  value: _relationshipType,
                  onChanged: (v) => setState(() => _relationshipType = v),
                ),
                const SizedBox(height: 20),
                _multiChoiceSection(
                  colors: colors,
                  label: 'Dating intentions',
                  fieldKey: 'datingIntention',
                  subtitle: 'Choose up to $_maxTraitMultiSelect.',
                  options: kDatingIntentionOptions,
                  selected: _datingIntentions,
                  onToggle: (v) => _toggleInList(
                    _datingIntentions,
                    v,
                    max: _maxTraitMultiSelect,
                  ),
                ),
                const SizedBox(height: 20),
                _sectionHeader(colors, 'Height', 'height'),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: _heightDropdown(
                        colors: colors,
                        label: 'ft',
                        value: _heightFeet,
                        range: const [4, 5, 6, 7],
                        onChanged: (v) => setState(() => _heightFeet = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _heightDropdown(
                        colors: colors,
                        label: 'in',
                        value: _heightRemainderInches,
                        range: const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
                        onChanged: (v) =>
                            setState(() => _heightRemainderInches = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _choiceSection(
                  colors: colors,
                  label: 'Do you drink?',
                  fieldKey: 'drinking',
                  options: kFrequencyOptions,
                  value: _drinking,
                  onChanged: (v) => setState(() => _drinking = v),
                ),
                const SizedBox(height: 20),
                _choiceSection(
                  colors: colors,
                  label: 'Do you smoke?',
                  fieldKey: 'smoking',
                  options: kFrequencyOptions,
                  value: _smoking,
                  onChanged: (v) => setState(() => _smoking = v),
                ),
                const SizedBox(height: 20),
                _choiceSection(
                  colors: colors,
                  label: 'Education level',
                  fieldKey: 'educationLevel',
                  options: kEducationOptions,
                  value: _educationLevel,
                  onChanged: (v) => setState(() => _educationLevel = v),
                ),
                const SizedBox(height: 20),
                _choiceSection(
                  colors: colors,
                  label: 'Family plans',
                  fieldKey: 'familyPlans',
                  options: kFamilyPlansOptions,
                  value: _familyPlans,
                  onChanged: (v) => setState(() => _familyPlans = v),
                ),
                const SizedBox(height: 20),
                _sectionHeader(colors, 'College', 'college'),
                const SizedBox(height: 9),
                TextFormField(
                  controller: _collegeController,
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Where did you go to school?',
                    hintStyle: TextStyle(
                      color: colors.inputHint,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: colors.inputBackground,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: colors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: colors.accent, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(LooksMatchColors colors, String label) {
    return Text(
      label,
      style: TextStyle(
        color: colors.headerPrimaryText,
        fontSize: 13.5,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  /// A section label paired with a show/hide toggle for [fieldKey] — used
  /// on every optional "about you" field so it's obvious per-field whether
  /// other people will see it.
  Widget _sectionHeader(
    LooksMatchColors colors,
    String label,
    String fieldKey,
  ) {
    final hidden = _hidden.contains(fieldKey);

    return Row(
      children: [
        Expanded(child: _sectionLabel(colors, label)),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _toggleHidden(fieldKey),
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hidden
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 15,
                    color: hidden ? colors.headerSecondaryText : colors.accent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    hidden ? 'Hidden' : 'Visible',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: hidden
                          ? colors.headerSecondaryText
                          : colors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _choiceSection({
    required LooksMatchColors colors,
    required String label,
    required String fieldKey,
    required List<String> options,
    required String? value,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(colors, label, fieldKey),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (option) => _choiceChip(
                  colors: colors,
                  label: option,
                  selected: value == option,
                  onTap: () => onChanged(option),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _multiChoiceSection({
    required LooksMatchColors colors,
    required String label,
    required String fieldKey,
    required String subtitle,
    required List<String> options,
    required List<String> selected,
    required ValueChanged<String> onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(colors, label, fieldKey),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: colors.headerSecondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (option) => _choiceChip(
                  colors: colors,
                  label: option,
                  selected: selected.contains(option),
                  onTap: () => onToggle(option),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _heightDropdown({
    required LooksMatchColors colors,
    required String label,
    required int? value,
    required List<int> range,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      style: TextStyle(
        color: colors.headerPrimaryText,
        fontWeight: FontWeight.w700,
      ),
      dropdownColor: colors.cardBackground,
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: colors.inputHint),
        filled: true,
        fillColor: colors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: colors.accent, width: 1.5),
        ),
      ),
      items: range
          .map((v) => DropdownMenuItem(value: v, child: Text('$v $label')))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _promptCard(LooksMatchColors colors, int index, ProfilePrompt prompt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.inputBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prompt.prompt,
                  style: TextStyle(
                    color: colors.headerSecondaryText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  prompt.answer,
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _addOrEditPrompt(existingIndex: index),
            icon: Icon(Icons.edit_outlined, color: colors.accent, size: 19),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: () => _removePrompt(index),
            icon: Icon(
              Icons.close_rounded,
              color: colors.deleteBackground,
              size: 19,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _choiceChip({
    required LooksMatchColors colors,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? colors.chipSelectedBackground
                : colors.chipUnselectedBackground,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? colors.chipSelectedBackground
                  : colors.chipBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? colors.chipSelectedText
                  : colors.chipUnselectedText,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _addPhotoTile(LooksMatchColors colors) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickingPhotos ? null : _pickPhotos,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: colors.inputBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.accent.withOpacity(0.45),
              width: 1.4,
            ),
          ),
          alignment: Alignment.center,
          child: _pickingPhotos
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.accent,
                  ),
                )
              : Icon(Icons.add_a_photo_outlined, color: colors.accent),
        ),
      ),
    );
  }

  Widget _photoTile(LooksMatchColors colors, int index) {
    final slot = _slots[index];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          slot.isExisting
              ? Image.network(
                  slot.photo!.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: colors.inputBackground,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: colors.headerSecondaryText,
                    ),
                  ),
                )
              : Image.file(slot.file!, fit: BoxFit.cover),
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: () => _removeSlot(index),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: GestureDetector(
              onTap: () => _pickPhotoTag(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      switch (slot.category) {
                        'hobby' => Icons.hiking_rounded,
                        'food' => Icons.restaurant_rounded,
                        _ => Icons.local_offer_outlined,
                      },
                      color: Colors.white,
                      size: 13,
                    ),
                    if (slot.category.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        slot.category == 'hobby' ? 'Hobby' : 'Food',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
