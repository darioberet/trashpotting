class ReportDraft {
  const ReportDraft({
    required this.note,
    this.photoUrl,
    this.latitude,
    this.longitude,
  });

  final String note;
  final String? photoUrl;
  final double? latitude;
  final double? longitude;
}
