import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_palette.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.greenBrand,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.greenBrand,
          onPrimary: Colors.white,
          secondary: AppColors.yellow,
          onSecondary: AppColors.onYellow,
          tertiary: AppColors.purple,
          onTertiary: Colors.white,
          surface: isDark ? const Color(0xFF1A1A18) : AppColors.surfaceWhite,
          onSurface: isDark ? const Color(0xFFEEEDEB) : AppColors.textPrimary,
          surfaceContainerHighest: isDark
              ? const Color(0xFF2C2C2A)
              : AppColors.surfaceWarm,
          onSurfaceVariant: isDark
              ? const Color(0xFFAAAA9E)
              : AppColors.textSecondary,
          outline: isDark ? const Color(0xFF48483E) : AppColors.mintBorder,
          outlineVariant: isDark ? const Color(0xFF3A3A30) : palette.divider,
          error: AppColors.redPin,
          onError: Colors.white,
        );

    // Titoli pesanti e stretti (800–900, tracking negativo), testo corrente
    // regolare: è il carattere del redesign.
    final baseText = GoogleFonts.interTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );
    TextStyle? heavy(TextStyle? s, double size, double tracking) => s?.copyWith(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: tracking,
      height: 1.2,
    );
    final textTheme = baseText.copyWith(
      displaySmall: heavy(baseText.displaySmall, 34, -1.2),
      headlineLarge: heavy(baseText.headlineLarge, 30, -1),
      headlineMedium: heavy(baseText.headlineMedium, 28, -0.9),
      headlineSmall: heavy(baseText.headlineSmall, 24, -0.6),
      titleLarge: heavy(baseText.titleLarge, 20, -0.4),
      titleMedium: baseText.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );

    final buttonText = GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
    );

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: isDark ? palette.divider : AppColors.mintBorder,
        width: 2,
      ),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
    );

    return base.copyWith(
      extensions: [palette],

      // Transizione "fade forwards" di Material 3 (Android 14+): la nuova
      // schermata entra con dissolvenza e un leggero scorrimento, più fluida
      // dello zoom predefinito.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      // Sfondo crema caldo: le card bianche sopra creano gerarchia.
      scaffoldBackgroundColor: isDark ? colorScheme.surface : AppColors.bgAlt,

      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? colorScheme.surface : AppColors.bgAlt,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: isDark ? const Color(0xFFEEEDEB) : AppColors.textPrimary,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF242422) : AppColors.surfaceWhite,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.greenBrand, width: 2),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.redPin, width: 2),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.redPin, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        prefixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? AppColors.greenBrand
              : palette.textDisabled,
        ),
        suffixIconColor: palette.textDisabled,
        labelStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: palette.textSecondary,
        ),
        floatingLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.mint : AppColors.greenDark,
        ),
        hintStyle: GoogleFonts.inter(fontSize: 15, color: palette.textDisabled),
        errorStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.redText,
        ),
      ),

      // Pulsante principale: giallo. Per la versione "a rilievo" con il bordo
      // inferiore pieno usare [AppButton] (widgets/app_button.dart).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: AppColors.yellow,
          foregroundColor: AppColors.onYellow,
          disabledBackgroundColor: isDark
              ? palette.divider
              : AppColors.mintBorder,
          disabledForegroundColor: palette.textDisabled,
          textStyle: buttonText,
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: isDark
              ? const Color(0xFF242422)
              : AppColors.surfaceWhite,
          side: BorderSide(
            color: isDark ? palette.divider : AppColors.mintBorder,
            width: 2,
          ),
          foregroundColor: isDark
              ? const Color(0xFFEEEDEB)
              : AppColors.greenDark,
          textStyle: buttonText,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.mint : AppColors.greenBrand,
          minimumSize: const Size(48, 44),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.onYellow,
        elevation: 0,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        color: isDark ? const Color(0xFF242422) : AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: isDark
              ? BorderSide(color: palette.divider, width: 0.5)
              : BorderSide.none,
        ),
        margin: EdgeInsets.zero,
      ),

      chipTheme: ChipThemeData(
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),

      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: AppColors.greenBrand, width: 2),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.greenBrand
              : null,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF242422) : AppColors.bgAlt,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF242422) : AppColors.bgAlt,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: colorScheme.onSurface,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: isDark
            ? const Color(0xFF3A3A30)
            : AppColors.textPrimary,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        actionTextColor: AppColors.yellow,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.greenBrand,
      ),

      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF3A3A30) : palette.divider,
        thickness: 1,
        space: 0,
      ),
    );
  }
}
