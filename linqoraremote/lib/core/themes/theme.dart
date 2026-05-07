import "package:flutter/material.dart";
import 'package:google_fonts/google_fonts.dart';

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() => darkScheme();

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF00E5FF), // Vibrant Cyan
      onPrimary: Color(0xFF00373D),
      primaryContainer: Color(0xFF004F58),
      onPrimaryContainer: Color(0xFFAAEDFF),
      secondary: Color(0xFFD0BCFF), // Soft Purple
      onSecondary: Color(0xFF381E72),
      secondaryContainer: Color(0xFF4F378B),
      onSecondaryContainer: Color(0xFFEADDFF),
      tertiary: Color(0xFFB4F088), // Fresh Green
      onTertiary: Color(0xFF223600),
      tertiaryContainer: Color(0xFF334E00),
      onTertiaryContainer: Color(0xFFCFFB9E),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000a),
      onErrorContainer: Color(0xffffdad6),
      surface: Color(0xFF0A0C10), // Deep Dark Blue/Gray
      onSurface: Color(0xFFE1E2E5),
      onSurfaceVariant: Color(0xFFC1C7CE),
      outline: Color(0xFF8B9199),
      outlineVariant: Color(0xFF41474D),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xFFE1E2E5),
      inversePrimary: Color(0xFF006875),
    );
  }

  ThemeData dark() {
    final colorScheme = darkScheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.interTextTheme(textTheme).apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.2)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary, width: 1.5),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
    );
  }

  // Fallback to dark theme for light request to maintain premium feel
  ThemeData light() => dark();
}
