part of '../report_detail_screen.dart';

/// Errore o segnalazione non trovata, con il pulsante per tornare indietro.
class _DetailMessage extends StatelessWidget {
  const _DetailMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: context.palette.textSecondary),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              AppButton(
                label: 'Torna indietro',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Pulita da Dario": chi ha ripulito la zona, con i punti guadagnati.
class _CleanedByCard extends StatelessWidget {
  const _CleanedByCard({required this.report});

  final TrashpotReport report;

  @override
  Widget build(BuildContext context) {
    final name = report.cleaningOwner!.label;
    // Prima parte dell'indirizzo ("SS16" da "SS16, Ponte del Colombarone").
    final place = report.address.split(',').first.trim();
    return Container(
      padding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.greenBrand,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -34,
            top: -38,
            child: Icon(
              AppIcons.leaf,
              size: 110,
              color: Colors.white.withAlpha(36),
            ),
          ),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(41),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  name.characters.first.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pulita da $name',
                      style: const TextStyle(
                        fontSize: 17,
                        height: 22 / 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      place.isEmpty
                          ? 'Grazie! Questa zona è di nuovo pulita.'
                          : 'Grazie! $place è di nuovo pulita.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 18 / 13,
                        color: Colors.white.withAlpha(217),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Align(
                alignment: Alignment.topCenter,
                child: _PointsBadge(points: pointsPerCleanup),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pillola gialla "+N pt".
class _PointsBadge extends StatelessWidget {
  const _PointsBadge({required this.points, this.height = 26});

  final int points;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.only(left: 6, right: 8),
      decoration: BoxDecoration(
        color: AppColors.yellow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.starFilled, size: 12, color: AppColors.onYellow),
          const SizedBox(width: 3),
          Text(
            '+$points pt',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.onYellow,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tre riquadri: distanza, tempo (da quando è segnalata, o quanto ci è
/// voluto a pulirla) e conferme della community.
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.report,
    required this.distanceKm,
    required this.reporterLabel,
  });

  final TrashpotReport report;
  final double? distanceKm;
  final String? reporterLabel;

  /// Durata in forma "numero + unità": 5 min, 2 ore, 3 giorni.
  static (String, String) _durationParts(Duration d) {
    if (d.inMinutes < 60) {
      final m = d.inMinutes.clamp(1, 59);
      return ('$m', 'min');
    }
    if (d.inHours < 24) {
      return ('${d.inHours}', d.inHours == 1 ? 'ora' : 'ore');
    }
    return ('${d.inDays}', d.inDays == 1 ? 'giorno' : 'giorni');
  }

  @override
  Widget build(BuildContext context) {
    final created = report.createdAt;
    final cleaned = report.cleanedAt;
    final tiles = <Widget>[];

    final km = distanceKm;
    if (km != null) {
      final label = distanceLabel(km);
      final i = label.lastIndexOf(' ');
      tiles.add(
        _StatTile(
          value: label.substring(0, i),
          unit: label.substring(i + 1),
          caption: 'da te',
          bg: AppColors.greenLight,
          fg: AppColors.greenDark,
        ),
      );
    }
    if (created != null) {
      final isCleaned = cleaned != null;
      final (value, unit) = _durationParts(
        (cleaned ?? DateTime.now()).difference(created),
      );
      tiles.add(
        _StatTile(
          value: value,
          unit: unit,
          caption: isCleaned
              ? 'per pulirla'
              : reporterLabel == null
              ? 'fa'
              : 'fa, da $reporterLabel',
          bg: AppColors.yellowLight,
          fg: AppColors.yellowText,
        ),
      );
    }
    tiles.add(
      _StatTile(
        value: '${report.confirmations}',
        caption: report.confirmations == 1 ? 'conferma' : 'conferme',
        bg: AppColors.purpleLight,
        fg: AppColors.purpleDark,
      ),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, tile) in tiles.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: tile),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.caption,
    required this.bg,
    required this.fg,
    this.unit,
  });

  final String value;
  final String? unit;
  final String caption;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: [value, ?unit, caption].join(' '),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 26 / 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg),
            ),
            Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 16 / 12,
                fontWeight: FontWeight.w600,
                color: fg.withAlpha(204),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Riquadro informativo colorato (sparita, pulizia in corso…).
class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.icon,
    required this.text,
    required this.bg,
    required this.fg,
  });

  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 20 / 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
