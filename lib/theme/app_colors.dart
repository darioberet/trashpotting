import 'package:flutter/material.dart';

import '../models/trashpot_report.dart';

abstract final class AppColors {
  static const greenBrand = Color(0xFF1D9E75);

  static ({Color bg, Color fg}) statusChip(TrashpotStatus status) {
    return switch (status) {
      TrashpotStatus.aperta || TrashpotStatus.segnalata => (
        bg: const Color(0xFFFCEBEB),
        fg: const Color(0xFF791F1F),
      ),
      TrashpotStatus.inLavorazione || TrashpotStatus.puliziaInCorso => (
        bg: const Color(0xFFFAEEDA),
        fg: const Color(0xFF633806),
      ),
      TrashpotStatus.eventoCreato => (
        bg: const Color(0xFFE6F0FF),
        fg: const Color(0xFF174EA6),
      ),
      TrashpotStatus.pulita || TrashpotStatus.ripulita => (
        bg: const Color(0xFFE1F5EE),
        fg: const Color(0xFF085041),
      ),
    };
  }
}
