import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/safety/data/models/safety_models.dart';
import 'package:eros_app/features/safety/data/repositories/safety_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_safety_api.dart';

void main() {
  late FakeSafetyApi api;
  late SafetyRepository repository;

  setUp(() {
    api = FakeSafetyApi();
    repository = SafetyRepository(api);
  });

  test('reads the reasons in the order sent', () async {
    final reasons = await repository.getReasons();

    expect(reasons.map((r) => r.code), [
      'FEELS_UNSAFE',
      'THREATENING',
      'HARASSMENT',
      'SEXUAL_CONTENT',
      'FAKE_PROFILE',
      'OTHER',
    ]);
    expect(reasons.first.label, 'I feel unsafe');
  });

  test('asks for an evidence upload with the type and size, and reads the ticket', () async {
    final ticket = await repository.requestEvidenceUpload(
      '7',
      contentType: 'image/png',
      fileSizeBytes: 123456,
    );

    expect(api.sent('POST', '/dates/7/report/evidence-url').single, {
      'contentType': 'image/png',
      'fileSizeBytes': 123456,
    });
    expect(ticket.evidenceId, '0f8fad5b-d9cb-469f-a165-70867728950e');
    expect(ticket.headers, {'Content-Type': 'image/png'});
    expect(ticket.expiresAt, DateTime.utc(2026, 11, 7, 19, 15));
  });

  test('sends a report as the contract says, and reads the result', () async {
    final result = await repository.submitReport(
      '7',
      const ReportRequest(
        origin: ReportOrigin.report,
        reason: 'HARASSMENT',
        description: 'They kept messaging after I asked them to stop',
        evidenceIds: ['0f8fad5b-d9cb-469f-a165-70867728950e'],
      ),
    );

    expect(api.sent('POST', '/dates/7/report').single, {
      'origin': 'REPORT',
      'reason': 'HARASSMENT',
      'description': 'They kept messaging after I asked them to stop',
      'evidenceIds': ['0f8fad5b-d9cb-469f-a165-70867728950e'],
    });
    expect(result.reportId, 7);
    expect(result.dateEnded, isTrue);
    expect(result.yourRefund, RefundOutcome.refunded);
  });

  test('a safety cancel sends origin CANCEL and leaves out an empty description', () async {
    await repository.submitReport(
      '7',
      const ReportRequest(origin: ReportOrigin.cancel, reason: 'FEELS_UNSAFE'),
    );

    expect(api.sent('POST', '/dates/7/report').single, {
      'origin': 'CANCEL',
      'reason': 'FEELS_UNSAFE',
      'evidenceIds': <String>[],
    });
  });

  test('reads each yourRefund, and an unknown one as NONE', () {
    RefundOutcome read(String? wire) => ReportResult.fromJson(
          {'reportId': 1, 'dateEnded': false, 'yourRefund': wire},
        ).yourRefund;

    expect(read('REFUNDED'), RefundOutcome.refunded);
    expect(read('UNDER_REVIEW'), RefundOutcome.underReview);
    expect(read('NONE'), RefundOutcome.none);
    expect(read('SOMETHING_NEW'), RefundOutcome.none);
  });

  test('a 409 reaches the caller as a ConflictException', () async {
    api.responses['POST /dates/7/report'] = const ConflictException('Already reported');

    expect(
      () => repository.submitReport(
        '7',
        const ReportRequest(origin: ReportOrigin.report, reason: 'OTHER'),
      ),
      throwsA(isA<ConflictException>()),
    );
  });

  group('reports and blocks outside a date (RFC-009 §5.5, §5.8)', () {
    test('a photo report sends the target, the media id and the category', () async {
      final result = await repository.reportContent(
        const ContentReportRequest(
          targetUserId: 'user2',
          targetMediaId: 42,
          category: ContentReportCategory.intimateImage,
          description: 'Not appropriate',
        ),
      );

      expect(api.sent('POST', '/safety/content-reports').single, {
        'targetUserId': 'user2',
        'targetMediaId': 42,
        'category': 'INTIMATE_IMAGE',
        'description': 'Not appropriate',
      });
      expect(result.reportId, 31);
      expect(result.alreadyReported, isFalse);
    });

    test('a profile report leaves out the media id and an empty description', () async {
      await repository.reportContent(
        const ContentReportRequest(
          targetUserId: 'user2',
          category: ContentReportCategory.illegalContent,
        ),
      );

      expect(api.sent('POST', '/safety/content-reports').single, {
        'targetUserId': 'user2',
        'category': 'ILLEGAL_CONTENT',
      });
    });

    test('every category goes on the wire as the backend names it', () {
      expect(
        ContentReportCategory.values.map(enumToWire),
        [
          'INTIMATE_IMAGE',
          'UNDERAGE',
          'SCAM',
          'IMPERSONATION',
          'HARASSMENT',
          'ILLEGAL_CONTENT',
          'COPYRIGHT',
          'OTHER',
        ],
      );
    });

    test('a repeat report reads alreadyReported', () async {
      api.responses['POST /safety/content-reports'] = {'reportId': 30, 'alreadyReported': true};

      final result = await repository.reportContent(
        const ContentReportRequest(targetUserId: 'user2', category: ContentReportCategory.scam),
      );

      expect(result.reportId, 30);
      expect(result.alreadyReported, isTrue);
    });

    test('a block sends the user id', () async {
      final outcome = await repository.block('user2');

      expect(api.sent('POST', '/safety/blocks').single, {'userId': 'user2'});
      expect(outcome, BlockOutcome.blocked);
    });

    test('a 409 ACTIVE_DATE is a date in progress, not an error', () async {
      api.responses['POST /safety/blocks'] = ConflictException(
        'Cancel your date first. Then you can block them.',
        originalError: safetyFixture('block_active_date'),
      );

      expect(await repository.block('user2'), BlockOutcome.activeDate);
    });

    test('any other 409, and a 404, are thrown', () async {
      api.responses['POST /safety/blocks'] =
          const ConflictException('conflict', originalError: {'error': 'conflict'});
      expect(() => repository.block('user2'), throwsA(isA<ConflictException>()));

      api.responses['POST /safety/blocks'] = const NotFoundException('Match not found');
      expect(() => repository.block('user2'), throwsA(isA<NotFoundException>()));
    });
  });
}
