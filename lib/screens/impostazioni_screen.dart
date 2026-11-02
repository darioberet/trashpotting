import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/push_service.dart';
import '../state/app_session.dart';
import '../state/theme_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/menu_card.dart';
import '../widgets/tab_header.dart';

class ImpostazioniScreen extends StatelessWidget {
  const ImpostazioniScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BackHeader(title: 'Impostazioni'),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    24 + MediaQuery.of(context).padding.bottom,
                  ),
                  children: const [
                    _NotificationsSection(),
                    // Il tema scuro va rifatto per il redesign: finché è
                    // bloccato la scelta non compare.
                    if (kDarkThemeEnabled) ...[
                      SizedBox(height: 24),
                      _ThemeSection(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Preferenze notifiche. Le notifiche personali (zona ripulita, promemoria
/// eventi) sono sempre attive finché Android le consente; quella "vicino a
/// me" si può disattivare.
class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context) {
    final uid = AppSessionScope.watch(context).currentUserId;
    if (uid == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Notifiche'),
        MenuCard(
          children: [
            StreamBuilder<bool>(
              stream: PushService.instance.watchNearbyEnabled(uid),
              builder: (context, snap) {
                final enabled = snap.data ?? true;
                void toggle() =>
                    PushService.instance.setNearbyEnabled(uid, !enabled);
                return MergeSemantics(
                  child: MenuTile(
                    icon: AppIcons.nearMe,
                    label: 'Segnalazioni vicino a me',
                    subtitle:
                        'Al massimo una al giorno, entro 5 km dall\'ultima '
                        'posizione in cui hai aperto l\'app.',
                    bg: AppColors.greenLight,
                    fg: AppColors.greenDark,
                    onTap: snap.hasData ? toggle : null,
                    trailing: Switch(
                      value: enabled,
                      onChanged: snap.hasData ? (_) => toggle() : null,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Ricevi sempre le notifiche quando una tua segnalazione viene '
            'ripulita e il giorno prima degli eventi a cui partecipi. Puoi '
            'disattivare tutte le notifiche dalle impostazioni di Android.',
            style: TextStyle(
              fontSize: 13,
              height: 19 / 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeSection extends StatelessWidget {
  const _ThemeSection();

  static const _options = [
    (mode: ThemeMode.light, label: 'Chiaro', icon: AppIcons.themeLight),
    (mode: ThemeMode.dark, label: 'Scuro', icon: AppIcons.themeDark),
    (
      mode: ThemeMode.system,
      label: 'Automatico (di sistema)',
      icon: AppIcons.themeAuto,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = ThemeControllerScope.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Aspetto'),
        MenuCard(
          children: [
            for (final option in _options)
              MenuTile(
                icon: option.icon,
                label: option.label,
                bg: AppColors.yellowLight,
                fg: AppColors.yellowText,
                onTap: () => controller.setMode(option.mode),
                trailing: Icon(
                  controller.mode == option.mode
                      ? AppIcons.radioOn
                      : AppIcons.radioOff,
                  size: 20,
                  color: controller.mode == option.mode
                      ? AppColors.greenBrand
                      : AppColors.textDisabled,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
