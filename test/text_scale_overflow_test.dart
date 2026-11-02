import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trashpotting_v3/theme/app_colors.dart';
import 'package:trashpotting_v3/theme/app_icons.dart';
import 'package:trashpotting_v3/theme/app_theme.dart';
import 'package:trashpotting_v3/theme/compact_text_scaler.dart';
import 'package:trashpotting_v3/widgets/app_button.dart';
import 'package:trashpotting_v3/widgets/app_text_field.dart';
import 'package:trashpotting_v3/widgets/menu_card.dart';
import 'package:trashpotting_v3/widgets/state_message.dart';
import 'package:trashpotting_v3/widgets/tab_header.dart';

/// Componenti condivisi su un telefono stretto con il testo ingrandito dalle
/// impostazioni (l'utente principale lo usa al 130%): un overflow fa fallire
/// il test con l'errore "A RenderFlex overflowed".
void main() {
  for (final scale in [1.3, 1.6]) {
    testWidgets('nessun overflow con testo al ${(scale * 100).round()}%', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: CompactTextScaler(TextScaler.linear(scale))),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const BackHeader(title: 'Le mie segnalazioni'),
                const SectionLabel('Contatti e documenti'),
                MenuCard(
                  children: [
                    MenuTile(
                      icon: AppIcons.nearMe,
                      label: 'Nuove segnalazioni vicino a me',
                      subtitle:
                          'Al massimo una al giorno, entro 5 km dall\'ultima '
                          'posizione in cui hai aperto l\'app.',
                      bg: AppColors.greenLight,
                      fg: AppColors.greenDark,
                      onTap: () {},
                      trailing: Switch(value: true, onChanged: (_) {}),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Segnala',
                  icon: AppIcons.addPlace,
                  badge: '+1 pt',
                  onPressed: () {},
                ),
                const SizedBox(height: 16),
                const AppTextField(
                  label: 'Email',
                  icon: AppIcons.email,
                  hintText: 'nome@esempio.it',
                ),
                const SizedBox(
                  height: 420,
                  child: StateMessage(
                    icon: AppIcons.offline,
                    title: 'Segnalazioni non disponibili',
                    message: 'Controlla la connessione e riprova.',
                    actionLabel: 'Riprova',
                    actionIcon: AppIcons.refresh,
                    onAction: _noop,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }
}

void _noop() {}
