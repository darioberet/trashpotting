class ReportDraft {
  const ReportDraft({
    required this.note,
    this.photoPath,
    this.latitude,
    this.longitude,
  });

  final String note;
  final String? photoPath;
  final double? latitude;
  final double? longitude;
}
