import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_button.dart';

/// Stato vuoto o di errore dentro una pagina o un pannello: icona in un
/// cerchio bianco, titolo, testo e, se serve, un pulsante (es. "Riprova").
/// Per gli stati a tutta pagina con illustrazione usare `IllustratedMessage`.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(32, 24, 32, 24),
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  /// Spazio attorno; in basso va lasciato quello di eventuali pulsanti
  /// fluttuanti sopra la pagina.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.mintBorder,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 34, color: AppColors.greenBrand),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 24 / 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (label != null && onAction != null) ...[
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: AppButton(
                      label: label,
                      icon: actionIcon,
                      variant: AppButtonVariant.secondary,
                      onPressed: onAction,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
