import 'package:flutter/material.dart';
import 'package:vit_ap_student_app/core/common/app_route_transition_state.dart';

/// Available accent themes. Monochrome is the neutral control theme; the
/// remaining themes share the same neutral surfaces and differ only in the
/// accent used for headings and selected states.
class AppColorTheme {
  static const mono = 'mono';
  static const gold = 'gold';
  static const emerald = 'emerald';
  static const pink = 'pink';
  static const red = 'red';
  static const custom = 'custom';
}

/// Dark emerald palette. The `isActive` check also accepts the accent role so
/// the palette remains identifiable when AMOLED mode changes the page
/// surface to pure black.
class EmeraldPalette {
  static const surface = Color(0xFF080D0B);
  static const card = Color(0xFF0E1512);
  static const edgeBright = Color(0xFF61C78F);
  static const edgeMid = Color(0xFF2E7A52);
  static const edgeDark = Color(0xFF102A1D);
  static const primaryText = Color(0xFFBFE3CC);
  static const mutedText = Color(0xFF92B4A0);

  static bool isActive(ThemeData theme) =>
      theme.brightness == Brightness.dark &&
      (theme.colorScheme.surface == surface ||
          theme.colorScheme.primary == edgeBright);
}

/// Dark gold palette.
class GoldPalette {
  static const surface = Color(0xFF0C0B08);
  static const card = Color(0xFF14120D);
  static const edgeBright = Color(0xFFE5BD50);
  static const edgeMid = Color(0xFF8A6A20);
  static const edgeDark = Color(0xFF33270D);
  static const primaryText = Color(0xFFF0D77B);
  static const mutedText = Color(0xFFB7AA8D);

  static bool isActive(ThemeData theme) =>
      theme.brightness == Brightness.dark &&
      (theme.colorScheme.surface == surface ||
          theme.colorScheme.primary == edgeBright);
}

/// Light gold palette.
class GoldLightPalette {
  static const surface = Color(0xFFFFFCF5);
  static const card = Color(0xFFFFFFFF);
  static const edgeBright = Color(0xFFC9A227);
  static const edgeMid = Color(0xFFE0C66A);
  static const edgeDark = Color(0xFFF5EBCF);
  static const primaryText = Color(0xFF8A6D1D);
  static const mutedText = Color(0xFF6F6250);
  static const accent = Color(0xFFB08D26);
  static const accentContainer = Color(0xFFF5EBCF);

  static bool isActive(ThemeData theme) =>
      theme.brightness == Brightness.light &&
      (theme.colorScheme.surface == surface ||
          theme.colorScheme.primary == accent);
}

/// Light pink palette.
class PinkPalette {
  static const surface = Color(0xFFFFF8FA);
  static const card = Color(0xFFFFFFFF);
  static const edgeBright = Color(0xFFE04D7D);
  static const edgeMid = Color(0xFFF19BB5);
  static const edgeDark = Color(0xFFFADCE5);
  static const primaryText = Color(0xFFA9154B);
  static const mutedText = Color(0xFF765663);
  static const accent = Color(0xFFC2185B);
  static const accentContainer = Color(0xFFFCE4EC);

  static bool isActive(ThemeData theme) =>
      theme.brightness == Brightness.light &&
      (theme.colorScheme.surface == surface ||
          theme.colorScheme.primary == accent);
}

/// Dark red palette.
class RedPalette {
  static const surface = Color(0xFF0D0808);
  static const card = Color(0xFF150E0E);
  static const edgeBright = Color(0xFFF06A6A);
  static const edgeMid = Color(0xFF9A3D3D);
  static const edgeDark = Color(0xFF351717);
  static const primaryText = Color(0xFFF0A8A8);
  static const mutedText = Color(0xFFBA9C9C);

  static bool isActive(ThemeData theme) =>
      theme.brightness == Brightness.dark &&
      (theme.colorScheme.surface == surface ||
          theme.colorScheme.primary == edgeBright);
}

/// Light red palette.
class RedLightPalette {
  static const surface = Color(0xFFFFF8F8);
  static const card = Color(0xFFFFFFFF);
  static const edgeBright = Color(0xFFE05252);
  static const edgeMid = Color(0xFFE98B8B);
  static const edgeDark = Color(0xFFF8DADA);
  static const primaryText = Color(0xFFB71C1C);
  static const mutedText = Color(0xFF765656);
  static const accent = Color(0xFFC62828);
  static const accentContainer = Color(0xFFFCE1E1);

  static bool isActive(ThemeData theme) =>
      theme.brightness == Brightness.light &&
      (theme.colorScheme.surface == surface ||
          theme.colorScheme.primary == accent);
}

/// A complete accent specification shared by the theme and heading widgets.
/// This prevents each component from inventing a slightly different
/// interpretation of the same theme.
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  final Color success;
  final Color onSuccessContainer;
  final Color successContainer;
  final Color warning;
  final Color onWarningContainer;
  final Color warningContainer;
  final Color danger;
  final Color onDangerContainer;
  final Color dangerContainer;
  final Color neutral;
  final Color onNeutralContainer;
  final Color neutralContainer;

  const AppStatusColors({
    required this.success,
    required this.onSuccessContainer,
    required this.successContainer,
    required this.warning,
    required this.onWarningContainer,
    required this.warningContainer,
    required this.danger,
    required this.onDangerContainer,
    required this.dangerContainer,
    required this.neutral,
    required this.onNeutralContainer,
    required this.neutralContainer,
  });

  static const light = AppStatusColors(
    success: Color(0xFF2E7D32),
    onSuccessContainer: Colors.white,
    successContainer: Color(0xFFD8F3DC),
    warning: Color(0xFFB45309),
    onWarningContainer: Colors.white,
    warningContainer: Color(0xFFFFF0D5),
    danger: Color(0xFFB3261E),
    onDangerContainer: Colors.white,
    dangerContainer: Color(0xFFFFDAD6),
    neutral: Color(0xFF5B5B63),
    onNeutralContainer: Colors.white,
    neutralContainer: Color(0xFFE7E7EA),
  );

  static const dark = AppStatusColors(
    success: Color(0xFF7BD8A0),
    onSuccessContainer: Color(0xFF06210F),
    successContainer: Color(0xFF123A24),
    warning: Color(0xFFF6C46A),
    onWarningContainer: Color(0xFF2A1A00),
    warningContainer: Color(0xFF4A3210),
    danger: Color(0xFFFFB4AB),
    onDangerContainer: Color(0xFF690005),
    dangerContainer: Color(0xFF5C1518),
    neutral: Color(0xFFC5C5CA),
    onNeutralContainer: Color(0xFF252525),
    neutralContainer: Color(0xFF3A3A3E),
  );

  static AppStatusColors of(BuildContext context) =>
      Theme.of(context).extension<AppStatusColors>() ?? light;

  static AppStatusColors forColorScheme(ColorScheme colorScheme) =>
      colorScheme.brightness == Brightness.dark ? dark : light;

  @override
  AppStatusColors copyWith({
    Color? success,
    Color? onSuccessContainer,
    Color? successContainer,
    Color? warning,
    Color? onWarningContainer,
    Color? warningContainer,
    Color? danger,
    Color? onDangerContainer,
    Color? dangerContainer,
    Color? neutral,
    Color? onNeutralContainer,
    Color? neutralContainer,
  }) {
    return AppStatusColors(
      success: success ?? this.success,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      warningContainer: warningContainer ?? this.warningContainer,
      danger: danger ?? this.danger,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      neutral: neutral ?? this.neutral,
      onNeutralContainer: onNeutralContainer ?? this.onNeutralContainer,
      neutralContainer: neutralContainer ?? this.neutralContainer,
    );
  }

  @override
  AppStatusColors lerp(covariant AppStatusColors? other, double t) {
    if (other == null) return this;
    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDangerContainer: Color.lerp(
        onDangerContainer,
        other.onDangerContainer,
        t,
      )!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      onNeutralContainer: Color.lerp(
        onNeutralContainer,
        other.onNeutralContainer,
        t,
      )!,
      neutralContainer: Color.lerp(
        neutralContainer,
        other.neutralContainer,
        t,
      )!,
    );
  }
}

class AppThemeAccent {
  final Color surface;
  final Color card;
  final Color surfaceContainerHighest;
  final Color surfaceContainerHigh;
  final Color surfaceContainer;
  final Color surfaceContainerLow;
  final Color surfaceContainerLowest;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;
  final Color edgeBright;
  final Color edgeMid;
  final Color edgeDark;
  final Color heading;
  final Color accent;
  final Color accentContainer;
  final Color onAccent;
  final List<Color> gradient;

  const AppThemeAccent({
    required this.surface,
    required this.card,
    required this.surfaceContainerHighest,
    required this.surfaceContainerHigh,
    required this.surfaceContainer,
    required this.surfaceContainerLow,
    required this.surfaceContainerLowest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.edgeBright,
    required this.edgeMid,
    required this.edgeDark,
    required this.heading,
    required this.accent,
    required this.accentContainer,
    required this.onAccent,
    required this.gradient,
  });

  static const goldDark = AppThemeAccent(
    surface: GoldPalette.surface,
    card: GoldPalette.card,
    surfaceContainerHighest: Color(0xFF1E1A12),
    surfaceContainerHigh: Color(0xFF18150F),
    surfaceContainer: Color(0xFF15120D),
    surfaceContainerLow: GoldPalette.card,
    surfaceContainerLowest: Color(0xFF090806),
    onSurface: Color(0xFFFFF9EA),
    onSurfaceVariant: GoldPalette.mutedText,
    outline: Color(0xFF9A7B2D),
    outlineVariant: Color(0xFF4A3B18),
    edgeBright: GoldPalette.edgeBright,
    edgeMid: GoldPalette.edgeMid,
    edgeDark: GoldPalette.edgeDark,
    heading: GoldPalette.primaryText,
    accent: Color(0xFFD4AF37),
    accentContainer: Color(0xFF302611),
    onAccent: Color(0xFF171106),
    gradient: [Color(0xFFF0D77B), Color(0xFFC9A227)],
  );

  static const emeraldDark = AppThemeAccent(
    surface: EmeraldPalette.surface,
    card: EmeraldPalette.card,
    surfaceContainerHighest: Color(0xFF182420),
    surfaceContainerHigh: Color(0xFF101E19),
    surfaceContainer: Color(0xFF0C1611),
    surfaceContainerLow: EmeraldPalette.card,
    surfaceContainerLowest: Color(0xFF050907),
    onSurface: Color(0xFFF1FFF7),
    onSurfaceVariant: EmeraldPalette.mutedText,
    outline: Color(0xFF3E7256),
    outlineVariant: Color(0xFF1F3A2A),
    edgeBright: EmeraldPalette.edgeBright,
    edgeMid: EmeraldPalette.edgeMid,
    edgeDark: EmeraldPalette.edgeDark,
    heading: EmeraldPalette.primaryText,
    accent: Color(0xFF4EA77D),
    accentContainer: Color(0xFF12291C),
    onAccent: Color(0xFF06130C),
    gradient: [Color(0xFFBFE3CC), Color(0xFF4EA77D)],
  );

  static const redDark = AppThemeAccent(
    surface: RedPalette.surface,
    card: RedPalette.card,
    surfaceContainerHighest: Color(0xFF1E1010),
    surfaceContainerHigh: Color(0xFF170C0C),
    surfaceContainer: Color(0xFF130A0A),
    surfaceContainerLow: RedPalette.card,
    surfaceContainerLowest: Color(0xFF0A0505),
    onSurface: Color(0xFFFFF5F3),
    onSurfaceVariant: RedPalette.mutedText,
    outline: Color(0xFF7C4545),
    outlineVariant: Color(0xFF3A2020),
    edgeBright: RedPalette.edgeBright,
    edgeMid: RedPalette.edgeMid,
    edgeDark: RedPalette.edgeDark,
    heading: RedPalette.primaryText,
    accent: Color(0xFFE05252),
    accentContainer: Color(0xFF2A1212),
    onAccent: Color(0xFF1A0A0A),
    gradient: [Color(0xFFF0A8A8), Color(0xFFE05252)],
  );

  static const goldLight = AppThemeAccent(
    surface: GoldLightPalette.surface,
    card: GoldLightPalette.card,
    surfaceContainerHighest: Color(0xFFF5EBCF),
    surfaceContainerHigh: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFFFFDF8),
    surfaceContainerLow: Color(0xFFFFFFFF),
    surfaceContainerLowest: Color(0xFFF8F0DE),
    onSurface: Color(0xFF241A06),
    onSurfaceVariant: GoldLightPalette.mutedText,
    outline: GoldLightPalette.accent,
    outlineVariant: Color(0xFFE8D39A),
    edgeBright: GoldLightPalette.edgeBright,
    edgeMid: GoldLightPalette.edgeMid,
    edgeDark: GoldLightPalette.edgeDark,
    heading: GoldLightPalette.primaryText,
    accent: GoldLightPalette.accent,
    accentContainer: GoldLightPalette.accentContainer,
    onAccent: Colors.white,
    gradient: [Color(0xFFD4AF37), Color(0xFF8A6D1D)],
  );

  static const pinkLight = AppThemeAccent(
    surface: PinkPalette.surface,
    card: PinkPalette.card,
    surfaceContainerHighest: Color(0xFFFCE4EC),
    surfaceContainerHigh: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFFFFBFC),
    surfaceContainerLow: Color(0xFFFFFFFF),
    surfaceContainerLowest: Color(0xFFFFF0F4),
    onSurface: Color(0xFF2B111A),
    onSurfaceVariant: PinkPalette.mutedText,
    outline: Color(0xFFD14D72),
    outlineVariant: Color(0xFFF1B7C8),
    edgeBright: PinkPalette.edgeBright,
    edgeMid: PinkPalette.edgeMid,
    edgeDark: PinkPalette.edgeDark,
    heading: PinkPalette.primaryText,
    accent: PinkPalette.accent,
    accentContainer: PinkPalette.accentContainer,
    onAccent: Colors.white,
    gradient: [Color(0xFFF48FB1), Color(0xFFC2185B)],
  );

  static const redLight = AppThemeAccent(
    surface: RedLightPalette.surface,
    card: RedLightPalette.card,
    surfaceContainerHighest: Color(0xFFFCE1E1),
    surfaceContainerHigh: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFFFFBFB),
    surfaceContainerLow: Color(0xFFFFFFFF),
    surfaceContainerLowest: Color(0xFFFFF0F0),
    onSurface: Color(0xFF2A1010),
    onSurfaceVariant: RedLightPalette.mutedText,
    outline: RedLightPalette.accent,
    outlineVariant: Color(0xFFF2B4B4),
    edgeBright: RedLightPalette.edgeBright,
    edgeMid: RedLightPalette.edgeMid,
    edgeDark: RedLightPalette.edgeDark,
    heading: RedLightPalette.primaryText,
    accent: RedLightPalette.accent,
    accentContainer: RedLightPalette.accentContainer,
    onAccent: Colors.white,
    gradient: [Color(0xFFEF5350), Color(0xFFB71C1C)],
  );

  static AppThemeAccent custom(Color color, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final onAccent =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final surface = isDark ? const Color(0xFF0B0B0C) : const Color(0xFFF7F7F8);
    final card = isDark ? const Color(0xFF111113) : Colors.white;
    return AppThemeAccent(
      surface: surface,
      card: card,
      surfaceContainerHighest: isDark
          ? const Color(0xFF242427)
          : const Color(0xFFECECF0),
      surfaceContainerHigh: isDark ? const Color(0xFF1B1B1F) : Colors.white,
      surfaceContainer: isDark
          ? const Color(0xFF151518)
          : const Color(0xFFFBFBFC),
      surfaceContainerLow: card,
      surfaceContainerLowest: isDark
          ? const Color(0xFF0B0B0C)
          : const Color(0xFFF0F0F3),
      onSurface: isDark ? const Color(0xFFFAFAFA) : const Color(0xFF111113),
      onSurfaceVariant: isDark
          ? const Color(0xFFB8B8BE)
          : const Color(0xFF5B5B63),
      outline: isDark ? const Color(0xFF6A6A72) : const Color(0xFF777780),
      outlineVariant: isDark
          ? const Color(0xFF303036)
          : const Color(0xFFE1E1E6),
      edgeBright: color,
      edgeMid: color,
      edgeDark: color,
      heading: color,
      accent: color,
      accentContainer: color.withValues(alpha: isDark ? 0.18 : 0.14),
      onAccent: onAccent,
      gradient: [
        Color.lerp(color, isDark ? Colors.white : Colors.black, 0.18)!,
        color,
      ],
    );
  }

  /// Resolves the shared accent specification from the active Material
  /// theme. Accent is carried by [ColorScheme.tertiary] so the primary and
  /// surface roles can remain monochrome.
  static AppThemeAccent? resolve(ThemeData theme) {
    final tertiary = theme.colorScheme.tertiary;
    if (theme.brightness == Brightness.dark) {
      if (tertiary == goldDark.accent) return goldDark;
      if (tertiary == emeraldDark.accent) return emeraldDark;
      if (tertiary == redDark.accent) return redDark;
    } else {
      if (tertiary == goldLight.accent) return goldLight;
      if (tertiary == pinkLight.accent) return pinkLight;
      if (tertiary == redLight.accent) return redLight;
    }
    if (tertiary != theme.colorScheme.onSurface) {
      return AppThemeAccent.custom(tertiary, theme.brightness);
    }
    return null;
  }
}

ThemeData getThemeData({
  required bool isDarkMode,
  bool isAmoled = false,
  String colorTheme = AppColorTheme.mono,
  Color? customAccent,
}) {
  final shouldApplyAmoled = isDarkMode && isAmoled;
  final accent = _accentFor(colorTheme, isDarkMode, customAccent);

  // Theme selection changes headings and selected states, never the
  // background family. Every mode therefore shares the same neutral surface
  // ladder so switching themes cannot make the whole app feel tinted.
  final surface = isDarkMode
      ? const Color(0xFF0B0B0C)
      : const Color(0xFFF7F7F8);
  final surfaceContainerHighest = isDarkMode
      ? const Color(0xFF242427)
      : const Color(0xFFECECF0);
  final surfaceContainerHigh = isDarkMode
      ? const Color(0xFF1B1B1F)
      : Colors.white;
  final surfaceContainer = isDarkMode
      ? const Color(0xFF151518)
      : const Color(0xFFFBFBFC);
  final surfaceContainerLow = isDarkMode
      ? const Color(0xFF111113)
      : Colors.white;
  final surfaceContainerLowest = isDarkMode
      ? const Color(0xFF0B0B0C)
      : const Color(0xFFF0F0F3);
  final onSurface = isDarkMode
      ? const Color(0xFFFAFAFA)
      : const Color(0xFF111113);
  final onSurfaceVariant = isDarkMode
      ? const Color(0xFFB8B8BE)
      : const Color(0xFF5B5B63);
  final outline = isDarkMode
      ? const Color(0xFF6A6A72)
      : const Color(0xFF777780);
  final outlineVariant = isDarkMode
      ? const Color(0xFF303036)
      : const Color(0xFFE1E1E6);
  final accentColor = accent?.accent ?? onSurface;
  final onAccent =
      accent?.onAccent ?? (isDarkMode ? Colors.black : Colors.white);

  final colorScheme = ColorScheme(
    brightness: isDarkMode ? Brightness.dark : Brightness.light,
    // Primary/secondary remain monochrome. Accent is deliberately reserved
    // for heading text and explicit selected-state surfaces.
    primary: onSurface,
    onPrimary: isDarkMode ? Colors.black : Colors.white,
    primaryContainer: surfaceContainerHigh,
    onPrimaryContainer: onSurface,
    secondary: onSurface,
    onSecondary: isDarkMode ? Colors.black : Colors.white,
    secondaryContainer: surfaceContainerHigh,
    onSecondaryContainer: onSurface,
    tertiary: accentColor,
    onTertiary: onAccent,
    tertiaryContainer: surfaceContainerHigh,
    onTertiaryContainer: onSurface,
    error: isDarkMode ? const Color(0xFFE6A0A0) : const Color(0xFFB3261E),
    onError: isDarkMode ? const Color(0xFF3A0908) : Colors.white,
    errorContainer: isDarkMode
        ? const Color(0xFF5C1A1A)
        : const Color(0xFFFFDAD6),
    onErrorContainer: isDarkMode
        ? const Color(0xFFFFDAD6)
        : const Color(0xFF410002),
    surface: shouldApplyAmoled ? Colors.black : surface,
    onSurface: onSurface,
    surfaceContainerHighest: surfaceContainerHighest,
    surfaceContainerHigh: surfaceContainerHigh,
    surfaceContainer: surfaceContainer,
    surfaceContainerLow: surfaceContainerLow,
    surfaceContainerLowest: surfaceContainerLowest,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: outlineVariant,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: isDarkMode ? Colors.white : Colors.black,
    onInverseSurface: isDarkMode ? Colors.black : Colors.white,
    inversePrimary: isDarkMode ? Colors.black : Colors.white,
    surfaceTint: Colors.transparent,
  );

  final textTheme = _buildTextTheme(
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    headingColor: accent?.heading ?? onSurface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    scaffoldBackgroundColor: shouldApplyAmoled ? Colors.black : surface,
    appBarTheme: AppBarTheme(
      backgroundColor: shouldApplyAmoled ? Colors.black : surface,
      foregroundColor: onSurface,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: accent?.heading ?? onSurface,
      ),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerColor: outlineVariant,
    cardColor: surfaceContainerLow,
    extensions: <ThemeExtension<dynamic>>[
      isDarkMode ? AppStatusColors.dark : AppStatusColors.light,
    ],
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: onSurface,
        foregroundColor: isDarkMode ? Colors.black : Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 3,
      activeTrackColor: accentColor,
      inactiveTrackColor: surfaceContainerHighest,
      thumbColor: accentColor,
      overlayColor: accentColor.withValues(alpha: 0.16),
      valueIndicatorColor: accentColor,
      valueIndicatorTextStyle: TextStyle(
        fontFamily: 'Instrument Sans',
        color: onAccent,
        fontWeight: FontWeight.w500,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        // Smooth route motion with an opaque theme-colored backdrop. The
        // backdrop prevents Android's native window from showing through
        // during predictive edge-back gestures.
        TargetPlatform.android: _SafeFadeForwardsPageTransitionsBuilder(),
      },
    ),
    fontFamily: 'Instrument Sans',
  );
}

class _SafeFadeForwardsPageTransitionsBuilder
    extends FadeForwardsPageTransitionsBuilder {
  const _SafeFadeForwardsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final transition = super.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
    return RouteTransitionTracker(
      route: route,
      child: ColoredBox(
        color: context == null
            ? Colors.transparent
            : Theme.of(context).scaffoldBackgroundColor,
        child: transition,
      ),
    );
  }
}

AppThemeAccent? _accentFor(
  String colorTheme,
  bool isDarkMode, [
  Color? customAccent,
]) {
  return switch ((colorTheme, isDarkMode)) {
    (AppColorTheme.gold, true) => AppThemeAccent.goldDark,
    (AppColorTheme.emerald, true) => AppThemeAccent.emeraldDark,
    (AppColorTheme.red, true) => AppThemeAccent.redDark,
    (AppColorTheme.gold, false) => AppThemeAccent.goldLight,
    (AppColorTheme.pink, false) => AppThemeAccent.pinkLight,
    (AppColorTheme.red, false) => AppThemeAccent.redLight,
    (AppColorTheme.custom, _) when customAccent != null =>
      AppThemeAccent.custom(
        customAccent,
        isDarkMode ? Brightness.dark : Brightness.light,
      ),
    _ => null,
  };
}

// Instrument Sans is the single family for the app. Theme color is
// reserved for headings; body copy, metadata, and controls stay monochrome.
TextTheme _buildTextTheme({
  required Color onSurface,
  required Color onSurfaceVariant,
  required Color headingColor,
}) {
  return TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Instrument Sans',
      fontWeight: FontWeight.w500,
      letterSpacing: -0.5,
      color: headingColor,
    ),
    displayMedium: TextStyle(
      fontFamily: 'Instrument Sans',
      fontWeight: FontWeight.w500,
      letterSpacing: -0.5,
      color: headingColor,
    ),
    displaySmall: TextStyle(
      fontFamily: 'Instrument Sans',
      fontWeight: FontWeight.w500,
      letterSpacing: -0.25,
      color: headingColor,
    ),
    headlineLarge: TextStyle(
      fontFamily: 'Instrument Sans',
      fontWeight: FontWeight.w500,
      letterSpacing: -0.5,
      color: headingColor,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Instrument Sans',
      fontWeight: FontWeight.w500,
      letterSpacing: -0.25,
      color: headingColor,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'Instrument Sans',
      fontWeight: FontWeight.w500,
      color: headingColor,
    ),
    titleLarge: TextStyle(
      fontFamily: 'Instrument Sans',
      fontWeight: FontWeight.w500,
      color: headingColor,
    ),
    titleMedium: TextStyle(
      fontFamily: 'Instrument Sans',
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: onSurface,
    ),
    titleSmall: TextStyle(
      fontFamily: 'Instrument Sans',
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: onSurface,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Instrument Sans',
      fontWeight: FontWeight.w400,
      letterSpacing: 0.15,
      color: onSurface,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Instrument Sans',
      fontWeight: FontWeight.w400,
      letterSpacing: 0.2,
      color: onSurface,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Instrument Sans',
      fontWeight: FontWeight.w400,
      letterSpacing: 0.1,
      color: onSurfaceVariant,
    ),
    labelLarge: TextStyle(
      fontFamily: 'Instrument Sans',
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
      color: onSurface,
    ),
    labelMedium: TextStyle(
      fontFamily: 'Instrument Sans',
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
      color: onSurfaceVariant,
    ),
    labelSmall: TextStyle(
      fontFamily: 'Instrument Sans',
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
      color: onSurfaceVariant,
    ),
  );
}
