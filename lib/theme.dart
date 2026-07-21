import 'package:flutter/material.dart';

/// DOCVA design language — "Sharp Tech".
///
/// A deliberately un-Material, product-grade look: angular corners (no pills),
/// crisp 1px hairline borders instead of soft diffuse shadows, a cool neutral
/// canvas, the geometric Manrope typeface, and confident electric-blue accents
/// over a deep-navy ink. Colours are taken straight from the DOCVA logo vector.
class Clinic {
  // --- Brand ink (from the logo) --------------------------------------------
  static const primary = Color(0xFF067AFA); // DOCVA electric blue (the arrow)
  static const primaryDark = Color(0xFF0A5FD0); // Pressed / darker accent
  static const brandNavy = Color(0xFF021F5F); // DOCVA deep navy (the D + text)
  static const secondary = Color(0xFF021F5F); // Headings / primary text
  static const muted = Color(0xFF5B6B85); // Slate for secondary text

  // --- Cool neutral canvas (NOT the old blue-tinted clinical palette) --------
  static const backgroundLight = Color(0xFFF4F6FA); // Cool light-gray canvas
  static const surfaceLight = Color(0xFFEDF1F7); // Subtle cool surface (chips)
  static const cardWhite = Color(0xFFFFFFFF);
  static const borderColor = Color(0xFFDDE3EC); // Crisp hairline that defines cards
  static const outlineColor = Color(0xFFC6D0DE); // Slightly stronger outline
  static const inkLine = Color(0xFF021F5F); // Structural accent line = navy

  // --- Semantic (kept separate from the brand accent) ------------------------
  static const priorityHigh = Color(0xFFD1362F); // Critical / red
  static const priorityMedium = Color(0xFFE5A100); // Warning / gold
  static const priorityLow = Color(0xFF0E8A6E); // Stable / teal (legacy)

  // --- Workflow status, tuned to the DOCVA logo (no clinical green) ----------
  // The list reads in the brand's own language: electric blue = active/your
  // turn, deep navy = filed & done, amber = waiting in the queue, red = alert.
  static const statusActive = primary; // captured · upcoming · ready to review
  static const statusWaiting = priorityMedium; // with scribe · changes · uploading
  static const statusDone = brandNavy; // approved · in EHR (settled ink)
  static const statusAlert = priorityHigh; // needs attention · failed

  // --- Geometry: angular, not pill -------------------------------------------
  static const double rCard = 10; // Cards / panels
  static const double rControl = 8; // Buttons / inputs
  static const double rChip = 6; // Chips / small tags

  /// Sharp Tech uses borders, not blur, to separate surfaces. This is a
  /// whisper-thin contact shadow only — the 1px border does the real work.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: brandNavy.withValues(alpha: 0.05),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get rowShadow => const [];

  /// A hairline border used app-wide to define cards and panels.
  static Border get hairline => Border.all(color: borderColor, width: 1);

  /// A flat, confident brand gradient reserved for the header band only.
  static const headerGradient = LinearGradient(
    colors: [Color(0xFF06266B), brandNavy],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Headings alias kept for existing call sites.
  static const accentDarkPurple = brandNavy;

  /// Subtle electric-blue gradient for the primary CTA on auth screens.
  static const buttonGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// A restrained lift under the primary CTA — tighter than the old soft glow
  /// to fit the Sharp Tech look, but still lets the button read as pressable.
  static List<BoxShadow> get buttonGlow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.22),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
}

ThemeData buildAnotTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: Clinic.primary,
    primary: Clinic.primary,
    surface: Clinic.cardWhite,
  );

  RoundedRectangleBorder ctrl([double r = Clinic.rControl]) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Clinic.backgroundLight,
    colorScheme: base.copyWith(
      surfaceContainerHighest: Clinic.surfaceLight,
      outlineVariant: Clinic.borderColor,
    ),
    fontFamily: 'Manrope',
    // Sharp look: crisp ripple, not the diffuse Material sparkle.
    splashFactory: InkRipple.splashFactory,

    appBarTheme: const AppBarTheme(
      backgroundColor: Clinic.backgroundLight,
      foregroundColor: Clinic.brandNavy,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        color: Clinic.brandNavy,
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    ),

    // Geometric hierarchy: tight, heavy display; open, legible body.
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
          color: Clinic.brandNavy,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6),
      titleLarge: TextStyle(
          color: Clinic.brandNavy,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4),
      titleMedium: TextStyle(
          color: Clinic.brandNavy,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2),
      bodyMedium: TextStyle(color: Clinic.secondary, height: 1.4),
      labelLarge: TextStyle(
          fontWeight: FontWeight.w700, letterSpacing: 0.3),
      // Uppercase micro-labels get real tracking — a Sharp Tech signature.
      labelSmall: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Clinic.muted),
    ),

    // Filled inputs, squared corners, crisp focus ring.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Clinic.cardWhite,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      hintStyle: TextStyle(color: Clinic.muted.withValues(alpha: 0.8)),
      labelStyle: const TextStyle(color: Clinic.muted),
      floatingLabelStyle: const TextStyle(
          color: Clinic.primary, fontWeight: FontWeight.w700),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Clinic.rControl),
        borderSide: const BorderSide(color: Clinic.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Clinic.rControl),
        borderSide: const BorderSide(color: Clinic.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Clinic.rControl),
        borderSide: const BorderSide(color: Clinic.primary, width: 1.8),
      ),
    ),

    // Flat, sharp-cornered buttons — no pills, no glow.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Clinic.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 50),
        elevation: 0,
        textStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
            letterSpacing: 0.3),
        shape: ctrl(),
      ).copyWith(
        overlayColor:
            WidgetStateProperty.all(Colors.white.withValues(alpha: 0.14)),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Clinic.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        elevation: 0,
        textStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3),
        shape: ctrl(),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Clinic.brandNavy,
        minimumSize: const Size(0, 50),
        side: const BorderSide(color: Clinic.outlineColor, width: 1.4),
        textStyle: const TextStyle(
            fontFamily: 'Manrope', fontWeight: FontWeight.w800),
        shape: ctrl(),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Clinic.primary,
        textStyle: const TextStyle(
            fontFamily: 'Manrope', fontWeight: FontWeight.w700),
        shape: ctrl(Clinic.rChip),
      ),
    ),

    // Cards = white + defined hairline border, effectively no elevation.
    cardTheme: CardThemeData(
      color: Clinic.cardWhite,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Clinic.rCard),
        side: const BorderSide(color: Clinic.borderColor),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: Clinic.surfaceLight,
      side: const BorderSide(color: Clinic.borderColor),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(Clinic.rChip)),
      labelStyle: const TextStyle(
          fontWeight: FontWeight.w700, color: Clinic.brandNavy, fontSize: 12),
    ),

    dividerTheme: const DividerThemeData(
      color: Clinic.borderColor,
      thickness: 1,
      space: 1,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Clinic.brandNavy,
      contentTextStyle: const TextStyle(
          fontFamily: 'Manrope', color: Colors.white, fontWeight: FontWeight.w600),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(Clinic.rControl)),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Clinic.cardWhite,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Clinic.primary.withValues(alpha: 0.12),
      indicatorShape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(Clinic.rControl)),
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontFamily: 'Manrope',
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: states.contains(WidgetState.selected)
                ? Clinic.primary
                : Clinic.muted,
          )),
    ),
  );
}
