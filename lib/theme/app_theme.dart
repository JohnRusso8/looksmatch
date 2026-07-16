import 'package:flutter/material.dart';

/// LooksMatch's theme palette. Values are intentionally kept in step with
/// the Barchive / Barchive Connect color system (same hex values) so the
/// two apps read as siblings.
@immutable
class LooksMatchColors extends ThemeExtension<LooksMatchColors> {
  final Color pageBackground;
  final Color surfaceBackground;
  final Color surfaceBorder;
  final Color divider;

  final Color headerBackground;
  final Color headerIconColor;
  final Color headerPrimaryText;
  final Color headerSecondaryText;

  final Color accent;
  final Color primaryButtonBackground;
  final Color primaryButtonText;
  final Color outlineButtonBorder;
  final Color outlineButtonText;

  final Color cardBackground;
  final Color cardBorder;
  final Color inputBackground;
  final Color inputBorder;
  final Color inputHint;

  final Color chipSelectedBackground;
  final Color chipSelectedText;
  final Color chipUnselectedBackground;
  final Color chipUnselectedText;
  final Color chipBorder;

  final Color dialogBackground;

  final Color deleteBackground;
  final Color deleteText;
  final Color successColor;

  final Color bottomNavBackground;
  final Color bottomNavSelectedIcon;
  final Color bottomNavUnselectedIcon;
  final Color bottomNavShadow;

  final Color scoreBackground;
  final Color scoreText;

  final Color messageBubbleMeBackground;
  final Color messageBubbleMeText;
  final Color messageBubbleOtherBackground;
  final Color messageBubbleOtherText;

  const LooksMatchColors({
    required this.pageBackground,
    required this.surfaceBackground,
    required this.surfaceBorder,
    required this.divider,
    required this.headerBackground,
    required this.headerIconColor,
    required this.headerPrimaryText,
    required this.headerSecondaryText,
    required this.accent,
    required this.primaryButtonBackground,
    required this.primaryButtonText,
    required this.outlineButtonBorder,
    required this.outlineButtonText,
    required this.cardBackground,
    required this.cardBorder,
    required this.inputBackground,
    required this.inputBorder,
    required this.inputHint,
    required this.chipSelectedBackground,
    required this.chipSelectedText,
    required this.chipUnselectedBackground,
    required this.chipUnselectedText,
    required this.chipBorder,
    required this.dialogBackground,
    required this.deleteBackground,
    required this.deleteText,
    required this.successColor,
    required this.bottomNavBackground,
    required this.bottomNavSelectedIcon,
    required this.bottomNavUnselectedIcon,
    required this.bottomNavShadow,
    required this.scoreBackground,
    required this.scoreText,
    required this.messageBubbleMeBackground,
    required this.messageBubbleMeText,
    required this.messageBubbleOtherBackground,
    required this.messageBubbleOtherText,
  });

  @override
  LooksMatchColors copyWith({
    Color? pageBackground,
    Color? surfaceBackground,
    Color? surfaceBorder,
    Color? divider,
    Color? headerBackground,
    Color? headerIconColor,
    Color? headerPrimaryText,
    Color? headerSecondaryText,
    Color? accent,
    Color? primaryButtonBackground,
    Color? primaryButtonText,
    Color? outlineButtonBorder,
    Color? outlineButtonText,
    Color? cardBackground,
    Color? cardBorder,
    Color? inputBackground,
    Color? inputBorder,
    Color? inputHint,
    Color? chipSelectedBackground,
    Color? chipSelectedText,
    Color? chipUnselectedBackground,
    Color? chipUnselectedText,
    Color? chipBorder,
    Color? dialogBackground,
    Color? deleteBackground,
    Color? deleteText,
    Color? successColor,
    Color? bottomNavBackground,
    Color? bottomNavSelectedIcon,
    Color? bottomNavUnselectedIcon,
    Color? bottomNavShadow,
    Color? scoreBackground,
    Color? scoreText,
    Color? messageBubbleMeBackground,
    Color? messageBubbleMeText,
    Color? messageBubbleOtherBackground,
    Color? messageBubbleOtherText,
  }) {
    return LooksMatchColors(
      pageBackground: pageBackground ?? this.pageBackground,
      surfaceBackground: surfaceBackground ?? this.surfaceBackground,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      divider: divider ?? this.divider,
      headerBackground: headerBackground ?? this.headerBackground,
      headerIconColor: headerIconColor ?? this.headerIconColor,
      headerPrimaryText: headerPrimaryText ?? this.headerPrimaryText,
      headerSecondaryText: headerSecondaryText ?? this.headerSecondaryText,
      accent: accent ?? this.accent,
      primaryButtonBackground:
          primaryButtonBackground ?? this.primaryButtonBackground,
      primaryButtonText: primaryButtonText ?? this.primaryButtonText,
      outlineButtonBorder: outlineButtonBorder ?? this.outlineButtonBorder,
      outlineButtonText: outlineButtonText ?? this.outlineButtonText,
      cardBackground: cardBackground ?? this.cardBackground,
      cardBorder: cardBorder ?? this.cardBorder,
      inputBackground: inputBackground ?? this.inputBackground,
      inputBorder: inputBorder ?? this.inputBorder,
      inputHint: inputHint ?? this.inputHint,
      chipSelectedBackground:
          chipSelectedBackground ?? this.chipSelectedBackground,
      chipSelectedText: chipSelectedText ?? this.chipSelectedText,
      chipUnselectedBackground:
          chipUnselectedBackground ?? this.chipUnselectedBackground,
      chipUnselectedText: chipUnselectedText ?? this.chipUnselectedText,
      chipBorder: chipBorder ?? this.chipBorder,
      dialogBackground: dialogBackground ?? this.dialogBackground,
      deleteBackground: deleteBackground ?? this.deleteBackground,
      deleteText: deleteText ?? this.deleteText,
      successColor: successColor ?? this.successColor,
      bottomNavBackground: bottomNavBackground ?? this.bottomNavBackground,
      bottomNavSelectedIcon:
          bottomNavSelectedIcon ?? this.bottomNavSelectedIcon,
      bottomNavUnselectedIcon:
          bottomNavUnselectedIcon ?? this.bottomNavUnselectedIcon,
      bottomNavShadow: bottomNavShadow ?? this.bottomNavShadow,
      scoreBackground: scoreBackground ?? this.scoreBackground,
      scoreText: scoreText ?? this.scoreText,
      messageBubbleMeBackground:
          messageBubbleMeBackground ?? this.messageBubbleMeBackground,
      messageBubbleMeText: messageBubbleMeText ?? this.messageBubbleMeText,
      messageBubbleOtherBackground:
          messageBubbleOtherBackground ?? this.messageBubbleOtherBackground,
      messageBubbleOtherText:
          messageBubbleOtherText ?? this.messageBubbleOtherText,
    );
  }

  @override
  LooksMatchColors lerp(ThemeExtension<LooksMatchColors>? other, double t) {
    if (other is! LooksMatchColors) return this;

    Color l(Color a, Color b) => Color.lerp(a, b, t)!;

    return LooksMatchColors(
      pageBackground: l(pageBackground, other.pageBackground),
      surfaceBackground: l(surfaceBackground, other.surfaceBackground),
      surfaceBorder: l(surfaceBorder, other.surfaceBorder),
      divider: l(divider, other.divider),
      headerBackground: l(headerBackground, other.headerBackground),
      headerIconColor: l(headerIconColor, other.headerIconColor),
      headerPrimaryText: l(headerPrimaryText, other.headerPrimaryText),
      headerSecondaryText: l(headerSecondaryText, other.headerSecondaryText),
      accent: l(accent, other.accent),
      primaryButtonBackground:
          l(primaryButtonBackground, other.primaryButtonBackground),
      primaryButtonText: l(primaryButtonText, other.primaryButtonText),
      outlineButtonBorder: l(outlineButtonBorder, other.outlineButtonBorder),
      outlineButtonText: l(outlineButtonText, other.outlineButtonText),
      cardBackground: l(cardBackground, other.cardBackground),
      cardBorder: l(cardBorder, other.cardBorder),
      inputBackground: l(inputBackground, other.inputBackground),
      inputBorder: l(inputBorder, other.inputBorder),
      inputHint: l(inputHint, other.inputHint),
      chipSelectedBackground:
          l(chipSelectedBackground, other.chipSelectedBackground),
      chipSelectedText: l(chipSelectedText, other.chipSelectedText),
      chipUnselectedBackground:
          l(chipUnselectedBackground, other.chipUnselectedBackground),
      chipUnselectedText: l(chipUnselectedText, other.chipUnselectedText),
      chipBorder: l(chipBorder, other.chipBorder),
      dialogBackground: l(dialogBackground, other.dialogBackground),
      deleteBackground: l(deleteBackground, other.deleteBackground),
      deleteText: l(deleteText, other.deleteText),
      successColor: l(successColor, other.successColor),
      bottomNavBackground: l(bottomNavBackground, other.bottomNavBackground),
      bottomNavSelectedIcon:
          l(bottomNavSelectedIcon, other.bottomNavSelectedIcon),
      bottomNavUnselectedIcon:
          l(bottomNavUnselectedIcon, other.bottomNavUnselectedIcon),
      bottomNavShadow: l(bottomNavShadow, other.bottomNavShadow),
      scoreBackground: l(scoreBackground, other.scoreBackground),
      scoreText: l(scoreText, other.scoreText),
      messageBubbleMeBackground:
          l(messageBubbleMeBackground, other.messageBubbleMeBackground),
      messageBubbleMeText: l(messageBubbleMeText, other.messageBubbleMeText),
      messageBubbleOtherBackground:
          l(messageBubbleOtherBackground, other.messageBubbleOtherBackground),
      messageBubbleOtherText:
          l(messageBubbleOtherText, other.messageBubbleOtherText),
    );
  }
}

class AppTheme {
  static const LooksMatchColors lightColors = LooksMatchColors(
    pageBackground: Colors.white,
    surfaceBackground: Color(0xFFF8FAFC),
    surfaceBorder: Color(0x1F111827),
    divider: Color(0x14111827),
    headerBackground: Colors.white,
    headerIconColor: Color(0xFF111827),
    headerPrimaryText: Color(0xFF111827),
    headerSecondaryText: Color(0xFF6B7280),
    accent: Color(0xFF2563EB),
    primaryButtonBackground: Color(0xFF111827),
    primaryButtonText: Colors.white,
    outlineButtonBorder: Color(0x1F111827),
    outlineButtonText: Color(0xFF111827),
    cardBackground: Colors.white,
    cardBorder: Color(0x1F111827),
    inputBackground: Color(0xFFF3F4F6),
    inputBorder: Color(0x1F111827),
    inputHint: Color(0xFF9CA3AF),
    chipSelectedBackground: Color(0xFF111827),
    chipSelectedText: Colors.white,
    chipUnselectedBackground: Color(0xFFF3F4F6),
    chipUnselectedText: Color(0xFF111827),
    chipBorder: Color(0x1F111827),
    dialogBackground: Colors.white,
    deleteBackground: Color(0xFFDC2626),
    deleteText: Colors.white,
    successColor: Color(0xFF16A34A),
    bottomNavBackground: Color(0xCCFFFFFF),
    bottomNavSelectedIcon: Color(0xFF2563EB),
    bottomNavUnselectedIcon: Color(0xFF6B7280),
    bottomNavShadow: Color(0x14000000),
    scoreBackground: Color(0x1F2563EB),
    scoreText: Color(0xFF2563EB),
    messageBubbleMeBackground: Color(0xFF2563EB),
    messageBubbleMeText: Colors.white,
    messageBubbleOtherBackground: Color(0xFFF3F4F6),
    messageBubbleOtherText: Color(0xFF111827),
  );

  static const LooksMatchColors darkColors = LooksMatchColors(
    pageBackground: Colors.black,
    surfaceBackground: Color(0xFF0B0B0B),
    surfaceBorder: Color(0x26FFFFFF),
    divider: Color(0x14FFFFFF),
    headerBackground: Colors.black,
    headerIconColor: Colors.white,
    headerPrimaryText: Colors.white,
    headerSecondaryText: Color(0xFFB3B3B3),
    accent: Color(0xFF60A5FA),
    primaryButtonBackground: Colors.white,
    primaryButtonText: Colors.black,
    outlineButtonBorder: Color(0x26FFFFFF),
    outlineButtonText: Colors.white,
    cardBackground: Color(0xFF111111),
    cardBorder: Color(0x26FFFFFF),
    inputBackground: Color(0xFF171717),
    inputBorder: Color(0x26FFFFFF),
    inputHint: Color(0xFF8A8A8A),
    chipSelectedBackground: Colors.white,
    chipSelectedText: Colors.black,
    chipUnselectedBackground: Color(0xFF171717),
    chipUnselectedText: Color(0xFFF5F5F5),
    chipBorder: Color(0x26FFFFFF),
    dialogBackground: Color(0xFF0B0B0B),
    deleteBackground: Color(0xFFB91C1C),
    deleteText: Colors.white,
    successColor: Color(0xFF34D399),
    bottomNavBackground: Color(0xCC111111),
    bottomNavSelectedIcon: Color(0xFF60A5FA),
    bottomNavUnselectedIcon: Color(0xFF9CA3AF),
    bottomNavShadow: Color(0x33000000),
    scoreBackground: Color(0x2960A5FA),
    scoreText: Color(0xFF93C5FD),
    messageBubbleMeBackground: Color(0xFF60A5FA),
    messageBubbleMeText: Colors.black,
    messageBubbleOtherBackground: Color(0xFF171717),
    messageBubbleOtherText: Color(0xFFF5F5F5),
  );

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF2563EB),
      secondary: Color(0xFF2563EB),
      surface: Colors.white,
      onSurface: Color(0xFF111827),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    extensions: const <ThemeExtension<dynamic>>[lightColors],
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF60A5FA),
      secondary: Color(0xFF60A5FA),
      surface: Color(0xFF0B0B0B),
      onSurface: Color(0xFFF5F5F5),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFF0B0B0B),
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF0B0B0B),
      surfaceTintColor: Colors.transparent,
    ),
    extensions: const <ThemeExtension<dynamic>>[darkColors],
  );
}

extension LooksMatchThemeX on BuildContext {
  LooksMatchColors get colors => Theme.of(this).extension<LooksMatchColors>()!;
}
