/// One report filed against a flagged account. Reporter identity is
/// deliberately not part of what the server hands back — see getReviewQueue
/// in functions/index.js.
class ReportSummary {
  const ReportSummary({required this.reason, required this.details, this.createdAt});

  factory ReportSummary.fromMap(Map<dynamic, dynamic> map) {
    return ReportSummary(
      reason: (map['reason'] ?? '').toString(),
      details: (map['details'] ?? '').toString(),
      createdAt: DateTime.tryParse((map['createdAt'] ?? '').toString()),
    );
  }

  final String reason;
  final String details;
  final DateTime? createdAt;
}

/// A flagged account in the moderation review queue — see getReviewQueue
/// in functions/index.js. Covers accounts auto-flagged (under_review) as
/// well as ones a reviewer has already acted on, so a past decision can be
/// revisited.
class ReviewEntry {
  const ReviewEntry({
    required this.uid,
    required this.name,
    required this.age,
    required this.primaryPhotoUrl,
    required this.accountStatus,
    required this.accountStatusMessage,
    required this.accountStatusReason,
    this.suspensionUntil,
    required this.reportCount,
    required this.reports,
  });

  factory ReviewEntry.fromMap(Map<dynamic, dynamic> map) {
    final rawReports = map['reports'];
    final reports = rawReports is List
        ? rawReports.whereType<Map>().map(ReportSummary.fromMap).toList()
        : const <ReportSummary>[];

    return ReviewEntry(
      uid: (map['uid'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      age: (map['age'] as num?)?.toInt(),
      primaryPhotoUrl: (map['primaryPhotoUrl'] ?? '').toString(),
      accountStatus: (map['accountStatus'] ?? '').toString(),
      accountStatusMessage: (map['accountStatusMessage'] ?? '').toString(),
      accountStatusReason: (map['accountStatusReason'] ?? '').toString(),
      suspensionUntil: DateTime.tryParse((map['suspensionUntil'] ?? '').toString()),
      reportCount: (map['reportCount'] as num?)?.toInt() ?? 0,
      reports: reports,
    );
  }

  final String uid;
  final String name;
  final int? age;
  final String primaryPhotoUrl;
  final String accountStatus;
  final String accountStatusMessage;
  final String accountStatusReason;
  final DateTime? suspensionUntil;
  final int reportCount;
  final List<ReportSummary> reports;
}
