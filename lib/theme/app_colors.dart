import 'package:flutter/material.dart';

import '../models/trashpot_report.dart';

/// Colori del tema chiaro (redesign "Trashpotting — Redesign", ott 2026).
///
/// Il verde resta il colore del brand, il giallo è quello delle azioni
/// principali (Segnala, Accedi, Voglio pulire…), il viola quello della
/// community (voti "È ancora lì?", conferme).
abstract final class AppColors {
  // Brand
  static const greenBrand = Color(0xFF0B7A5C);
  static const greenDark = Color(0xFF064E3B);
  static const greenLight = Color(0xFFE4F3EA);

  /// Verde foresta di nav bar, header di Login e Classifica.
  static const forest = Color(0xFF0E3B2E);

  /// Verde menta: accenti su sfondo foresta (foglie decorative, anelli).
  static const mint = Color(0xFF17B890);

  /// Testo secondario su sfondo foresta.
  static const mintText = Color(0xFFA9D8C3);

  /// Bordi di campi e card (anche "ombra piena" sotto le card bianche).
  static const mintBorder = Color(0xFFCDEBDB);

  // Azione principale (giallo)
  static const yellow = Color(0xFFFFC53D);
  static const onYellow = Color(0xFF2A1B00);

  /// Bordo inferiore "a rilievo" dei pulsanti gialli.
  static const yellowEdge = Color(0xFFD99A00);
  static const yellowLight = Color(0xFFFFF3CF);
  static const yellowText = Color(0xFF7A5200);

  // Community (viola)
  static const purple = Color(0xFF6E4CE0);
  static const purpleDark = Color(0xFF4B2FB0);
  static const purpleLight = Color(0xFFECE6FF);

  // Text
  static const textPrimary = Color(0xFF10231D);
  static const textSecondary = Color(0xFF52615B);
  static const textDisabled = Color(0xFF87938E);

  // Surface
  static const surfaceWhite = Color(0xFFFFFFFF);
  static const surfaceWarm = Color(0xFFF2EDE1);
  static const bgAlt = Color(0xFFFAF7F0); // sfondo pagina, crema caldo
  static const divider = Color(0xFFE8E1D2);

  static final cardShadow = textPrimary.withAlpha(31);

  // Stati: "Da pulire" (rosso)
  static const redPin = Color(0xFFE5484D);
  static const redLight = Color(0xFFFDECEC);
  static const redText = Color(0xFFB42324);

  // Stati: "In corso" (arancio)
  static const amberDot = Color(0xFFF76B15);
  static const amberLight = Color(0xFFFEEEE2);
  static const amberText = Color(0xFFA8410A);

  // Stati: "Evento" (blu)
  static const bluePin = Color(0xFF3E63DD);
  static const blueLight = Color(0xFFECF0FD);
  static const blueText = Color(0xFF2A44A8);

  // Stati: "Pulita" (verde)
  static const greenPin = Color(0xFF17A376);
  static const greenStatusLight = Color(0xFFDDF3EA);
  static const greenStatusText = Color(0xFF0A6B4D);

  // Stati: "Sparita" (grigio)
  static const greyPin = Color(0xFF8B9590);
  static const greyLight = Color(0xFFEDEFEE);

  static ({Color bg, Color fg}) statusChip(TrashpotStatus status) {
    return switch (status) {
      TrashpotStatus.segnalata ||
      TrashpotStatus.aperta => (bg: redLight, fg: redText),
      TrashpotStatus.inLavorazione ||
      TrashpotStatus.puliziaInCorso => (bg: amberLight, fg: amberText),
      TrashpotStatus.eventoCreato => (bg: blueLight, fg: blueText),
      TrashpotStatus.pulita ||
      TrashpotStatus.ripulita => (bg: greenStatusLight, fg: greenStatusText),
      TrashpotStatus.sparita => (bg: greyLight, fg: textSecondary),
    };
  }

  /// Colore pieno dello stato (pin, pallini dei filtri, timeline).
  static Color statusColor(TrashpotStatus status) {
    return switch (status) {
      TrashpotStatus.segnalata || TrashpotStatus.aperta => redPin,
      TrashpotStatus.inLavorazione || TrashpotStatus.puliziaInCorso => amberDot,
      TrashpotStatus.eventoCreato => bluePin,
      TrashpotStatus.pulita || TrashpotStatus.ripulita => greenPin,
      TrashpotStatus.sparita => greyPin,
    };
  }
}
