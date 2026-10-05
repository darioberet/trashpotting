import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/time_format.dart';
import '../models/trashpot_report.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// Card di una segnalazione nelle liste (Mappa, Le mie segnalazioni): foto,
/// titolo, stato, tipo e tempo, distanza in un riquadro giallo.
class ReportCard extends StatelessWidget {
  const ReportCard({
    super.key,
    required this.report,
    required this.onTap,
    this.distance,
  });

  final TrashpotReport report;
  final VoidCallback onTap;

  /// Distanza già formattata, es. "120 m" o "2,4 km".
  final String? distance;

  IconData get _statusIcon => switch (report.status) {
    TrashpotStatus.segnalata ||
    TrashpotStatus.aperta => AppIcons.forWasteType(report.typeLabel),
    TrashpotStatus.inLavorazione ||
    TrashpotStatus.puliziaInCorso => AppIcons.clean,
    TrashpotStatus.eventoCreato => AppIcons.calendar,
    TrashpotStatus.pulita || TrashpotStatus.ripulita => AppIcons.check,
    TrashpotStatus.sparita => AppIcons.hidden,
  };

  String get _statusText {
    final event = report.event;
    return switch (report.status) {
      TrashpotStatus.segnalata || TrashpotStatus.aperta => 'Da pulire',
      TrashpotStatus.inLavorazione => 'Presa in carico',
      TrashpotStatus.puliziaInCorso => 'Pulizia in corso',
      TrashpotStatus.eventoCreato =>
        event == null ? 'Evento' : 'Evento ${shortDayLabel(event.scheduledAt)}',
      TrashpotStatus.pulita || TrashpotStatus.ripulita => 'Pulita',
      TrashpotStatus.sparita => 'Sparita',
    };
  }

  String? get _meta {
    final created = report.createdAt;
    final parts = [
      if (report.typeLabel != null) report.typeLabel!,
      if (created != null) relativeTimeLabel(created),
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final (:bg, :fg) = AppColors.statusChip(report.status);
    final participants = report.event?.participants.length ?? 0;
    final meta = _meta;
    final (distValue, distUnit) = _splitDistance(distance);

    return Semantics(
      button: true,
      label: [
        report.title,
        _statusText,
        ?meta,
        if (distance != null) 'a $distance',
      ].join(', '),
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(color: AppColors.mintBorder, offset: Offset(0, 2)),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: report.photoUrl != null
                        ? Image(
                            image: CachedNetworkImageProvider(report.photoUrl!),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _PlaceholderThumb(
                              bg: bg,
                              fg: fg,
                              icon: _statusIcon,
                            ),
                          )
                        : _PlaceholderThumb(bg: bg, fg: fg, icon: _statusIcon),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 20 / 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              height: 26,
                              padding: const EdgeInsets.only(
                                left: 7,
                                right: 10,
                              ),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_statusIcon, size: 14, color: fg),
                                  const SizedBox(width: 5),
                                  Text(
                                    _statusText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: fg,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (participants > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    AppIcons.users,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$participants',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (meta != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                AppIcons.time,
                                size: 13,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 16 / 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (distValue != null) ...[
                    const SizedBox(width: 10),
                    Container(
                      constraints: const BoxConstraints(minWidth: 56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.yellowLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            distValue,
                            style: const TextStyle(
                              fontSize: 22,
                              height: 24 / 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              color: AppColors.yellowText,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(
                            distUnit,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.yellowText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "120 m" → ("120", "m"); "2,4 km" → ("2,4", "km").
  static (String?, String) _splitDistance(String? label) {
    if (label == null) return (null, '');
    final i = label.lastIndexOf(' ');
    if (i <= 0) return (label, '');
    return (label.substring(0, i), label.substring(i + 1));
  }
}

class _PlaceholderThumb extends StatelessWidget {
  const _PlaceholderThumb({
    required this.bg,
    required this.fg,
    required this.icon,
  });

  final Color bg;
  final Color fg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      color: bg,
      child: Icon(icon, size: 28, color: fg),
    );
  }
}
