import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_controller.dart';
import '../theme/app_theme.dart';

/// A city text field that suggests real places as the user types (via
/// AuthController.placeAutocomplete/placeDetails, backed by Google Places —
/// see functions/index.js) instead of asking them to type an exact,
/// correctly-spelled city and separately pick a state. Selecting a
/// suggestion resolves it to city/state/coordinates and hands that back via
/// [onSelected]; nothing is saved by this widget itself.
class LocationAutocompleteField extends StatefulWidget {
  const LocationAutocompleteField({
    super.key,
    required this.auth,
    required this.initialCity,
    required this.initialState,
    required this.onSelected,
  });

  final AuthController auth;
  final String initialCity;
  final String? initialState;
  final void Function(String city, String state, double lat, double lng)
  onSelected;

  @override
  State<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  late final _controller = TextEditingController(
    text: widget.initialCity.isNotEmpty && widget.initialState != null
        ? '${widget.initialCity}, ${widget.initialState}'
        : '',
  );
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];
  bool _loading = false;
  bool _resolving = false;

  // Guards against a slow, stale autocomplete response landing after a
  // newer one already has — otherwise the older results could flash back
  // in over what the user is currently seeing.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    // Rebuilds so the clear button appears/disappears as text is typed,
    // not just when a debounced suggestions fetch happens to setState.
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _clear() {
    _debounce?.cancel();
    setState(() {
      _controller.clear();
      _suggestions = [];
    });
    _focusNode.requestFocus();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _fetchSuggestions(value),
    );
  }

  Future<void> _fetchSuggestions(String input) async {
    final requestId = ++_requestId;
    setState(() => _loading = true);

    try {
      final results = await widget.auth.placeAutocomplete(input);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _suggestions = results;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _suggestions = [];
        _loading = false;
      });
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    _debounce?.cancel();
    setState(() {
      _suggestions = [];
      _resolving = true;
      _controller.text = suggestion.description;
    });
    _focusNode.unfocus();

    try {
      final resolved = await widget.auth.placeDetails(suggestion.placeId);
      if (!mounted) return;
      widget.onSelected(
        resolved.city,
        resolved.state,
        resolved.lat,
        resolved.lng,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Could not use that location. Please try again.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: 'Start typing your city...',
            hintStyle: TextStyle(
              color: colors.inputHint,
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: Icon(Icons.location_on_outlined, color: colors.accent),
            suffixIcon: (_loading || _resolving)
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.accent,
                      ),
                    ),
                  )
                : (_controller.text.isNotEmpty)
                ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: colors.headerSecondaryText,
                    ),
                    onPressed: _clear,
                  )
                : null,
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
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: colors.cardBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _suggestions.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: colors.divider),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _selectSuggestion(_suggestions[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_city_rounded,
                              size: 18,
                              color: colors.headerSecondaryText,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _suggestions[i].description,
                                style: TextStyle(
                                  color: colors.headerPrimaryText,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
