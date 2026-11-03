/// Safety models: report reasons, evidence uploads and reports (RFC-006 §5 "Safety").
///
/// A report and a safety cancel are the same request, told apart by [ReportOrigin] (D-7).
/// Report descriptions are never logged (primer rule 20), so nothing here has a `toString`
/// that includes one.
library;

import 'package:eros_app/features/dates/data/models/date_models.dart';

/// Where a report was made: the cancel dialog's "I don't feel safe" is [cancel], every
/// other entry point is [report].
enum ReportOrigin { report, cancel }

/// What happened to the reporter's own deposit (RFC-006 §4.8).
enum RefundOutcome {
  refunded,
  underReview,
  none;

  /// An unknown value from a newer backend reads as [none]: the result screen then says
  /// nothing about money, rather than something wrong.
  static RefundOutcome fromWire(String? wire) {
    for (final value in values) {
      if (enumToWire(value) == wire) return value;
    }
    return none;
  }
}

/// A report reason, from `GET /safety/reasons`. The app shows [label] as sent and never
/// keeps its own list (primer rule 21).
class SafetyReason {
  final String code;
  final String label;

  const SafetyReason({required this.code, required this.label});

  factory SafetyReason.fromJson(Map<String, dynamic> json) => SafetyReason(
        code: json['code'] as String,
        label: json['label'] as String,
      );
}

/// A presigned upload for one evidence image, from `POST /dates/{id}/report/evidence-url`.
class EvidenceUploadTicket {
  final String evidenceId;
  final String uploadUrl;

  /// Signed into [uploadUrl], so they are sent exactly as given.
  final Map<String, String> headers;
  final DateTime expiresAt;

  const EvidenceUploadTicket({
    required this.evidenceId,
    required this.uploadUrl,
    required this.headers,
    required this.expiresAt,
  });

  factory EvidenceUploadTicket.fromJson(Map<String, dynamic> json) => EvidenceUploadTicket(
        evidenceId: json['evidenceId'] as String,
        uploadUrl: json['uploadUrl'] as String,
        headers: ((json['headers'] as Map<String, dynamic>?) ?? const {})
            .map((k, v) => MapEntry(k, v as String)),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}

/// Body of `POST /dates/{id}/report`.
class ReportRequest {
  final ReportOrigin origin;
  final String reason;

  /// Already cleaned with `UserText`; null when the person wrote nothing.
  final String? description;
  final List<String> evidenceIds;

  const ReportRequest({
    required this.origin,
    required this.reason,
    this.description,
    this.evidenceIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'origin': enumToWire(origin),
        'reason': reason,
        if (description != null) 'description': description,
        'evidenceIds': evidenceIds,
      };
}

/// Response of `POST /dates/{id}/report`.
class ReportResult {
  final int reportId;
  final bool dateEnded;
  final RefundOutcome yourRefund;

  const ReportResult({
    required this.reportId,
    required this.dateEnded,
    required this.yourRefund,
  });

  factory ReportResult.fromJson(Map<String, dynamic> json) => ReportResult(
        reportId: json['reportId'] as int,
        dateEnded: json['dateEnded'] as bool,
        yourRefund: RefundOutcome.fromWire(json['yourRefund'] as String?),
      );
}

/// Report limits. They mirror the backend (RFC-006 §5 "Safety", CH-B8); change both together.
class SafetyLimits {
  SafetyLimits._();

  /// At most this many images per report.
  static const int maxEvidenceImages = 3;

  /// Evidence image types the backend accepts. Narrower than profile photos: no WebP or HEIF.
  static const List<String> evidenceContentTypes = ['image/jpeg', 'image/png', 'image/heic'];

  /// Largest evidence image, in bytes. There is no minimum: a screenshot can be tiny.
  static const int maxEvidenceBytes = 10 * 1024 * 1024;

  /// A finished date can be reported for this long after it ended (D-22).
  static const Duration reportWindow = Duration(days: 30);

  /// How long submitting waits for images still uploading. S3 uploads have no timeout of their
  /// own, and a report matters more than its images, so after this it's sent without them.
  static const Duration submitUploadWait = Duration(seconds: 20);
}
