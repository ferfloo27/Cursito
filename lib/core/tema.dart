import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens del sistema de diseño «Cursito» (docs: Guía de identidad visual y UI).
/// Significado de color: cielo = comunicación, menta = finanzas y pagado,
/// durazno = pendiente de acción, rosa = sólo errores y rechazos.
class C {
  static const surface = Color(0xFFF6F7FB);
  static const surfaceRaised = Color(0xFFFFFFFF);
  static const line = Color(0xFFE2E4F0);
  static const ink = Color(0xFF1F2340);
  static const inkMuted = Color(0xFF5A5F7E);
  static const lila = Color(0xFFD9D3FA);
  static const lilaStrong = Color(0xFF4B44B8);
  static const onLilaStrong = Color(0xFFFFFFFF);
  static const cielo = Color(0xFFCFE8F8);
  static const cieloInk = Color(0xFF1B5579);
  static const menta = Color(0xFFCDEFDE);
  static const mentaInk = Color(0xFF1C6643);
  static const durazno = Color(0xFFFFE0CC);
  static const duraznoInk = Color(0xFF86430F);
  static const rosa = Color(0xFFFAD5DA);
  static const rosaInk = Color(0xFF962235);
}

class R {
  static const sm = 8.0;
  static const md = 14.0;
  static const lg = 22.0;
}

class T {
  static TextStyle display = GoogleFonts.fredoka(fontSize: 30, height: 36 / 30, fontWeight: FontWeight.w600, color: C.ink);
  static TextStyle title = GoogleFonts.fredoka(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600, color: C.ink);
  static TextStyle heading = GoogleFonts.figtree(fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w700, color: C.ink);
  static TextStyle body = GoogleFonts.figtree(fontSize: 15, height: 22 / 15, color: C.ink);
  static TextStyle label =
      GoogleFonts.figtree(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w600, letterSpacing: 0.26, color: C.inkMuted);
  static TextStyle caption = GoogleFonts.figtree(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, color: C.inkMuted);
  static TextStyle amount = GoogleFonts.figtree(
      fontSize: 26, height: 32 / 26, fontWeight: FontWeight.w700, color: C.ink, fontFeatures: const [FontFeature.tabularFigures()]);
}

ThemeData temaCursito() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.lilaStrong,
      primary: C.lilaStrong,
      onPrimary: C.onLilaStrong,
      surface: C.surface,
      onSurface: C.ink,
      error: C.rosaInk,
    ),
    scaffoldBackgroundColor: C.surface,
    fontFamily: GoogleFonts.figtree().fontFamily,
  );
  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: C.surface,
      foregroundColor: C.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: T.heading,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: pill,
        backgroundColor: C.lilaStrong,
        foregroundColor: C.onLilaStrong,
        textStyle: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: pill,
        foregroundColor: C.lilaStrong,
        side: const BorderSide(color: C.line, width: 1.5),
        backgroundColor: C.surfaceRaised,
        textStyle: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: C.lilaStrong,
        textStyle: GoogleFonts.figtree(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surfaceRaised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.sm), borderSide: const BorderSide(color: C.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.sm), borderSide: const BorderSide(color: C.line)),
      focusedBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(R.sm), borderSide: const BorderSide(color: C.lilaStrong, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.sm), borderSide: const BorderSide(color: C.rosaInk)),
      hintStyle: T.body.copyWith(color: C.inkMuted),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: pill,
      side: const BorderSide(color: C.line),
      backgroundColor: C.surfaceRaised,
      selectedColor: C.lila,
      labelStyle: T.label.copyWith(color: C.ink),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.ink,
      contentTextStyle: T.body.copyWith(color: Colors.white),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.surfaceRaised,
      indicatorColor: C.lila,
      labelTextStyle: WidgetStatePropertyAll(T.caption.copyWith(color: C.ink)),
    ),
    dividerTheme: const DividerThemeData(color: C.line, space: 1),
  );
}
