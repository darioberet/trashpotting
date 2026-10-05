import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../models/trashpot_report.dart';
import '../repositories/report_repository.dart';
import '../routes.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../widgets/app_button.dart';
import '../widgets/illustration.dart';
import '../widgets/report_card.dart';
import '../widgets/skeleton.dart';
import '../widgets/tab_header.dart';

class MieSegnalazioniScreen extends StatefulWidget {
  MieSegnalazioniScreen({super.key, ReportRepository? repository})
    : _repository = repository ?? FirestoreReportRepository();

  final ReportRepository _repository;

  @override
  State<MieSegnalazioniScreen> createState() => _MieSegnalazioniScreenState();
}

class _MieSegnalazioniScreenState extends State<MieSegnalazioniScreen> {
  // Memorizzato: ricrearlo a ogni build riaprirebbe la query.
  String? _uid;
  Stream<List<TrashpotReport>>? _stream;

  @override
  Widget build(BuildContext context) {
    final uid = AppSessionScope.of(context).currentUserId;
    if (uid != _uid) {
      _uid = uid;
      _stream = uid == null ? null : widget._repository.watchReportsByUser(uid);
    }

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
              const BackHeader(title: 'Le mie segnalazioni'),
              Expanded(
                child: uid == null
                    ? const Center(
                        child: Text(
                          'Accedi per vedere le tue segnalazioni.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : StreamBuilder<List<TrashpotReport>>(
                        stream: _stream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const SkeletonList(
                              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                              thumbSize: 72,
                            );
                          }
                          if (snapshot.hasError) {
                            return const _ErrorMessage();
                          }
                          final reports =
                              snapshot.data ?? const <TrashpotReport>[];
                          if (reports.isEmpty) return const _EmptyMessage();
                          return ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              16 + MediaQuery.of(context).padding.bottom,
                            ),
                            itemCount: reports.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final r = reports[i];
                              return ReportCard(
                                report: r,
                                onTap: () => context.push(
                                  '${AppRoutes.reportDetail}/${r.id}',
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage();

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: IllustratedMessage(
        illustration: SvgPicture.asset('assets/onboarding/segnala.svg'),
        title: 'Non hai ancora inviato segnalazioni.',
        message:
            'Hai visto dei rifiuti in giro? Una foto e la posizione: '
            'bastano 10 secondi.',
        note: const IllustratedNote(
          icon: AppIcons.starFilled,
          boldLead: 'La prima vale 1 punto',
          text: 'e ti fa entrare in classifica',
          bg: AppColors.greenLight,
          fg: AppColors.greenDark,
          iconBg: AppColors.yellow,
          iconFg: AppColors.onYellow,
        ),
        primary: AppButton(
          label: 'Fai la prima segnalazione',
          icon: AppIcons.addPlace,
          onPressed: () => context.push(AppRoutes.segnala),
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.offline, size: 48, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text(
              'Errore di rete. Riprova più tardi.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
