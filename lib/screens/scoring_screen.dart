import 'package:flutter/material.dart';

import '../services/auth_controller.dart';
import '../services/profile_cache.dart';
import '../theme/app_theme.dart';

const Map<String, String> _rejectionMessages = {
  'no_face_detected':
      'We couldn\'t detect a face in that photo. Try one '
      'where your face is clearly visible.',
  'multiple_faces':
      'That photo has more than one person in it. Use a '
      'photo of just you.',
  'face_obscured':
      'Your face looks obscured (sunglasses, mask, or '
      'similar). Try a clearer, unobstructed photo.',
  'eyes_closed': 'Your eyes appear closed in that photo. Try another one.',
  'low_quality':
      'That photo is too blurry or the lighting is too dark or '
      'too bright. Try a sharper, well-lit photo.',
  'extreme_pose': 'Try a photo facing more directly toward the camera.',
  'inappropriate_content': 'That photo can\'t be used. Try a different one.',
};

String _rejectionMessage(String? reason) {
  return _rejectionMessages[reason] ??
      'That photo couldn\'t be scored. Try a different one.';
}

enum _ScoringStep { choosePhoto, submitting, scored, rejected }

class ScoringScreen extends StatefulWidget {
  const ScoringScreen({
    super.key,
    required this.auth,
    required this.profileCache,
  });

  final AuthController auth;
  final ProfileCache profileCache;

  @override
  State<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends State<ScoringScreen> {
  int? _selectedIndex;
  _ScoringStep _step = _ScoringStep.choosePhoto;
  String? _rejectionReason;

  Future<void> _submit(String storagePath) async {
    setState(() => _step = _ScoringStep.submitting);

    try {
      await widget.auth.submitPhotoForScoring(storagePath);

      if (!mounted) return;

      final profile = await widget.auth.watchProfile().first;
      final status = profile?['scoringStatus'];

      setState(() {
        if (status == 'scored') {
          _step = _ScoringStep.scored;
        } else {
          _step = _ScoringStep.rejected;
          _rejectionReason = profile?['scoreRejectionReason'] as String?;
        }
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _step = _ScoringStep.choosePhoto);
      _showMessage(authErrorMessage(error));
    }
  }

  void _reset() {
    setState(() {
      _selectedIndex = null;
      _step = _ScoringStep.choosePhoto;
      _rejectionReason = null;
    });
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
          'LooksMatch Score',
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: switch (_step) {
            _ScoringStep.choosePhoto ||
            _ScoringStep.submitting => _choosePhotoView(colors),
            _ScoringStep.scored => _scoredView(colors),
            _ScoringStep.rejected => _rejectedView(colors),
          },
        ),
      ),
    );
  }

  Widget _choosePhotoView(LooksMatchColors colors) {
    return ListenableBuilder(
      listenable: widget.profileCache,
      builder: (context, _) {
        final rawPhotos = widget.profileCache.profile?['photos'];
        final photos = rawPhotos is List
            ? rawPhotos.whereType<Map>().toList()
            : const <Map>[];

        if (!widget.profileCache.hasProfile) {
          return Center(child: CircularProgressIndicator(color: colors.accent));
        }

        if (photos.isEmpty) {
          return Center(
            child: Text(
              'Add profile photos first, then come back here to score one.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.headerSecondaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        final submitting = _step == _ScoringStep.submitting;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose a photo to score',
              style: TextStyle(
                color: colors.headerPrimaryText,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your LooksMatch score is always calculated from one of your '
              'actual profile photos — the score you get is what your '
              'matches see.',
              style: TextStyle(
                color: colors.headerSecondaryText,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: GridView.builder(
                itemCount: photos.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 9,
                  mainAxisSpacing: 9,
                  childAspectRatio: 0.78,
                ),
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  final url = (photo['url'] ?? '').toString();
                  final selected = _selectedIndex == index;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: submitting
                          ? null
                          : () => setState(() => _selectedIndex = index),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected ? colors.accent : colors.cardBorder,
                            width: selected ? 2.5 : 1,
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: colors.inputBackground),
                            ),
                            if (selected)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: colors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: (_selectedIndex == null || submitting)
                  ? null
                  : () => _submit(
                      (photos[_selectedIndex!]['storagePath'] ?? '').toString(),
                    ),
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
              child: submitting
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: colors.primaryButtonText,
                      ),
                    )
                  : const Text('Submit for Scoring'),
            ),
          ],
        );
      },
    );
  }

  Widget _scoredView(LooksMatchColors colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.scoreBackground,
            border: Border.all(color: colors.accent, width: 3),
          ),
          child: Icon(Icons.favorite_rounded, color: colors.accent, size: 36),
        ),
        const SizedBox(height: 20),
        Text(
          'You\'re all set',
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We\'re using this photo to find your best possible matches.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.headerSecondaryText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 26),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primaryButtonBackground,
            foregroundColor: colors.primaryButtonText,
            minimumSize: const Size.fromHeight(50),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Done',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _rejectedView(LooksMatchColors colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: colors.deleteBackground.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.image_not_supported_outlined,
            color: colors.deleteBackground,
            size: 34,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'That photo didn\'t work',
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _rejectionMessage(_rejectionReason),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.headerSecondaryText,
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Add a better photo to your profile, or choose a different one.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.headerSecondaryText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        ElevatedButton(
          onPressed: _reset,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primaryButtonBackground,
            foregroundColor: colors.primaryButtonText,
            minimumSize: const Size.fromHeight(50),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Choose a Different Photo',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}
