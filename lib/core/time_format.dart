/// Tempo trascorso in forma breve e colloquiale: "ora", "5 min fa",
/// "2 ore fa", "ieri", "3 giorni fa", poi la data (12/03/2026).
String relativeTimeLabel(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.inMinutes < 1) return 'ora';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min fa';
  if (diff.inHours < 24) {
    return diff.inHours == 1 ? '1 ora fa' : '${diff.inHours} ore fa';
  }
  final days = DateTime(
    current.year,
    current.month,
    current.day,
  ).difference(DateTime(time.year, time.month, time.day)).inDays;
  if (days <= 1) return 'ieri';
  if (days < 7) return '$days giorni fa';
  return '${time.day.toString().padLeft(2, '0')}/'
      '${time.month.toString().padLeft(2, '0')}/${time.year}';
}

const _weekdays = ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'];
const _months = [
  'gen',
  'feb',
  'mar',
  'apr',
  'mag',
  'giu',
  'lug',
  'ago',
  'set',
  'ott',
  'nov',
  'dic',
];

/// Giorno breve, es. "sab 5 ott".
String shortDayLabel(DateTime time) =>
    '${_weekdays[time.weekday - 1]} ${time.day} ${_months[time.month - 1]}';

/// Data breve senza giorno della settimana, es. "1 ott".
String shortDateLabel(DateTime time) =>
    '${time.day} ${_months[time.month - 1]}';
