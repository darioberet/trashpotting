import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Coppie sfondo/testo degli avatar con le iniziali.
const _avatarTints = [
  (bg: Color(0xFFBFE8D6), fg: AppColors.greenDark),
  (bg: Color(0xFFD9CCFF), fg: AppColors.purpleDark),
  (bg: Color(0xFFFFD2BC), fg: Color(0xFF8A3B0A)),
  (bg: Color(0xFFCFE0FF), fg: AppColors.blueText),
  (bg: Color(0xFFFFE3A3), fg: AppColors.yellowText),
];

/// Tinta di un utente: sempre la stessa per lo stesso id.
({Color bg, Color fg}) avatarTintFor(String seed) {
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return _avatarTints[hash % _avatarTints.length];
}

/// Iniziali del nome: "Giulia" → "G", "Mario Rossi" → "MR".
String initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  String first(String s) => s.characters.first.toUpperCase();
  if (parts.length == 1) return first(parts.first);
  return first(parts.first) + first(parts.last);
}

/// Avatar tondo con le iniziali su una tinta pastello.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    required this.seed,
    this.size = 40,
    this.ring,
    this.tint,
  });

  final String name;

  /// Determina il colore (di solito l'uid).
  final String seed;
  final double size;

  /// Anello attorno all'avatar (es. giallo per il primo in classifica).
  final ({Color color, double width})? ring;

  /// Tinta esplicita al posto di quella ricavata da [seed].
  final ({Color bg, Color fg})? tint;

  @override
  Widget build(BuildContext context) {
    final t = tint ?? avatarTintFor(seed);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.bg,
          shape: BoxShape.circle,
          boxShadow: ring == null
              ? null
              : [BoxShadow(color: ring!.color, spreadRadius: ring!.width)],
        ),
        child: Text(
          initialsOf(name),
          style: TextStyle(
            fontSize: size * 0.41,
            fontWeight: FontWeight.w800,
            color: t.fg,
          ),
        ),
      ),
    );
  }
}
