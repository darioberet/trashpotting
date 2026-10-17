part of '../report_detail_screen.dart';

/// Avanzamento in tre tappe: Da pulire → In corso → Pulita, con le date.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.report});

  final TrashpotReport report;

  /// Data della tappa: "oggi, 10:12", "ieri, 18:30" o "28 set".
  static String? _stepDate(DateTime? time) {
    if (time == null) return null;
    final now = DateTime.now();
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(time.year, time.month, time.day)).inDays;
    final hhmm =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    if (days == 0) return 'oggi, $hhmm';
    if (days == 1) return 'ieri, $hhmm';
    return shortDateLabel(time);
  }

  @override
  Widget build(BuildContext context) {
    final s = report.status;
    final current = switch (s) {
      TrashpotStatus.segnalata ||
      TrashpotStatus.aperta ||
      TrashpotStatus.sparita => 0,
      TrashpotStatus.inLavorazione ||
      TrashpotStatus.eventoCreato ||
      TrashpotStatus.puliziaInCorso => 1,
      TrashpotStatus.pulita || TrashpotStatus.ripulita => 2,
    };
    final event = report.event;
    final middleDate = s == TrashpotStatus.eventoCreato && event != null
        ? event.scheduledAt
        : report.cleaningStartedAt;
    final steps = [
      (
        label: current == 0 ? 'Da pulire' : 'Segnalata',
        date: _stepDate(report.createdAt),
        color: AppColors.statusColor(TrashpotStatus.segnalata),
        light: AppColors.redLight,
        text: AppColors.redText,
        icon: AppIcons.forWasteType(report.typeLabel),
      ),
      (
        label: s == TrashpotStatus.eventoCreato ? 'Evento' : 'In corso',
        date: current >= 1 ? _stepDate(middleDate) : null,
        color: s == TrashpotStatus.eventoCreato
            ? AppColors.bluePin
            : AppColors.amberDot,
        light: s == TrashpotStatus.eventoCreato
            ? AppColors.blueLight
            : AppColors.amberLight,
        text: s == TrashpotStatus.eventoCreato
            ? AppColors.blueText
            : AppColors.amberText,
        icon: s == TrashpotStatus.eventoCreato
            ? AppIcons.calendar
            : AppIcons.clean,
      ),
      (
        label: 'Pulita',
        date: current == 2 ? _stepDate(report.cleanedAt) : null,
        color: AppColors.greenPin,
        light: AppColors.greenStatusLight,
        text: AppColors.greenDark,
        icon: AppIcons.check,
      ),
    ];

    return Semantics(
      label: 'Stato: ${steps[current].label}',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const stepWidth = 96.0;
          // La linea va dal centro della prima tappa a quello dell'ultima.
          final lineWidth = constraints.maxWidth + 32 - stepWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: stepWidth / 2 - 16,
                top: 15,
                width: lineWidth,
                height: 3,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFECE6D9),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: current / 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(-16, 0),
                child: SizedBox(
                  width: constraints.maxWidth + 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, step) in steps.indexed)
                        SizedBox(
                          width: stepWidth,
                          child: Column(
                            children: [
                              _TimelineDot(
                                done: i < current,
                                current: i == current,
                                color: step.color,
                                light: step.light,
                                icon: step.icon,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                step.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 16 / 13,
                                  fontWeight: i == current
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: i == current
                                      ? step.text
                                      : i < current
                                      ? AppColors.textPrimary
                                      : AppColors.textDisabled,
                                ),
                              ),
                              if (step.date != null)
                                Text(
                                  step.date!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 16 / 12,
                                    color: AppColors.textDisabled,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TimelineDot extends StatelessWidget {
  const _TimelineDot({
    required this.done,
    required this.current,
    required this.color,
    required this.light,
    required this.icon,
  });

  final bool done;
  final bool current;
  final Color color;
  final Color light;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (current) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: light, spreadRadius: 5)],
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      );
    }
    if (done) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: AppColors.greenStatusLight,
          shape: BoxShape.circle,
        ),
        child: const Icon(AppIcons.check, size: 16, color: AppColors.greenDark),
      );
    }
    // Tappa futura: cerchio vuoto tratteggiato.
    return CustomPaint(
      size: const Size(32, 32),
      painter: _DashedCirclePainter(color: AppColors.mintBorder),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.greenLight.withAlpha(160),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Offset.zero & size;
    const dashes = 12;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect.deflate(1), i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}
