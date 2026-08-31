import 'package:flutter/material.dart';

/// Available accent themes. 'mono' is the classic black & white look;
/// 'gold' keeps every surface monochrome but lets a shiny gold carry the
/// hairlines, borders and edges (dark mode only). 'emerald' is a deep
/// forest-black theme where emerald typography carries the identity
/// (dark mode only).
class AppColorTheme {
  static const mono = 'mono';
  static const gold = 'gold';
  static const emerald = 'emerald';
  static const pink = 'pink';
  static const red = 'red';
}

/// Palette constants for the emerald theme's specular card edges.
class EmeraldPalette {  static const surface = Color(0xFF080D0B);
  static const card = Color(0xFF0E1512);
  static const edgeBright = Color(0xFF4EA77D);
  static const edgeMid = Color(0xFF2E5A44);
  static const edgeDark = Color(0xFF12241B);
  static const primaryText = Color(0xFF98D8B4);
  static const mutedText = Color(0xFF7CA08C);

  static bool isActive(ThemeData theme) =>
      theme.brightness == Brightness.dark &&
      theme.colorScheme.surface == surface;
}

/// Palette constants for the gold theme's specular card edges.
class GoldPalette {
  static const surface = Color(0xFF0C0B08);
  static const card = Color(0xFF14120D);
  static const edgeBright = Color(0xFFD4AF37);
  static const edgeMid = Color(0xFF8A742C);
  static const edgeDark = Color(0xFF2E2712);
  static const primaryText = Color(0xFFE6C15A);
  static const mutedText = Color(0xFFA89F8C);

  static bool isActive(ThemeData theme) =>
      theme.brightness == Brightness.dark &&
      theme.colorScheme.surface == surface;
}

/// Palette constants for the dark red theme's specular card edges.
class RedPalette {
  static const surface = Color(0xFF0D0808);
  static const card = Color(0xFF150E0E);
  static const edgeBright = Color(0xFFE05252);
  static const edgeMid = Color(0xFF8A3A3A);
  static const edgeDark = Color(0xFF2A1212);
  static const primaryText = Color(0xFFF0A8A8);
  static const mutedText = Color(0xFFA08C8C);

  static bool isActive(ThemeData theme) =>
      theme.brightness == Brightness.dark &&
      theme.colorScheme.surface == surface;
}

ThemeData getThemeData({
  required bool isDarkMode,
  bool isAmoled = false,
  String colorTheme = AppColorTheme.mono,
}) {
  // AMOLED only applies when dark mode is enabled
  final shouldApplyAmoled = isDarkMode && isAmoled;

  const white = Colors.white;
  const black = Colors.black;

  // Gold theme: surfaces and text stay monochrome; only the outline
  // family picks up the gold so dividers, hairlines and card edges get
  // the shiny treatment. Gold is a dark-mode-only theme — in light mode
  // everything falls back to monochrome.
  final isGold = colorTheme == AppColorTheme.gold && isDarkMode;
  // Emerald theme: deep forest-black surfaces with emerald headings.
  // Regular text stays white — only headings pick up the emerald tone
  // (handled in the text theme below). Also dark-mode-only.
  final isSapphire = colorTheme == AppColorTheme.emerald && isDarkMode;

  // Light-mode accent themes: white surfaces with colored headings,
  // hairlines and edges (white + gold / pink / red).
  final isGoldLight = colorTheme == AppColorTheme.gold && !isDarkMode;
  final isPink = colorTheme == AppColorTheme.pink && !isDarkMode;
  // Red exists in BOTH modes: white + red in light, deep dark red in dark.
  final isRed = colorTheme == AppColorTheme.red;
  final isRedDark = isRed && isDarkMode;

  final outlineColor = isGold
      ? (isDarkMode ? const Color(0xFF9C8434) : const Color(0xFFB08D26))
      : (isDarkMode ? const Color(0xFF8C8C8C) : const Color(0xFF333333));
  final outlineVariantColor = isGold
      ? (isDarkMode ? const Color(0xFF8A742C) : const Color(0xFFD4AF37))
      : (isDarkMode ? const Color(0xFF2E2E2E) : const Color(0xFFE0E0E0));

  final colorScheme = ColorScheme(
    brightness: isDarkMode ? Brightness.dark : Brightness.light,
    primary: isDarkMode ? white : black,
    onPrimary: isDarkMode ? black : white,
    primaryContainer: isDarkMode ? black : white,
    onPrimaryContainer: isDarkMode ? white : black,
    secondary: isDarkMode ? white : black,
    onSecondary: isDarkMode ? black : white,
    secondaryContainer: isDarkMode
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFF2F2F2),
    onSecondaryContainer: isDarkMode ? white : black,
    tertiary: isGold
        ? (isDarkMode ? const Color(0xFFD4AF37) : const Color(0xFFB08D26))
        : (isDarkMode ? white : black),
    onTertiary: isDarkMode ? black : white,
    tertiaryContainer: isGold
        ? (isDarkMode
            ? const Color(0xFF2E2712)
            : const Color(0xFFF5EBCF))
        : (isDarkMode
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFF2F2F2)),
    onTertiaryContainer: isDarkMode ? white : black,
    error: const Color(0xFF9E9E9E),
    onError: isDarkMode ? black : white,
    errorContainer: isDarkMode
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFF2F2F2),
    onErrorContainer: isDarkMode ? white : black,
    surface: shouldApplyAmoled ? black : (isDarkMode ? black : const Color(0xFFF5F5F7)),
    onSurface: isDarkMode ? white : black,
    surfaceContainerHighest: isDarkMode
        ? const Color(0xFF242424)
        : const Color(0xFFE8E8ED),
    surfaceContainerHigh: isDarkMode
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFFFFFFF),
    surfaceContainer: isDarkMode
        ? const Color(0xFF181818)
        : const Color(0xFFFAFAFC),
    surfaceContainerLow: isDarkMode
        ? const Color(0xFF141414)
        : const Color(0xFFFFFFFF),
    surfaceContainerLowest: isDarkMode
        ? const Color(0xFF0F0F0F)
        : const Color(0xFFFBFBFD),
    onSurfaceVariant: isDarkMode
        ? const Color(0xFFB3B3B3)
        : const Color(0xFF4D4D4D),
    outline: outlineColor,
    outlineVariant: outlineVariantColor,
    shadow: black,
    scrim: black,
    inverseSurface: isDarkMode ? white : black,
    onInverseSurface: isDarkMode ? black : white,
    inversePrimary: isDarkMode ? black : white,
    surfaceTint: Colors.transparent,
  );

  // Gold overrides: warm near-black surfaces with gold headings, gold
  // outline family for the shiny hairlines/edges. Regular text stays
  // white; buttons and selected states stay monochrome.
  var effectiveScheme = colorScheme;
  if (isGold && isDarkMode) {
    effectiveScheme = colorScheme.copyWith(
      surface: shouldApplyAmoled ? black : GoldPalette.surface,
      surfaceContainerHighest: const Color(0xFF1C1914),
      surfaceContainerHigh: const Color(0xFF171410),
      surfaceContainer: const Color(0xFF191611),
      surfaceContainerLow: GoldPalette.card,
      surfaceContainerLowest: const Color(0xFF080706),
      onSurfaceVariant: GoldPalette.mutedText,
    );
  }

  // Emerald overrides: deep forest-black surfaces, emerald headings.
  // Regular text stays white — only headings pick up the emerald tone
  // (handled in the text theme below).
  if (isSapphire) {
    effectiveScheme = colorScheme.copyWith(
      primary: EmeraldPalette.edgeBright,
      onPrimary: const Color(0xFF08120C),
      primaryContainer: const Color(0xFF12291C),
      onPrimaryContainer: EmeraldPalette.primaryText,
      secondary: EmeraldPalette.edgeBright,
      onSecondary: const Color(0xFF08120C),
      secondaryContainer: const Color(0xFF10141E),
      onSecondaryContainer: EmeraldPalette.primaryText,
      tertiary: const Color(0xFFBFE3CC),
      tertiaryContainer: const Color(0xFF12241B),
      surface: shouldApplyAmoled ? black : EmeraldPalette.surface,
      onSurface: white,
      surfaceContainerHighest: const Color(0xFF182420),
      surfaceContainerHigh: const Color(0xFF10141E),
      surfaceContainer: const Color(0xFF0C1210),
      surfaceContainerLow: EmeraldPalette.card,
      surfaceContainerLowest: const Color(0xFF050907),
      onSurfaceVariant: EmeraldPalette.mutedText,
      outline: const Color(0xFF3A5246),
      outlineVariant: const Color(0xFF1E2B24),
      inverseSurface: const Color(0xFFE2F2E8),
      onInverseSurface: const Color(0xFF08120C),
      inversePrimary: const Color(0xFF2E6B4C),
    );
  }

  // Dark red overrides: deep crimson-black surfaces with muted red
  // headings, same card-edge treatment as emerald/gold.
  if (isRedDark) {
    effectiveScheme = colorScheme.copyWith(
      primary: RedPalette.edgeBright,
      onPrimary: const Color(0xFF1A0A0A),
      primaryContainer: const Color(0xFF2A1212),
      onPrimaryContainer: RedPalette.primaryText,
      secondary: RedPalette.edgeBright,
      onSecondary: const Color(0xFF1A0A0A),
      secondaryContainer: const Color(0xFF1A0E0E),
      onSecondaryContainer: RedPalette.primaryText,
      tertiary: const Color(0xFFF0A8A8),
      tertiaryContainer: RedPalette.edgeDark,
      surface: shouldApplyAmoled ? black : RedPalette.surface,
      onSurface: white,
      surfaceContainerHighest: const Color(0xFF1E1010),
      surfaceContainerHigh: const Color(0xFF170C0C),
      surfaceContainer: const Color(0xFF130A0A),
      surfaceContainerLow: RedPalette.card,
      surfaceContainerLowest: const Color(0xFF0A0505),
      onSurfaceVariant: RedPalette.mutedText,
      outline: const Color(0xFF5A3A3A),
      outlineVariant: const Color(0xFF2A1B1B),
      inverseSurface: const Color(0xFFF0D0D0),
      onInverseSurface: const Color(0xFF1A0A0A),
      inversePrimary: const Color(0xFF8A3A3A),
    );
  }

  // Light accent overrides: white surfaces with accent headings,
  // accent hairlines/borders and accent course codes.
  if (isGoldLight) {
    effectiveScheme = colorScheme.copyWith(
      tertiary: const Color(0xFFB08D26),
      outline: const Color(0xFFB08D26),
      outlineVariant: const Color(0xFFD4AF37),
    );
  } else if (isPink) {
    effectiveScheme = colorScheme.copyWith(
      tertiary: const Color(0xFFC2185B),
      outline: const Color(0xFFD14D72),
      outlineVariant: const Color(0xFFF2B8C6),
    );
  } else if (isRed && !isDarkMode) {
    effectiveScheme = colorScheme.copyWith(
      tertiary: const Color(0xFFC62828),
      outline: const Color(0xFFC62828),
      outlineVariant: const Color(0xFFEF9A9A),
    );
  }

  // Headings carry the accent identity (emerald/gold light/pink/red);
  // body text stays neutral.
  final headingColor = isSapphire
      ? EmeraldPalette.primaryText
      : (isGold && isDarkMode
          ? GoldPalette.primaryText
          : (isRedDark
              ? RedPalette.primaryText
              : (isGoldLight
                  ? const Color(0xFFB08D26)
                  : (isPink
                      ? const Color(0xFFC2185B)
                      : (isRed ? const Color(0xFFB71C1C) : null)))));
  final textOnSurface = isDarkMode ? white : black;
  final textOnSurfaceVariant = isSapphire
      ? EmeraldPalette.mutedText
      : (isRedDark
          ? RedPalette.mutedText
          : (isDarkMode
              ? const Color(0xFFB3B3B3)
              : const Color(0xFF4D4D4D)));

  return ThemeData(
    useMaterial3: true,
    colorScheme: effectiveScheme,
    textTheme: _buildTextTheme(
      onSurface: textOnSurface,
      onSurfaceVariant: textOnSurfaceVariant,
      headingColor: headingColor,
    ),
    primaryTextTheme: _buildTextTheme(
      onSurface: textOnSurface,
      onSurfaceVariant: textOnSurfaceVariant,
      headingColor: headingColor,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        // Set the predictive back transitions for Android.
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      },
    ),
    scaffoldBackgroundColor: shouldApplyAmoled
        ? black
        : effectiveScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: shouldApplyAmoled ? black : effectiveScheme.surface,
      foregroundColor: textOnSurface,
    ),
    fontFamily: 'Outfit',
  );
}

// Outfit carries the identity of the app (headings, titles, body).
// Inter handles the fine print: captions, timestamps, labels and metadata.
//
// Weight pairing guide:
//   Headings  -> Outfit SemiBold (600) for a crisp, confident look
//   Titles    -> Outfit Medium (500) to stay prominent without shouting
//   Body      -> Outfit Regular (400)
//   Buttons   -> Outfit Medium (500), slightly tracked out
//   Details   -> Inter Regular/Medium (400/500), slightly tighter spacing
TextTheme _buildTextTheme({
  required Color onSurface,
  required Color onSurfaceVariant,
  Color? headingColor,
}) {
  // Headings may carry the accent identity (sapphire) while body text
  // stays neutral.
  final displayColor = headingColor ?? onSurface;

  return TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Outfit',
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      color: displayColor,
    ),
    displayMedium: TextStyle(
      fontFamily: 'Outfit',
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      color: displayColor,
    ),
    displaySmall: TextStyle(
      fontFamily: 'Outfit',
      fontWeight: FontWeight.w600,
      letterSpacing: -0.25,
      color: displayColor,
    ),
    headlineLarge: TextStyle(
      fontFamily: 'Outfit',
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: displayColor,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Outfit',
      fontWeight: FontWeight.w600,
      letterSpacing: -0.25,
      color: displayColor,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'Outfit',
      fontWeight: FontWeight.w600,
      color: displayColor,
    ),
    titleLarge: TextStyle(
      fontFamily: 'Outfit',
      fontWeight: FontWeight.w600,
      color: onSurface,
    ),
    titleMedium: TextStyle(
      fontFamily: 'Outfit',
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: onSurface,
    ),
    titleSmall: TextStyle(
      fontFamily: 'Outfit',
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: onSurface,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Outfit',
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
      color: onSurface,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Outfit',
      fontWeight: FontWeight.w400,
      letterSpacing: 0.2,
      color: onSurface,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w400,
      letterSpacing: 0.1,
      color: onSurfaceVariant,
    ),
    labelLarge: TextStyle(
      fontFamily: 'Outfit',
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      color: onSurface,
    ),
    labelMedium: TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
      color: onSurfaceVariant,
    ),
    labelSmall: TextStyle(
      fontFamily: 'Inter',
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
      color: onSurfaceVariant,
    ),
  );
}
