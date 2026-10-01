import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Colori neutri (testi, superfici, divisori) che cambiano con il tema.
///
/// [AppColors] contiene i valori del tema chiaro: usati direttamente nelle
/// schermate davano testo scuro su sfondo scuro in modalità scura. Le
/// schermate leggono invece `context.palette`, registrata in [AppTheme].
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.surfaceWhite,
    required this.surfaceWarm,
    required this.bgAlt,
    required this.divider,
    required this.cardShadow,
    required this.greenLight,
  });

  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  /// Superficie delle card (bianca nel tema chiaro).
  final Color surfaceWhite;

  /// Superficie secondaria calda (input, riquadri, card della lista).
  final Color surfaceWarm;
  final Color bgAlt;
  final Color divider;
  final Color cardShadow;

  /// Sfondo tenue verde per badge, avatar e selezioni.
  final Color greenLight;

  static final light = AppPalette(
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textDisabled: AppColors.textDisabled,
    surfaceWhite: AppColors.surfaceWhite,
    surfaceWarm: AppColors.surfaceWarm,
    bgAlt: AppColors.bgAlt,
    divider: AppColors.divider,
    cardShadow: AppColors.cardShadow,
    greenLight: AppColors.greenLight,
  );

  static final dark = AppPalette(
    textPrimary: const Color(0xFFEEEDEB),
    textSecondary: const Color(0xFFAAAA9E),
    textDisabled: const Color(0xFF7D7D74),
    surfaceWhite: const Color(0xFF242422),
    surfaceWarm: const Color(0xFF2C2C2A),
    bgAlt: const Color(0xFF1A1A18),
    divider: const Color(0xFF48483E),
    cardShadow: Colors.black.withAlpha(90),
    greenLight: const Color(0xFF173A2F),
  );

  @override
  AppPalette copyWith({
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? surfaceWhite,
    Color? surfaceWarm,
    Color? bgAlt,
    Color? divider,
    Color? cardShadow,
    Color? greenLight,
  }) {
    return AppPalette(
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      surfaceWhite: surfaceWhite ?? this.surfaceWhite,
      surfaceWarm: surfaceWarm ?? this.surfaceWarm,
      bgAlt: bgAlt ?? this.bgAlt,
      divider: divider ?? this.divider,
      cardShadow: cardShadow ?? this.cardShadow,
      greenLight: greenLight ?? this.greenLight,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      surfaceWhite: Color.lerp(surfaceWhite, other.surfaceWhite, t)!,
      surfaceWarm: Color.lerp(surfaceWarm, other.surfaceWarm, t)!,
      bgAlt: Color.lerp(bgAlt, other.bgAlt, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      greenLight: Color.lerp(greenLight, other.greenLight, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
