import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/safety/data/models/safety_models.dart';

/// Reports and safety cancels (RFC-006 §4.7, §5 "Safety"), and reports and blocks outside a
/// date (RFC-009 §5.5, §5.8).
///
/// Logs ids, counts and sizes only. A description is never logged (primer rule 20).
class SafetyRepository {
  final ApiClient _apiClient;
  final Logger _logger = Logger();

  SafetyRepository(this._apiClient);

  /// GET /safety/reasons
  Future<List<SafetyReason>> getReasons() async {
    try {
      final response = await _apiClient.get<List<dynamic>>(ApiEndpoints.safety.reasons());
      return response.map((e) => SafetyReason.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to get report reasons', error: e);
      rethrow;
    }
  }

  /// POST /dates/{dateId}/report/evidence-url
  ///
  /// Throws [ConflictException] when evidence uploads are off.
  Future<EvidenceUploadTicket> requestEvidenceUpload(
    String dateId, {
    required String contentType,
    required int fileSizeBytes,
  }) async {
    try {
      _logger.d('🖼️  Requesting evidence upload for date $dateId ($fileSizeBytes bytes)');
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.safety.evidenceUrl(dateId),
        data: {'contentType': contentType, 'fileSizeBytes': fileSizeBytes},
      );
      return EvidenceUploadTicket.fromJson(response);
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to get an evidence upload for date $dateId', error: e);
      rethrow;
    }
  }

  /// PUT the image to the presigned [ticket].
  Future<void> uploadEvidence(
    EvidenceUploadTicket ticket, {
    required Uint8List bytes,
    required String contentType,
  }) {
    return _apiClient.uploadToS3(
      presignedUrl: ticket.uploadUrl,
      fileBytes: bytes,
      contentType: contentType,
      extraHeaders: ticket.headers,
    );
  }

  /// POST /dates/{dateId}/report
  ///
  /// Throws [ConflictException] for a second report on this date, more than 30 days after a
  /// finished date, or a safety cancel on a date that has already ended.
  Future<ReportResult> submitReport(String dateId, ReportRequest request) async {
    try {
      _logger.d('🛟 Submitting ${request.origin.name} for date $dateId '
          '(${request.evidenceIds.length} images)');
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.safety.report(dateId),
        data: request.toJson(),
      );
      final result = ReportResult.fromJson(response);
      _logger.d('✅ Report ${result.reportId} filed for date $dateId');
      return result;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to submit report for date $dateId (status ${e.statusCode})');
      rethrow;
    }
  }

  /// POST /safety/content-reports
  ///
  /// Reports a profile, or one of its photos, without touching a date or money. The two are
  /// hidden from each other from then on. A repeat returns the first report.
  ///
  /// Throws [NotFoundException] when the reporter can no longer see them (or the photo isn't
  /// theirs), and [ValidationException] for a request the backend refuses.
  Future<ContentReportResult> reportContent(ContentReportRequest request) async {
    try {
      _logger.d('🛟 Reporting user ${request.targetUserId}'
          '${request.targetMediaId == null ? '' : ' (photo ${request.targetMediaId})'}');
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.safety.contentReports(),
        data: request.toJson(),
      );
      final result = ContentReportResult.fromJson(response);
      _logger.d('✅ Content report ${result.reportId} filed'
          '${result.alreadyReported ? ' (already reported)' : ''}');
      return result;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to report user ${request.targetUserId} (status ${e.statusCode})');
      rethrow;
    }
  }

  /// POST /safety/blocks
  ///
  /// Blocks a match. Returns [BlockOutcome.activeDate] for the 409 `ACTIVE_DATE`, when a date
  /// between them is in progress. Throws [NotFoundException] when they aren't a match.
  Future<BlockOutcome> block(String userId) async {
    try {
      _logger.d('🚫 Blocking user $userId');
      await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.safety.blocks(),
        data: {'userId': userId},
      );
      _logger.d('✅ Blocked user $userId');
      return BlockOutcome.blocked;
    } on ConflictException catch (e) {
      final body = e.originalError;
      if (body is Map<String, dynamic> && body['error'] == activeDateCode) {
        _logger.i('ℹ️  Block of $userId refused: a date is in progress');
        return BlockOutcome.activeDate;
      }
      _logger.e('🚨 Failed to block user $userId (status ${e.statusCode})');
      rethrow;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to block user $userId (status ${e.statusCode})');
      rethrow;
    }
  }

  /// The `error` of the 409 `POST /safety/blocks` answers with a date in progress.
  static const String activeDateCode = 'ACTIVE_DATE';
}
