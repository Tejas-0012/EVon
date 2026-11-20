import 'package:flutter/material.dart';

class AppTheme {
  // Exact palette from EVon_Major_project/static/css/style.css
  static const Color bgDark = Color(0xFF0A0E17);
  static const Color bgCard = Color(0xFF0F172A);
  static const Color bgCardHover = Color(0xFF141E37);
  static const Color border = Color(0x2600FFAA); // rgba(0, 255, 170, 0.15)
  static const Color borderGlow = Color(0x5900FFAA); // rgba(0, 255, 170, 0.35)

  static const Color neonGreen = Color(0xFF00FFAA);
  static const Color neonCyan = Color(0xFF00D4FF);
  static const Color electricBlue = Color(0xFF3B82F6);
  static const Color purple = Color(0xFF8B5CF6);

  static const Color textMain = Color(0xFFE2E8F0);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDim = Color(0xFF64748B);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [neonGreen, neonCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [electricBlue, neonCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration glassCardDecoration({
    Color? borderColor,
    double borderRadius = 16.0,
    bool glow = false,
  }) {
    return BoxDecoration(
      color: bgCard,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? (glow ? borderGlow : border),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        if (glow)
          BoxShadow(
            color: neonGreen.withOpacity(0.18),
            blurRadius: 24,
            spreadRadius: 1,
          ),
      ],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: neonGreen,
      scaffoldBackgroundColor: bgDark,
      canvasColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: neonGreen,
        secondary: neonCyan,
        surface: bgCard,
        background: bgDark,
        onPrimary: Color(0xFF0A0E17),
        onSecondary: Color(0xFF0A0E17),
        onSurface: textMain,
        onBackground: textMain,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        foregroundColor: textMain,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textMain,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgCard,
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textDim),
        prefixIconColor: neonGreen,
        suffixIconColor: neonCyan,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: neonGreen, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonGreen,
          foregroundColor: const Color(0xFF0A0E17),
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: neonGreen,
          side: const BorderSide(color: borderGlow),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgDark,
        indicatorColor: neonGreen.withOpacity(0.18),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(color: neonGreen, fontSize: 12, fontWeight: FontWeight.bold);
          }
          return const TextStyle(color: textMuted, fontSize: 12);
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: neonGreen);
          }
          return const IconThemeData(color: textMuted);
        }),
      ),
    );
  }
}
