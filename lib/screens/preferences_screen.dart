import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

import '../models/profile_details.dart';
import '../services/auth_controller.dart';
import '../services/profile_cache.dart';
import '../theme/app_theme.dart';

/// Match preferences — who shows up in Discover. Distinct from Edit
/// Profile: everything here is a private filter about candidates, never
/// displayed on this user's own profile (see the "About you" section of
/// EditProfileScreen for the self-description equivalents).
///
/// Shown as a list of preference types; tapping one opens a dedicated
/// full-screen editor for just that type, which returns its updated value
/// via Navigator.pop. Everything is saved together when this screen's own
/// Save is tapped.
class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({
    super.key,
    required this.auth,
    required this.profileCache,
  });

  final AuthController auth;
  final ProfileCache profileCache;

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  static const List<String> _interestOptions = ['Men', 'Women', 'Everyone'];

  String? _interestedIn;

  bool _limitAge = false;
  RangeValues _ageRange = const RangeValues(18, 55);
  bool _limitDistance = false;
  double _maxDistance = 25;
  String _city = '';
  String? _state;

  List<String> _preferredEthnicities = [];
  bool _limitHeight = false;
  int? _minHeightInches;
  int? _maxHeightInches;
  List<String> _preferredRelationshipTypes = [];
  List<String> _preferredFamilyPlans = [];
  List<String> _preferredEducationLevels = [];

  // Loaded once and preserved via copyWith on save — this screen only
  // manages the fields above; bio/prompts/traits/etc belong to Edit
  // Profile, and building from scratch here would wipe them out.
  ProfileDetails _originalDetails = const ProfileDetails();

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
    _interestedIn = (profile?['interestedIn'] as String?)?.isNotEmpty == true
        ? profile!['interestedIn'] as String
        : null;

    _originalDetails = details;
    _city = details.city;
    _state = details.state;

    _limitAge = details.ageRangeMin != null || details.ageRangeMax != null;
    _ageRange = RangeValues(
      (details.ageRangeMin ?? 18).toDouble(),
      (details.ageRangeMax ?? 55).toDouble(),
    );
    _limitDistance = details.maxDistanceMiles != null;
    _maxDistance = (details.maxDistanceMiles ?? 25).toDouble();

    _preferredEthnicities = List.of(details.preferredEthnicities);
    _limitHeight =
        details.minHeightInches != null || details.maxHeightInches != null;
    _minHeightInches = details.minHeightInches;
    _maxHeightInches = details.maxHeightInches;
    _preferredRelationshipTypes = List.of(details.preferredRelationshipTypes);
    _preferredFamilyPlans = List.of(details.preferredFamilyPlans);
    _preferredEducationLevels = List.of(details.preferredEducationLevels);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    try {
      await Future.wait([
        widget.auth.updateInterestedIn(_interestedIn ?? 'Everyone'),
        widget.auth.saveProfileDetails(
          _originalDetails.copyWith(
            city: _city,
            state: _state,
            ageRangeMin: _limitAge ? _ageRange.start.round() : null,
            ageRangeMax: _limitAge ? _ageRange.end.round() : null,
            maxDistanceMiles: _limitDistance ? _maxDistance.round() : null,
            preferredEthnicities: _preferredEthnicities,
            minHeightInches: _limitHeight ? _minHeightInches : null,
            maxHeightInches: _limitHeight ? _maxHeightInches : null,
            preferredRelationshipTypes: _preferredRelationshipTypes,
            preferredFamilyPlans: _preferredFamilyPlans,
            preferredEducationLevels: _preferredEducationLevels,
          ),
        ),
      ]);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not save your preferences. Please try again.');
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

  String _heightLabel(int inches) => '${inches ~/ 12}\'${inches % 12}"';

  String _multiSummary(List<String> selected) =>
      selected.isEmpty ? 'Open to all' : '${selected.length} selected';

  Future<void> _openSingleChoice({
    required String title,
    required List<String> options,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _SingleChoicePage(
          title: title,
          options: options,
          initialValue: value,
        ),
      ),
    );
    if (result != null) onChanged(result);
  }

  Future<void> _openMultiChoice({
    required String title,
    required String subtitle,
    required List<String> options,
    required List<String> selected,
    required ValueChanged<List<String>> onChanged,
  }) async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => _MultiChoicePage(
          title: title,
          subtitle: subtitle,
          options: options,
          initialSelected: selected,
        ),
      ),
    );
    if (result != null) onChanged(result);
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
          'Match Preferences',
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            _groupLabel(colors, 'Discovery'),
            const SizedBox(height: 10),
            _row(
              colors: colors,
              icon: Icons.favorite_border_rounded,
              label: 'Interested in',
              value: _interestedIn ?? 'Not set',
              onTap: () => _openSingleChoice(
                title: 'Interested in',
                options: _interestOptions,
                value: _interestedIn,
                onChanged: (v) => setState(() => _interestedIn = v),
              ),
            ),
            _row(
              colors: colors,
              icon: Icons.cake_outlined,
              label: 'Age range',
              value: _limitAge
                  ? '${_ageRange.start.round()}–${_ageRange.end.round()} years'
                  : 'Anyone',
              onTap: () async {
                final result = await Navigator.push<_AgeRangeResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        _AgeRangePage(limited: _limitAge, range: _ageRange),
                  ),
                );
                if (result != null) {
                  setState(() {
                    _limitAge = result.limited;
                    _ageRange = result.range;
                  });
                }
              },
            ),
            _row(
              colors: colors,
              icon: Icons.social_distance_outlined,
              label: 'Maximum distance',
              value: _limitDistance
                  ? '${_maxDistance.round()} miles'
                  : 'Anywhere',
              onTap: () async {
                final result = await Navigator.push<_DistanceResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _MaxDistancePage(
                      limited: _limitDistance,
                      miles: _maxDistance,
                    ),
                  ),
                );
                if (result != null) {
                  setState(() {
                    _limitDistance = result.limited;
                    _maxDistance = result.miles;
                  });
                }
              },
            ),
            _row(
              colors: colors,
              icon: Icons.location_on_outlined,
              label: 'Location',
              value: (_city.isNotEmpty && _state != null)
                  ? '$_city, $_state'
                  : 'Not set',
              onTap: () async {
                final result = await Navigator.push<_LocationResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _LocationPage(
                      auth: widget.auth,
                      city: _city,
                      state: _state,
                    ),
                  ),
                );
                if (result != null) {
                  setState(() {
                    _city = result.city;
                    _state = result.state;
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            _groupLabel(colors, 'Who you\'d like to see'),
            const SizedBox(height: 4),
            Text(
              'Leave anything unselected to see everyone on that dimension '
              '— nobody\'s excluded until you set a preference.',
              style: TextStyle(
                color: colors.headerSecondaryText,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _row(
              colors: colors,
              icon: Icons.public_rounded,
              label: 'Ethnicity',
              value: _multiSummary(_preferredEthnicities),
              onTap: () => _openMultiChoice(
                title: 'Ethnicity',
                subtitle: 'Leave unselected to see people of any ethnicity.',
                options: kEthnicityOptions,
                selected: _preferredEthnicities,
                onChanged: (v) => setState(() => _preferredEthnicities = v),
              ),
            ),
            _row(
              colors: colors,
              icon: Icons.height_rounded,
              label: 'Height',
              value: _limitHeight
                  ? '${_minHeightInches != null ? _heightLabel(_minHeightInches!) : 'Any'}'
                        ' – ${_maxHeightInches != null ? _heightLabel(_maxHeightInches!) : 'Any'}'
                  : 'Any height',
              onTap: () async {
                final result = await Navigator.push<_HeightRangeResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _HeightRangePage(
                      limited: _limitHeight,
                      minHeightInches: _minHeightInches,
                      maxHeightInches: _maxHeightInches,
                    ),
                  ),
                );
                if (result != null) {
                  setState(() {
                    _limitHeight = result.limited;
                    _minHeightInches = result.minHeightInches;
                    _maxHeightInches = result.maxHeightInches;
                  });
                }
              },
            ),
            _row(
              colors: colors,
              icon: Icons.diversity_3_outlined,
              label: 'Relationship type',
              value: _multiSummary(_preferredRelationshipTypes),
              onTap: () => _openMultiChoice(
                title: 'Relationship type',
                subtitle: 'Leave unselected to see any relationship type.',
                options: kRelationshipTypeOptions,
                selected: _preferredRelationshipTypes,
                onChanged: (v) =>
                    setState(() => _preferredRelationshipTypes = v),
              ),
            ),
            _row(
              colors: colors,
              icon: Icons.child_friendly_outlined,
              label: 'Children',
              value: _multiSummary(_preferredFamilyPlans),
              onTap: () => _openMultiChoice(
                title: 'Children',
                subtitle: 'Leave unselected to see any family plans.',
                options: kFamilyPlansOptions,
                selected: _preferredFamilyPlans,
                onChanged: (v) => setState(() => _preferredFamilyPlans = v),
              ),
            ),
            _row(
              colors: colors,
              icon: Icons.school_outlined,
              label: 'Education level',
              value: _multiSummary(_preferredEducationLevels),
              onTap: () => _openMultiChoice(
                title: 'Education level',
                subtitle: 'Leave unselected to see any education level.',
                options: kEducationOptions,
                selected: _preferredEducationLevels,
                onChanged: (v) => setState(() => _preferredEducationLevels = v),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupLabel(LooksMatchColors colors, String label) {
    return Text(
      label,
      style: TextStyle(
        color: colors.headerPrimaryText,
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _row({
    required LooksMatchColors colors,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.scoreBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: colors.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: colors.headerPrimaryText,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: TextStyle(
                          color: colors.headerSecondaryText,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.headerSecondaryText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared full-screen scaffold shell for every detail page below — same
/// AppBar treatment (title + Done action) so they all read as one system.
class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({
    required this.title,
    required this.onDone,
    required this.body,
  });

  final String title;
  final VoidCallback onDone;
  final Widget body;

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
          title,
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          TextButton(
            onPressed: onDone,
            child: Text(
              'Done',
              style: TextStyle(
                color: colors.accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

class _SingleChoicePage extends StatefulWidget {
  const _SingleChoicePage({
    required this.title,
    required this.options,
    this.initialValue,
  });

  final String title;
  final List<String> options;
  final String? initialValue;

  @override
  State<_SingleChoicePage> createState() => _SingleChoicePageState();
}

class _SingleChoicePageState extends State<_SingleChoicePage> {
  late String? _value = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return _DetailScaffold(
      title: widget.title,
      onDone: () => Navigator.pop(context, _value),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: widget.options.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: colors.divider, indent: 20),
        itemBuilder: (context, index) {
          final option = widget.options[index];
          final selected = option == _value;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 2,
            ),
            title: Text(
              option,
              style: TextStyle(
                color: colors.headerPrimaryText,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            trailing: selected
                ? Icon(Icons.check_circle_rounded, color: colors.accent)
                : null,
            onTap: () => setState(() => _value = option),
          );
        },
      ),
    );
  }
}

class _MultiChoicePage extends StatefulWidget {
  const _MultiChoicePage({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.initialSelected,
  });

  final String title;
  final String subtitle;
  final List<String> options;
  final List<String> initialSelected;

  @override
  State<_MultiChoicePage> createState() => _MultiChoicePageState();
}

class _MultiChoicePageState extends State<_MultiChoicePage> {
  late final List<String> _selected = List.of(widget.initialSelected);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return _DetailScaffold(
      title: widget.title,
      onDone: () => Navigator.pop(context, _selected),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.subtitle,
                    style: TextStyle(
                      color: colors.headerSecondaryText,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(_selected.clear),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        color: colors.deleteBackground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 4),
              itemCount: widget.options.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: colors.divider, indent: 20),
              itemBuilder: (context, index) {
                final option = widget.options[index];
                final selected = _selected.contains(option);
                return CheckboxListTile(
                  value: selected,
                  onChanged: (_) => setState(
                    () => selected
                        ? _selected.remove(option)
                        : _selected.add(option),
                  ),
                  controlAffinity: ListTileControlAffinity.trailing,
                  activeColor: colors.accent,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: Text(
                    option,
                    style: TextStyle(
                      color: colors.headerPrimaryText,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AgeRangeResult {
  const _AgeRangeResult(this.limited, this.range);
  final bool limited;
  final RangeValues range;
}

class _AgeRangePage extends StatefulWidget {
  const _AgeRangePage({required this.limited, required this.range});

  final bool limited;
  final RangeValues range;

  @override
  State<_AgeRangePage> createState() => _AgeRangePageState();
}

class _AgeRangePageState extends State<_AgeRangePage> {
  late bool _limited = widget.limited;
  late RangeValues _range = widget.range;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return _DetailScaffold(
      title: 'Age Range',
      onDone: () => Navigator.pop(context, _AgeRangeResult(_limited, _range)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toggleRow(
              colors,
              'Limit by age range',
              _limited,
              (v) => setState(() => _limited = v),
            ),
            if (_limited) ...[
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '${_range.start.round()} – ${_range.end.round()} years',
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              RangeSlider(
                values: _range,
                min: 18,
                max: 80,
                divisions: 62,
                activeColor: colors.accent,
                labels: RangeLabels(
                  _range.start.round().toString(),
                  _range.end.round().toString(),
                ),
                onChanged: (v) => setState(() => _range = v),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DistanceResult {
  const _DistanceResult(this.limited, this.miles);
  final bool limited;
  final double miles;
}

class _MaxDistancePage extends StatefulWidget {
  const _MaxDistancePage({required this.limited, required this.miles});

  final bool limited;
  final double miles;

  @override
  State<_MaxDistancePage> createState() => _MaxDistancePageState();
}

class _MaxDistancePageState extends State<_MaxDistancePage> {
  late bool _limited = widget.limited;
  late double _miles = widget.miles;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return _DetailScaffold(
      title: 'Maximum Distance',
      onDone: () => Navigator.pop(context, _DistanceResult(_limited, _miles)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toggleRow(
              colors,
              'Limit by max distance',
              _limited,
              (v) => setState(() => _limited = v),
            ),
            if (_limited) ...[
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '${_miles.round()} miles',
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Slider(
                value: _miles,
                min: 1,
                max: 100,
                divisions: 99,
                activeColor: colors.accent,
                label: '${_miles.round()} mi',
                onChanged: (v) => setState(() => _miles = v),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocationResult {
  const _LocationResult(this.city, this.state);
  final String city;
  final String? state;
}

class _LocationPage extends StatefulWidget {
  const _LocationPage({
    required this.auth,
    required this.city,
    required this.state,
  });

  final AuthController auth;
  final String city;
  final String? state;

  @override
  State<_LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<_LocationPage> {
  late final _cityController = TextEditingController(text: widget.city);
  late String? _state = widget.state;
  bool _settingLocation = false;

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
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
      final results = await Geocoding().locationFromAddress(
        '$city, $_state, USA',
      );
      if (results.isEmpty) {
        if (!mounted) return;
        _showMessage(
          'Could not find that city. Check the spelling and try again.',
        );
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

    return _DetailScaffold(
      title: 'Location',
      onDone: () => Navigator.pop(
        context,
        _LocationResult(_cityController.text.trim(), _state),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set the city you want matches measured from — this does not '
              'use your device\'s location.',
              style: TextStyle(
                color: colors.headerSecondaryText,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
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
                        borderSide: BorderSide(
                          color: colors.accent,
                          width: 1.5,
                        ),
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
                        borderSide: BorderSide(
                          color: colors.accent,
                          width: 1.5,
                        ),
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
            const SizedBox(height: 14),
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
    );
  }
}

class _HeightRangeResult {
  const _HeightRangeResult(
    this.limited,
    this.minHeightInches,
    this.maxHeightInches,
  );
  final bool limited;
  final int? minHeightInches;
  final int? maxHeightInches;
}

class _HeightRangePage extends StatefulWidget {
  const _HeightRangePage({
    required this.limited,
    required this.minHeightInches,
    required this.maxHeightInches,
  });

  final bool limited;
  final int? minHeightInches;
  final int? maxHeightInches;

  @override
  State<_HeightRangePage> createState() => _HeightRangePageState();
}

class _HeightRangePageState extends State<_HeightRangePage> {
  late bool _limited = widget.limited;
  int? _minFeet;
  int? _minInches;
  int? _maxFeet;
  int? _maxInches;

  @override
  void initState() {
    super.initState();
    if (widget.minHeightInches != null) {
      _minFeet = widget.minHeightInches! ~/ 12;
      _minInches = widget.minHeightInches! % 12;
    }
    if (widget.maxHeightInches != null) {
      _maxFeet = widget.maxHeightInches! ~/ 12;
      _maxInches = widget.maxHeightInches! % 12;
    }
  }

  void _done() {
    final minHeightInches = (_minFeet != null && _minInches != null)
        ? _minFeet! * 12 + _minInches!
        : null;
    final maxHeightInches = (_maxFeet != null && _maxInches != null)
        ? _maxFeet! * 12 + _maxInches!
        : null;
    Navigator.pop(
      context,
      _HeightRangeResult(_limited, minHeightInches, maxHeightInches),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return _DetailScaffold(
      title: 'Height',
      onDone: _done,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toggleRow(
              colors,
              'Limit by height',
              _limited,
              (v) => setState(() => _limited = v),
            ),
            if (_limited) ...[
              const SizedBox(height: 20),
              Text(
                'Min height',
                style: TextStyle(
                  color: colors.headerSecondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _heightDropdown(
                      colors,
                      'ft',
                      _minFeet,
                      (v) => setState(() => _minFeet = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _heightDropdown(
                      colors,
                      'in',
                      _minInches,
                      (v) => setState(() => _minInches = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Max height',
                style: TextStyle(
                  color: colors.headerSecondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _heightDropdown(
                      colors,
                      'ft',
                      _maxFeet,
                      (v) => setState(() => _maxFeet = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _heightDropdown(
                      colors,
                      'in',
                      _maxInches,
                      (v) => setState(() => _maxInches = v),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _heightDropdown(
    LooksMatchColors colors,
    String label,
    int? value,
    ValueChanged<int?> onChanged,
  ) {
    final range = label == 'ft'
        ? const [4, 5, 6, 7]
        : const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

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
}

Widget _toggleRow(
  LooksMatchColors colors,
  String label,
  bool value,
  ValueChanged<bool> onChanged,
) {
  return Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: colors.accent,
      ),
    ],
  );
}
