import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';

import '../models/profile_details.dart';
import '../models/profile_extras.dart';
import '../services/auth_controller.dart';
import '../theme/app_theme.dart';
import 'prompt_edit_screen.dart';

/// One of the up-to-6 tiles shown in the photo grid — either an already
/// uploaded photo (has a URL + storagePath) or a freshly picked one still
/// waiting to be uploaded on save (has a local File).
class _PhotoSlot {
  _PhotoSlot.existing(this.photo) : file = null;
  _PhotoSlot.newFile(this.file) : photo = null;

  final ProfilePhoto? photo;
  final File? file;

  bool get isExisting => photo != null;
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const int _maxPhotos = 6;
  static const List<String> _genderOptions = ['Man', 'Woman', 'Nonbinary'];
  static const List<String> _interestOptions = ['Men', 'Women', 'Everyone'];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _collegeController = TextEditingController();
  final _cityController = TextEditingController();
  final _picker = ImagePicker();

  final List<_PhotoSlot> _slots = [];
  final List<String> _removedStoragePaths = [];
  DateTime? _birthDate;
  String? _gender;
  String? _interestedIn;

  List<ProfilePrompt> _prompts = [];
  List<String> _interests = [];
  String? _ethnicity;
  String? _relationshipType;
  String? _datingIntention;
  String? _drinking;
  String? _smoking;
  String? _educationLevel;
  int? _heightFeet;
  int? _heightRemainderInches;
  final Set<String> _hidden = {};

  bool _limitAge = false;
  RangeValues _ageRange = const RangeValues(18, 55);
  bool _limitDistance = false;
  double _maxDistance = 25;
  String? _state;
  bool _settingLocation = false;

  bool _loading = true;
  bool _pickingPhotos = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _collegeController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentProfile() async {
    final results = await Future.wait([
      widget.auth.watchProfile().first,
      widget.auth.watchProfileDetails().first,
    ]);

    if (!mounted) return;

    final profile = results[0] as Map<String, dynamic>?;
    final details = results[1] as ProfileDetails;

    final rawPhotos = profile?['photos'];
    final photos = rawPhotos is List
        ? rawPhotos.whereType<Map>().map((map) {
            return ProfilePhoto(
              url: (map['url'] ?? '').toString(),
              storagePath: (map['storagePath'] ?? '').toString(),
            );
          }).toList()
        : const <ProfilePhoto>[];

    setState(() {
      _nameController.text = (profile?['name'] ?? '').toString();
      _gender = (profile?['gender'] as String?)?.isNotEmpty == true
          ? profile!['gender'] as String
          : null;
      _interestedIn = (profile?['interestedIn'] as String?)?.isNotEmpty == true
          ? profile!['interestedIn'] as String
          : null;
      _birthDate = _parseBirthDate(profile?['birthDate']);
      _slots.addAll(photos.map(_PhotoSlot.existing));

      _bioController.text = details.bio;
      _collegeController.text = details.college;
      _cityController.text = details.city;
      _state = details.state;
      _prompts = List.of(details.prompts);
      _interests = List.of(details.interests);
      _ethnicity = details.ethnicity;
      _relationshipType = details.relationshipType;
      _datingIntention = details.datingIntention;
      _drinking = details.drinking;
      _smoking = details.smoking;
      _educationLevel = details.educationLevel;
      if (details.heightInches != null) {
        _heightFeet = details.heightInches! ~/ 12;
        _heightRemainderInches = details.heightInches! % 12;
      }
      _hidden.addAll(details.hiddenFields);

      _limitAge = details.ageRangeMin != null || details.ageRangeMax != null;
      _ageRange = RangeValues(
        (details.ageRangeMin ?? 18).toDouble(),
        (details.ageRangeMax ?? 55).toDouble(),
      );
      _limitDistance = details.maxDistanceMiles != null;
      _maxDistance = (details.maxDistanceMiles ?? 25).toDouble();

      _loading = false;
    });
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
    final available = kPromptOptions.where((p) => !usedPrompts.contains(p)).toList();
    final initialPrompt = existingIndex != null ? _prompts[existingIndex].prompt : null;
    // Keep the prompt currently assigned to this slot selectable even
    // though it's technically "in use" — by this same slot.
    final pickerOptions = initialPrompt != null && !available.contains(initialPrompt)
        ? [initialPrompt, ...available]
        : available;

    final result = await Navigator.push<ProfilePrompt>(
      context,
      MaterialPageRoute(
        builder: (_) => PromptEditScreen(
          availablePrompts: pickerOptions,
          initialPrompt: initialPrompt,
          initialAnswer: existingIndex != null ? _prompts[existingIndex].answer : '',
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

  static const int _maxInterests = 10;

  void _toggleInterest(String interest) {
    setState(() {
      if (_interests.contains(interest)) {
        _interests.remove(interest);
      } else if (_interests.length < _maxInterests) {
        _interests.add(interest);
      }
    });
  }

  // Uses on-device forward geocoding (no location permission needed — this
  // just resolves the typed city/state to coordinates, it never reads the
  // device's actual position) so the distance shown to matches is based on
  // wherever the user says they are, not GPS.
  Future<void> _setLocation() async {
    final city = _cityController.text.trim();
    if (city.isEmpty || _state == null) {
      _showMessage('Enter a city and state first.');
      return;
    }

    setState(() => _settingLocation = true);
    try {
      final results = await Geocoding().locationFromAddress('$city, $_state, USA');
      if (results.isEmpty) {
        if (!mounted) return;
        _showMessage('Could not find that city. Check the spelling and try again.');
        return;
      }

      final location = results.first;
      await widget.auth.updateLocation(
        lat: location.latitude,
        lng: location.longitude,
      );

      if (!mounted) return;
      _showMessage('Location set to $city, $_state.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not set your location. Please try again.');
    } finally {
      if (mounted) setState(() => _settingLocation = false);
    }
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
    if (_interestedIn == null) {
      return 'Choose who you\'re interested in to continue.';
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
      final uploaded = await Future.wait(
        _slots.map(
          (slot) => slot.isExisting
              ? Future.value(slot.photo!)
              : widget.auth.uploadProfilePhoto(slot.file!),
        ),
      );

      await widget.auth.saveProfile(
        name: _nameController.text,
        birthDate: _birthDate!,
        gender: _gender!,
        interestedIn: _interestedIn!,
        photos: uploaded,
      );

      final heightInches = (_heightFeet != null && _heightRemainderInches != null)
          ? _heightFeet! * 12 + _heightRemainderInches!
          : null;

      await widget.auth.saveProfileDetails(
        ProfileDetails(
          bio: _bioController.text.trim(),
          prompts: _prompts,
          interests: _interests,
          ethnicity: _ethnicity,
          relationshipType: _relationshipType,
          datingIntention: _datingIntention,
          heightInches: heightInches,
          drinking: _drinking,
          smoking: _smoking,
          educationLevel: _educationLevel,
          college: _collegeController.text.trim(),
          city: _cityController.text.trim(),
          state: _state,
          ageRangeMin: _limitAge ? _ageRange.start.round() : null,
          ageRangeMax: _limitAge ? _ageRange.end.round() : null,
          maxDistanceMiles: _limitDistance ? _maxDistance.round() : null,
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
            onPressed: _submitting || _loading ? null : _submit,
            child: Text(
              _submitting ? 'Saving...' : 'Save',
              style: TextStyle(
                color: _submitting || _loading
                    ? colors.headerSecondaryText
                    : colors.accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.accent))
          : SafeArea(
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
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
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
                            borderSide:
                                BorderSide(color: colors.accent, width: 1.5),
                          ),
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter your name'
                            : null,
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
                                onTap: () =>
                                    setState(() => _gender = option),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                      _sectionLabel(colors, 'Interested in'),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _interestOptions
                            .map(
                              (option) => _choiceChip(
                                colors: colors,
                                label: option,
                                selected: _interestedIn == option,
                                onTap: () =>
                                    setState(() => _interestedIn = option),
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
                      _sectionHeader(colors, 'Interests', 'interests'),
                      const SizedBox(height: 4),
                      Text(
                        'Choose up to $_maxInterests — shared interests boost your '
                        'compatibility with matches.',
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
                        children: kInterestOptions
                            .map(
                              (option) => _choiceChip(
                                colors: colors,
                                label: option,
                                selected: _interests.contains(option),
                                onTap: () => _toggleInterest(option),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                      _choiceSection(
                        colors: colors,
                        label: 'Ethnicity',
                        fieldKey: 'ethnicity',
                        options: kEthnicityOptions,
                        value: _ethnicity,
                        onChanged: (v) => setState(() => _ethnicity = v),
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
                      _choiceSection(
                        colors: colors,
                        label: 'Dating intentions',
                        fieldKey: 'datingIntention',
                        options: kDatingIntentionOptions,
                        value: _datingIntention,
                        onChanged: (v) => setState(() => _datingIntention = v),
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
                              onChanged: (v) => setState(() => _heightRemainderInches = v),
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
                      const SizedBox(height: 28),
                      Divider(color: colors.divider),
                      const SizedBox(height: 8),
                      Text(
                        'Dating preferences',
                        style: TextStyle(
                          color: colors.headerPrimaryText,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Private — only used to choose your matches, never shown '
                        'on your profile.',
                        style: TextStyle(
                          color: colors.headerSecondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _prefToggleRow(
                        colors: colors,
                        label: 'Limit by age range',
                        value: _limitAge,
                        onChanged: (v) => setState(() => _limitAge = v),
                      ),
                      if (_limitAge) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${_ageRange.start.round()} – ${_ageRange.end.round()}',
                          style: TextStyle(
                            color: colors.headerPrimaryText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        RangeSlider(
                          values: _ageRange,
                          min: 18,
                          max: 80,
                          divisions: 62,
                          activeColor: colors.accent,
                          labels: RangeLabels(
                            _ageRange.start.round().toString(),
                            _ageRange.end.round().toString(),
                          ),
                          onChanged: (v) => setState(() => _ageRange = v),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _prefToggleRow(
                        colors: colors,
                        label: 'Limit by max distance',
                        value: _limitDistance,
                        onChanged: (v) => setState(() => _limitDistance = v),
                      ),
                      if (_limitDistance) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${_maxDistance.round()} miles',
                          style: TextStyle(
                            color: colors.headerPrimaryText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Slider(
                          value: _maxDistance,
                          min: 1,
                          max: 100,
                          divisions: 99,
                          activeColor: colors.accent,
                          label: '${_maxDistance.round()} mi',
                          onChanged: (v) => setState(() => _maxDistance = v),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Location',
                        style: TextStyle(
                          color: colors.headerPrimaryText,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set the city you want matches measured from — this '
                        'does not use your device\'s location.',
                        style: TextStyle(
                          color: colors.headerSecondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _cityController,
                              textCapitalization: TextCapitalization.words,
                              style: TextStyle(
                                color: colors.headerPrimaryText,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                hintText: 'City',
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
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _state,
                              style: TextStyle(
                                color: colors.headerPrimaryText,
                                fontWeight: FontWeight.w700,
                              ),
                              dropdownColor: colors.cardBackground,
                              decoration: InputDecoration(
                                hintText: 'State',
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
                              items: kUsStates
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                  .toList(),
                              onChanged: (v) => setState(() => _state = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _settingLocation ? null : _setLocation,
                        icon: _settingLocation
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.accent,
                                ),
                              )
                            : const Icon(Icons.location_on_outlined),
                        label: Text(
                          _settingLocation ? 'Setting location...' : 'Set location',
                        ),
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
  Widget _sectionHeader(LooksMatchColors colors, String label, String fieldKey) {
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
                    hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 15,
                    color: hidden ? colors.headerSecondaryText : colors.accent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    hidden ? 'Hidden' : 'Visible',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: hidden ? colors.headerSecondaryText : colors.accent,
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

  Widget _heightDropdown({
    required LooksMatchColors colors,
    required String label,
    required int? value,
    required List<int> range,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      style: TextStyle(color: colors.headerPrimaryText, fontWeight: FontWeight.w700),
      dropdownColor: colors.cardBackground,
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: colors.inputHint),
        filled: true,
        fillColor: colors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

  Widget _prefToggleRow({
    required LooksMatchColors colors,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colors.headerPrimaryText,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: colors.accent),
      ],
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
            icon: Icon(Icons.close_rounded, color: colors.deleteBackground, size: 19),
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
              color:
                  selected ? colors.chipSelectedBackground : colors.chipBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color:
                  selected ? colors.chipSelectedText : colors.chipUnselectedText,
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
        ],
      ),
    );
  }
}
