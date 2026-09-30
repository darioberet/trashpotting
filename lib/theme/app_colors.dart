import 'package:flutter/material.dart';

import '../models/trashpot_report.dart';

abstract final class AppColors {
  // Brand
  static const greenBrand = Color(0xFF1D9E75);
  static const greenDark = Color(0xFF085041);
  static const greenLight = Color(0xFFE1F5EE);

  // Text
  static const textPrimary = Color(0xFF2C2C2A);
  static const textSecondary = Color(0xFF5F5E5A);
  static const textDisabled = Color(0xFF888780);

  // Surface
  static const surfaceWhite = Color(0xFFFFFFFF);
  static const surfaceWarm = Color(0xFFF1EFE8); // warm beige — input bg
  static const bgAlt = Color(
    0xFFF7F6F2,
  ); // sfondo pagina — card bianche sopra creano profondità
  static const divider = Color(0xFFD3D1C7);

  // Ombra colorata verde per dare profondità alle card primarie
  // (invece del bordo grigio piatto) — vedi design/ai_design_prompt.md.
  static final cardShadow = greenBrand.withAlpha(31); // ~rgba(29,158,117,0.12)

  // Status — amber/warning
  static const amberLight = Color(0xFFFAEEDA);
  static const amberText = Color(0xFF633806);
  static const amberDot = Color(0xFFEF9F27);

  // Status — red/error
  static const redLight = Color(0xFFFCEBEB);
  static const redText = Color(0xFF791F1F);
  static const redPin = Color(0xFFE24B4A);

  // Status — blue/event
  static const blueLight = Color(0xFFE6F0FF);
  static const blueText = Color(0xFF174EA6);

  static ({Color bg, Color fg}) statusChip(TrashpotStatus status) {
    return switch (status) {
      TrashpotStatus.segnalata => (bg: redLight, fg: redText),
      TrashpotStatus.aperta => (bg: amberLight, fg: amberText),
      TrashpotStatus.inLavorazione => (
        bg: surfaceWarm,
        fg: const Color(0xFF444441),
      ),
      TrashpotStatus.puliziaInCorso => (bg: amberLight, fg: amberText),
      TrashpotStatus.eventoCreato => (bg: blueLight, fg: blueText),
      TrashpotStatus.pulita ||
      TrashpotStatus.ripulita => (bg: greenLight, fg: greenDark),
    };
  }
}
