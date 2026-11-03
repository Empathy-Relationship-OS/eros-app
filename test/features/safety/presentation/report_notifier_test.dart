import 'dart:async';
import 'dart:typed_data';

import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/safety/data/models/safety_models.dart';
import 'package:eros_app/features/safety/data/repositories/safety_repository.dart';
import 'package:eros_app/features/safety/presentation/providers/report_provider.dart';
import 'package:eros_app/features/safety/presentation/widgets/safety_copy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_safety_api.dart';

void main() {
  late FakeSafetyApi api;
  late ReportNotifier notifier;

  setUp(() {
    api = FakeSafetyApi();
    notifier = ReportNotifier(SafetyRepository(api), '7');
  });

  tearDown(() => notifier.dispose());

  Future<void> addPng() => notifier.addImage(bytes: pngBytes, path: 'evidence.png');

  Map<String, dynamic> sentReport() =>
      api.sent('POST', '/dates/7/report').single as Map<String, dynamic>;

  test('a reason is required', () async {
    expect(await notifier.submit(ReportOrigin.report), isFalse);
    expect(notifier.state.errorMessage, SafetyCopy.chooseReason);
    expect(api.sent('POST', '/dates/7/report'), isEmpty);
  });

  test('cleans the description with UserText and keeps its paragraphs', () async {
    notifier.selectReason('HARASSMENT');
    notifier.setDescription('  They   kept\r\n\n\n\nmessaging  ');

    expect(await notifier.submit(ReportOrigin.report), isTrue);
    expect(sentReport()['description'], 'They kept\n\nmessaging');
  });

  test('a description over 1,000 characters is refused before sending', () async {
    notifier.selectReason('OTHER');
    notifier.setDescription('a' * 1001);

    expect(await notifier.submit(ReportOrigin.report), isFalse);
    expect(notifier.state.errorMessage, contains('1000'));
    expect(api.sent('POST', '/dates/7/report'), isEmpty);
  });

  test('an uploaded image is attached by its evidence id', () async {
    await addPng();
    notifier.selectReason('HARASSMENT');

    expect(notifier.state.images.single.status, EvidenceUploadStatus.uploaded);
    expect(api.uploadedUrls, ['https://evidence.example/upload']);

    await notifier.submit(ReportOrigin.report);
    expect(sentReport()['evidenceIds'], ['0f8fad5b-d9cb-469f-a165-70867728950e']);
  });

  test('a failed upload keeps the description and does not block the report', () async {
    api.failUploads = true;
    notifier.selectReason('HARASSMENT');
    notifier.setDescription('They kept messaging');
    await addPng();

    expect(notifier.state.images.single.status, EvidenceUploadStatus.failed);
    expect(notifier.state.hasFailedImage, isTrue);
    expect(notifier.state.description, 'They kept messaging');

    expect(await notifier.submit(ReportOrigin.report), isTrue);
    expect(sentReport()['description'], 'They kept messaging');
    expect(sentReport()['evidenceIds'], isEmpty);
  });

  test('a stalled upload delays the report only until the wait runs out', () async {
    final stalled = ReportNotifier(
      SafetyRepository(api),
      '7',
      uploadWait: const Duration(milliseconds: 50),
    );
    addTearDown(stalled.dispose);
    api.uploadGate = Completer<void>();
    addTearDown(() => api.uploadGate!.complete());
    stalled.selectReason('HARASSMENT');
    unawaited(stalled.addImage(bytes: pngBytes, path: 'evidence.png'));
    await pumpEventQueue();
    expect(stalled.state.images.single.status, EvidenceUploadStatus.uploading);

    expect(await stalled.submit(ReportOrigin.report), isTrue);
    expect(sentReport()['evidenceIds'], isEmpty);
    expect(stalled.state.isSubmitting, isFalse);
    expect(stalled.state.images.single.status, EvidenceUploadStatus.uploading);
  });

  test('a failed evidence-url request is a failed image too', () async {
    api.responses['POST /dates/7/report/evidence-url'] =
        const ConflictException('Evidence uploads are off');
    await addPng();

    expect(notifier.state.images.single.status, EvidenceUploadStatus.failed);
    notifier.removeImage(notifier.state.images.single.localId);
    expect(notifier.state.images, isEmpty);
  });

  test('refuses an image type the backend does not accept, without uploading', () async {
    // A GIF header.
    await notifier.addImage(
      bytes: Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, ...List.filled(64, 0)]),
      path: 'evidence.gif',
    );

    expect(notifier.state.images, isEmpty);
    expect(notifier.state.imageError, SafetyCopy.imageWrongType);
    expect(api.sent('POST', '/dates/7/report/evidence-url'), isEmpty);
  });

  test('takes at most 3 images', () async {
    for (var i = 0; i < 4; i++) {
      await addPng();
    }

    expect(notifier.state.images, hasLength(3));
    expect(notifier.state.canAddImage, isFalse);
  });

  test('a 409 on a report says it was already reported', () async {
    api.responses['POST /dates/7/report'] = const ConflictException('Already reported');
    notifier.selectReason('OTHER');

    expect(await notifier.submit(ReportOrigin.report), isFalse);
    expect(notifier.state.errorMessage, SafetyCopy.alreadyReported);
    expect(notifier.state.conflict, isTrue);
  });

  test('a 400 with images marks them failed, so the report can go without them', () async {
    api.responses['POST /dates/7/report'] = const ValidationException('Bad evidence id');
    notifier.selectReason('OTHER');
    await addPng();

    expect(await notifier.submit(ReportOrigin.report), isFalse);
    expect(notifier.state.errorMessage, SafetyCopy.imagesNotAttached);
    expect(notifier.state.images.single.status, EvidenceUploadStatus.failed);

    api.responses['POST /dates/7/report'] = safetyFixture('report_refunded') as Object;
    expect(await notifier.submit(ReportOrigin.report), isTrue);
    expect(api.sent('POST', '/dates/7/report'), hasLength(2));
    expect(
      (api.sent('POST', '/dates/7/report').last as Map<String, dynamic>)['evidenceIds'],
      isEmpty,
    );
  });
}
