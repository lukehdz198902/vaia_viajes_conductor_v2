import 'package:flutter/material.dart';

class VaiaColors {
  static const Color primary = Color(0xFFF59E0B);
  static const Color primaryDark = Color(0xFFD97706);
  static const Color primaryLight = Color(0xFFFCD34D);
  static const Color primaryGhost = Color(0xFFFFFBEB);

  static const Color accent = Color(0xFFEA580C);
  static const Color accentDark = Color(0xFFC2410C);
  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textInverse = Color(0xFFFFFFFF);

  static const Color bgLight = Color(0xFFFAFAF7);
  static const Color bgSubtle = Color(0xFFF5F5F0);
  static const Color bgMuted = Color(0xFFE5E7EB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF9FAFB);

  static const Color border = Color(0xFFE5E7EB);
  static const Color borderStrong = Color(0xFFD1D5DB);

  static const Color onlineGreen = Color(0xFF16A34A);
  static const Color offlineRed = Color(0xFFDC2626);
  static const Color busyOrange = Color(0xFFEA580C);

  static const Color bgDark = Color(0xFF111827);
  static const Color surfaceDark = Color(0xFF1F2937);
  static const Color surfaceDarkAlt = Color(0xFF374151);
  static const Color borderDark = Color(0xFF374151);
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFFD1D5DB);

  static const Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Gradient heroGradient = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFF59E0B), Color(0xFFFCD34D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class VaiaSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class VaiaRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;
}

class AppTheme {
  static const Color primary = VaiaColors.primary;
  static const Color primaryDark = VaiaColors.primaryDark;
  static const Color primaryLight = VaiaColors.primaryLight;
  static const Color danger = VaiaColors.danger;
  static const Color success = VaiaColors.success;
  static const Color textPrimary = VaiaColors.textPrimary;
  static const Color textSecondary = VaiaColors.textSecondary;
  static const Color textMuted = VaiaColors.textMuted;
  static const Color bgLight = VaiaColors.bgLight;
  static const Color surface = VaiaColors.surface;
  static const Color border = VaiaColors.border;

  static const Color accent = VaiaColors.accent;
  static const Color secondary = VaiaColors.accent;
  static const Color textDark = VaiaColors.textPrimary;
  static const Color textMedium = VaiaColors.textSecondary;
  static const Color textLight = VaiaColors.textMuted;
  static const Color bgCard = VaiaColors.surface;
  static const Color bgBody = VaiaColors.bgLight;
  static const Color dark = VaiaColors.textPrimary;
  static const Color onlineGreen = VaiaColors.onlineGreen;
  static const Color offlineRed = VaiaColors.offlineRed;
  static const Color darkBg = VaiaColors.bgDark;
  static const Color darkSurface = VaiaColors.surfaceDark;
  static const Color darkCard = VaiaColors.surfaceDark;
  static const Color darkBorder = VaiaColors.borderDark;
  static const Color darkTextPrimary = VaiaColors.textPrimaryDark;
  static const Color darkTextSecondary = VaiaColors.textSecondaryDark;

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: VaiaColors.primary,
      onPrimary: Colors.white,
      secondary: VaiaColors.accent,
      onSecondary: Colors.white,
      surface: VaiaColors.surface,
      onSurface: VaiaColors.textPrimary,
      error: VaiaColors.danger,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: VaiaColors.bgLight,
    primaryColor: VaiaColors.primary,
    canvasColor: VaiaColors.bgLight,
    cardColor: VaiaColors.surface,
    dividerColor: VaiaColors.border,
    hintColor: VaiaColors.textMuted,
    splashColor: VaiaColors.primary.withOpacity(0.10),
    highlightColor: VaiaColors.primary.withOpacity(0.08),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: VaiaColors.textPrimary, height: 1.1, letterSpacing: -0.5),
      displayMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary, height: 1.15, letterSpacing: -0.3),
      displaySmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary, height: 1.2),
      headlineLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary),
      headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary),
      headlineSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: VaiaColors.textPrimary),
      titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: VaiaColors.textPrimary),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: VaiaColors.textPrimary, height: 1.4),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: VaiaColors.textPrimary, height: 1.4),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: VaiaColors.textSecondary, height: 1.4),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: VaiaColors.textPrimary),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: VaiaColors.textSecondary, letterSpacing: 0.3),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: VaiaColors.textMuted, letterSpacing: 0.4),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: VaiaColors.surface,
      foregroundColor: VaiaColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: VaiaColors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: VaiaColors.textPrimary, size: 22),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VaiaColors.surface,
      hoverColor: VaiaColors.bgSubtle,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: VaiaColors.textMuted, fontSize: 14),
      labelStyle: const TextStyle(color: VaiaColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
      floatingLabelStyle: const TextStyle(color: VaiaColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
      prefixIconColor: VaiaColors.textMuted,
      suffixIconColor: VaiaColors.textMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        borderSide: const BorderSide(color: VaiaColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        borderSide: const BorderSide(color: VaiaColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        borderSide: const BorderSide(color: VaiaColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        borderSide: const BorderSide(color: VaiaColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VaiaRadius.md),
        borderSide: const BorderSide(color: VaiaColors.danger, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: VaiaColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: VaiaColors.bgMuted,
        disabledForegroundColor: VaiaColors.textMuted,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.md)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.1),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: VaiaColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 36),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.sm)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: VaiaColors.textPrimary,
        side: const BorderSide(color: VaiaColors.border, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.md)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: VaiaColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VaiaRadius.lg),
        side: const BorderSide(color: VaiaColors.border),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: VaiaColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: CircleBorder(),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: VaiaColors.surface,
      selectedItemColor: VaiaColors.primary,
      unselectedItemColor: VaiaColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    ),
    dividerTheme: const DividerThemeData(
      color: VaiaColors.border,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: VaiaColors.textPrimary,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      actionTextColor: VaiaColors.primaryLight,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.md)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: VaiaColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: VaiaColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VaiaRadius.lg)),
      titleTextStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: VaiaColors.textPrimary),
      contentTextStyle: const TextStyle(fontSize: 14, color: VaiaColors.textSecondary, height: 1.4),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: VaiaColors.primary,
      circularTrackColor: VaiaColors.bgMuted,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return VaiaColors.textMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return VaiaColors.primary;
        return VaiaColors.bgMuted;
      }),
    ),
    iconTheme: const IconThemeData(color: VaiaColors.textSecondary, size: 22),
    primaryIconTheme: const IconThemeData(color: VaiaColors.primary, size: 22),
    visualDensity: VisualDensity.compact,
  );
}

class VaiaShadows {
  static List<BoxShadow> card = [
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2)),
  ];
  static List<BoxShadow> elevated = [
    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8)),
  ];
  static List<BoxShadow> glow = [
    BoxShadow(color: VaiaColors.primary.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 4)),
  ];
}