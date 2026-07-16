import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sign_out_dialog.dart';

/// Shown after phone or email sign-in/sign-up until the user finishes the
/// fields needed to appear in Discover — nothing past this screen (i.e.
/// HomeShell) is reachable until saveProfile succeeds.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const int _maxPhotos = 6;
  static const List<String> _genderOptions = ['Man', 'Woman', 'Nonbinary'];
  static const List<String> _interestOptions = ['Men', 'Women', 'Everyone'];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _picker = ImagePicker();

  final List<File> _photos = [];
  DateTime? _birthDate;
  String? _gender;
  String? _interestedIn;

  bool _pickingPhotos = false;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    if (_pickingPhotos || _photos.length >= _maxPhotos) return;

    setState(() => _pickingPhotos = true);

    try {
      final remaining = _maxPhotos - _photos.length;
      final picked = await _picker.pickMultiImage(imageQuality: 85);

      if (!mounted || picked.isEmpty) return;

      setState(() {
        _photos.addAll(picked.take(remaining).map((file) => File(file.path)));
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not open your photos.');
    } finally {
      if (mounted) {
        setState(() => _pickingPhotos = false);
      }
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
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
    if (_photos.isEmpty) {
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
      final photoUrls = await Future.wait(
        _photos.map((file) => widget.auth.uploadProfilePhoto(file)),
      );

      await widget.auth.saveProfile(
        name: _nameController.text,
        birthDate: _birthDate!,
        gender: _gender!,
        interestedIn: _interestedIn!,
        photoUrls: photoUrls,
      );
      // No navigation here — AuthGate is watching Firestore for
      // profileCompleted and swaps to HomeShell on its own.
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not save your profile. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
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
        automaticallyImplyLeading: false,
        iconTheme: IconThemeData(color: colors.headerIconColor),
        actions: [
          TextButton(
            onPressed: _submitting
                ? null
                : () => confirmSignOut(
                    context: context,
                    onSignOut: widget.auth.signOut,
                  ),
            child: Text(
              'Log Out',
              style: TextStyle(
                color: colors.headerSecondaryText,
                fontWeight: FontWeight.w800,
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
                Text(
                  'Complete your profile',
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This is what your matches will see, and your photos are '
                  'what we use to calculate your LooksMatch score.',
                  style: TextStyle(
                    color: colors.headerSecondaryText,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                _sectionLabel(colors, 'Photos'),
                const SizedBox(height: 9),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _photos.length + (_photos.length < _maxPhotos ? 1 : 0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 9,
                    mainAxisSpacing: 9,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, index) {
                    if (index == _photos.length) {
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
                          onTap: () => setState(() => _gender = option),
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
                          onTap: () => setState(() => _interestedIn = option),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 26),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primaryButtonBackground,
                    foregroundColor: colors.primaryButtonText,
                    disabledBackgroundColor: colors.primaryButtonBackground
                        .withOpacity(0.5),
                    minimumSize: const Size.fromHeight(52),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  child: _submitting
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: colors.primaryButtonText,
                          ),
                        )
                      : const Text('Continue'),
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
              color: selected ? colors.chipSelectedBackground : colors.chipBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? colors.chipSelectedText : colors.chipUnselectedText,
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
          Image.file(_photos[index], fit: BoxFit.cover),
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: () => _removePhoto(index),
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
