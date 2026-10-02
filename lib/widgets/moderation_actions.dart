import 'package:flutter/material.dart';

import '../models/trashpot_report.dart';
import '../repositories/moderation_repository.dart';
import '../state/app_session.dart';

/// Esegue un'azione di moderazione mostrando l'esito nello snackbar comune.
Future<bool> runModerationAction(
  BuildContext context,
  Future<void> Function() action, {
  required String success,
}) async {
  final session = AppSessionScope.of(context);
  try {
    await action();
    session.publishInfo(success);
    return true;
  } catch (e) {
    session.publishError(e, fallback: 'Operazione non riuscita.');
    return false;
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final cs = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Admin: rimuove una segnalazione (archiviata in `removedReports`, foto
/// cancellate). Restituisce true se rimossa.
Future<bool> confirmRemoveReport(
  BuildContext context, {
  required ModerationRepository moderation,
  required String reportId,
}) async {
  final adminUid = AppSessionScope.of(context).currentUserId;
  if (adminUid == null) return false;
  final ok = await _confirm(
    context,
    title: 'Rimuovere la segnalazione?',
    message:
        'Sparirà dalla mappa per tutti e le sue foto verranno eliminate. '
        'Una copia resta nell\'archivio di moderazione.',
    action: 'Rimuovi',
  );
  if (!ok || !context.mounted) return false;
  return runModerationAction(
    context,
    () => moderation.removeReport(reportId: reportId, adminUid: adminUid),
    success: 'Segnalazione rimossa.',
  );
}

/// Admin: blocca un utente (non potrà più pubblicare né partecipare).
Future<bool> confirmBlockUser(
  BuildContext context, {
  required ModerationRepository moderation,
  required String uid,
}) async {
  final session = AppSessionScope.of(context);
  final adminUid = session.currentUserId;
  if (adminUid == null) return false;
  if (uid == adminUid) {
    session.publishInfo('Non puoi bloccare il tuo account.');
    return false;
  }
  final ok = await _confirm(
    context,
    title: 'Bloccare l\'autore?',
    message:
        'Non potrà più pubblicare segnalazioni, partecipare alle pulizie né '
        'guadagnare punti. Puoi sbloccarlo in qualsiasi momento da '
        'Moderazione → Utenti bloccati.',
    action: 'Blocca',
  );
  if (!ok || !context.mounted) return false;
  return runModerationAction(
    context,
    () => moderation.setBlocked(uid: uid, blocked: true, adminUid: adminUid),
    success: 'Utente bloccato.',
  );
}

/// Utente: segnala un contenuto inappropriato ai moderatori.
Future<void> showFlagReportDialog(
  BuildContext context, {
  required ModerationRepository moderation,
  required TrashpotReport report,
}) async {
  final session = AppSessionScope.of(context);
  final uid = session.currentUserId;
  if (uid == null) return;

  try {
    if (await moderation.hasFlagged(reportId: report.id, uid: uid)) {
      session.publishInfo('Hai già segnalato questo contenuto. Grazie!');
      return;
    }
  } catch (_) {
    // Verifica non riuscita: si prova comunque, le regole evitano doppioni.
  }
  if (!context.mounted) return;

  final reason = await showDialog<String>(
    context: context,
    builder: (ctx) => const _FlagDialog(),
  );
  if (reason == null || !context.mounted) return;
  await runModerationAction(
    context,
    () =>
        moderation.flagReport(report: report, reporterUid: uid, reason: reason),
    success: 'Grazie, un moderatore controllerà il contenuto.',
  );
}

class _FlagDialog extends StatefulWidget {
  const _FlagDialog();

  @override
  State<_FlagDialog> createState() => _FlagDialogState();
}

class _FlagDialogState extends State<_FlagDialog> {
  String _reason = flagReasons.first;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Segnala contenuto'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v ?? _reason),
            child: Column(
              children: [
                for (final r in flagReasons)
                  RadioListTile<String>(
                    value: r,
                    title: Text(r),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
              ],
            ),
          ),
          TextField(
            controller: _details,
            maxLength: 200,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Dettagli (facoltativo)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () {
            final details = _details.text.trim();
            Navigator.of(
              context,
            ).pop(details.isEmpty ? _reason : '$_reason: $details');
          },
          child: const Text('Invia'),
        ),
      ],
    );
  }
}
