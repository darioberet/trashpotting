import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.greenBrand,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.greenBrand,
          onPrimary: Colors.white,
          surface: isDark ? const Color(0xFF1A1A18) : AppColors.surfaceWhite,
          onSurface: isDark ? const Color(0xFFEEEDEB) : AppColors.textPrimary,
          surfaceContainerHighest: isDark
              ? const Color(0xFF2C2C2A)
              : AppColors.surfaceWarm,
          onSurfaceVariant: isDark
              ? const Color(0xFFAAAA9E)
              : AppColors.textSecondary,
          outline: isDark ? const Color(0xFF48483E) : AppColors.divider,
          outlineVariant: isDark ? const Color(0xFF3A3A30) : AppColors.divider,
          error: AppColors.redPin,
          onError: Colors.white,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.interTextTheme(
        brightness == Brightness.light
            ? ThemeData.light().textTheme
            : ThemeData.dark().textTheme,
      ),
    );

    return base.copyWith(
      // Sfondo pagina leggermente tinto (non bianco puro): le card bianche
      // sopra creano gerarchia visiva invece di un piatto bianco-su-bianco.
      scaffoldBackgroundColor: isDark ? colorScheme.surface : AppColors.bgAlt,

      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: isDark ? const Color(0xFFEEEDEB) : AppColors.textPrimary,
        ),
        shape: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF3A3A30) : AppColors.divider,
            width: 0.5,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return isDark ? const Color(0xFF2C2C2A) : AppColors.surfaceWhite;
          }
          return isDark ? const Color(0xFF242422) : AppColors.surfaceWarm;
        }),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.divider, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.divider, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.greenBrand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.redPin, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.redPin, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? const Color(0xFFAAAAAE) : AppColors.textPrimary,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.textDisabled,
        ),
        errorStyle: GoogleFonts.inter(fontSize: 11, color: AppColors.redPin),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: AppColors.greenBrand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.divider,
          disabledForegroundColor: AppColors.textDisabled,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          side: BorderSide(color: AppColors.divider, width: 0.5),
          foregroundColor: isDark
              ? const Color(0xFFEEEDEB)
              : AppColors.textPrimary,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.greenBrand,
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        height: 60,
        indicatorColor: AppColors.greenLight,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.greenBrand, size: 22);
          }
          return const IconThemeData(color: AppColors.textDisabled, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.greenDark,
              letterSpacing: 0.3,
            );
          }
          return GoogleFonts.inter(
            fontSize: 10,
            color: AppColors.textDisabled,
            letterSpacing: 0.3,
          );
        }),
      ),

      cardTheme: CardThemeData(
        // Ombra verde soffusa invece del bordo grigio piatto: dà profondità
        // senza sembrare uno scheletro bianco-su-bianco (vedi design brief).
        elevation: isDark ? 0 : 4,
        shadowColor: AppColors.cardShadow,
        surfaceTintColor: Colors.transparent,
        color: isDark ? const Color(0xFF242422) : AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isDark
              ? BorderSide(color: AppColors.divider, width: 0.5)
              : BorderSide.none,
        ),
        margin: EdgeInsets.zero,
      ),

      chipTheme: ChipThemeData(
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: isDark
            ? const Color(0xFF3A3A30)
            : AppColors.textPrimary,
        contentTextStyle: GoogleFonts.inter(fontSize: 13, color: Colors.white),
      ),

      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF3A3A30) : AppColors.divider,
        thickness: 0.5,
        space: 0,
      ),
    );
  }
}
