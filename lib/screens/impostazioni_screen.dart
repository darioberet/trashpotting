import 'package:flutter/material.dart';

import '../state/theme_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

class ImpostazioniScreen extends StatelessWidget {
  const ImpostazioniScreen({super.key});

  static const _options = [
    (mode: ThemeMode.light, label: 'Chiaro', icon: Icons.light_mode_outlined),
    (mode: ThemeMode.dark, label: 'Scuro', icon: Icons.dark_mode_outlined),
    (
      mode: ThemeMode.system,
      label: 'Automatico (di sistema)',
      icon: Icons.brightness_auto_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeControllerScope.watch(context);
    final currentMode = themeController.mode;

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Aspetto',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: context.palette.divider, width: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, option) in _options.indexed) ...[
                  if (i > 0) Divider(height: 1, color: context.palette.divider),
                  InkWell(
                    onTap: () => themeController.setMode(option.mode),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            option.icon,
                            size: 18,
                            color: context.palette.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              option.label,
                              style: TextStyle(
                                fontSize: 13,
                                color: currentMode == option.mode
                                    ? context.palette.textPrimary
                                    : context.palette.textSecondary,
                                fontWeight: currentMode == option.mode
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          Icon(
                            currentMode == option.mode
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 18,
                            color: currentMode == option.mode
                                ? AppColors.greenBrand
                                : context.palette.textDisabled,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
