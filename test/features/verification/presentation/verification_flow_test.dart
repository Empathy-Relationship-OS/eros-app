import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/notifications/push_host.dart';
import 'package:eros_app/features/verification/data/selfie_camera.dart';
import 'package:eros_app/features/verification/data/selfie_processor.dart';
import 'package:eros_app/features/verification/domain/models/verification_models.dart';
import 'package:eros_app/features/verification/presentation/start_verification.dart';
import 'package:eros_app/features/verification/presentation/verification_links.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_selfie_capture.dart';
import '../fake_verification_http.dart';

/// The selfie's S3 key, the path of both the first upload link and the fresh one from a 422.
const _s3Path = '/selfies/user1/3f2504e0.jpg';

/// VF-F2 acceptance: consent, the camera, review and the results, over a fake camera, a fake
/// image processor and a real repository on stubbed HTTP.
void main() {
  late StubHttp http;
  late FakeCameraRig cameras;
  late FakeSelfieProcessor processor;
  late FakeVerificationLinks links;

  /// Completes when the flow closes.
  late Future<void>? flowClosed;

  setUp(() {
    http = StubHttp();
    cameras = FakeCameraRig();
    processor = FakeSelfieProcessor();
    links = FakeVerificationLinks();
    flowClosed = null;
    http.responses['GET $statusPath'] = reply(200, statusJson('NOT_VERIFIED'));
    http.responses['POST $attemptsPath'] = reply(200, verificationFixture('attempt_start'));
    http.responses['PUT $_s3Path'] = reply(200, null);
    http.responses['POST $submitPath'] = reply(200, {'state': 'IN_REVIEW'});
  });

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(600, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Lets the stubbed requests and the screens' futures finish. Never `pumpAndSettle`: the
  /// progress indicators never settle.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// A launcher screen with the flow opened from it, as VF-F3 and VF-F4 call it.
  Future<void> openFlow(WidgetTester tester) async {
    tallScreen(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          signedInUidProvider.overrideWith((ref) => 'dev_alice'),
          apiClientProvider.overrideWith((ref) => apiClientOver(http)),
          selfieCameraFactoryProvider.overrideWithValue(cameras.create),
          selfieProcessorProvider.overrideWithValue(processor),
          verificationLinksProvider.overrideWithValue(links),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => flowClosed = startVerification(context, ref),
                  child: const Text('Launcher'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Launcher'));
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await settle(tester);
  }

  Future<void> shutter(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel(VerificationCopy.shutterLabel));
    await settle(tester);
  }

  /// Agree, take a picture and send it.
  Future<void> agreeCaptureAndSend(WidgetTester tester) async {
    await tapText(tester, VerificationCopy.consentAgree);
    await shutter(tester);
    await tapText(tester, VerificationCopy.useThis);
  }

  List<String> uploadSignatures() => [
        for (final r in http.sent('PUT', _s3Path)) r.uri.queryParameters['X-Amz-Signature']!,
      ];

  Future<void> expectFlowClosed(WidgetTester tester) async {
    expect(find.text('Launcher'), findsOneWidget);
    await expectLater(flowClosed, completes);
  }

  group('consent comes first', () {
    testWidgets('the camera can\'t open before I agree', (tester) async {
      await openFlow(tester);

      expect(find.text(VerificationCopy.consentTitle), findsOneWidget);
      expect(cameras.made, isEmpty);
      expect(find.byKey(FakeSelfieCamera.previewKey), findsNothing);
      expect(http.sent('POST', attemptsPath), isEmpty);

      await tapText(tester, VerificationCopy.consentAgree);

      final body = http.sent('POST', attemptsPath).single.data as Map;
      expect(body, {'consentVersion': '1', 'automatedCheck': true});
      expect(cameras.open, 1);
      expect(find.byKey(FakeSelfieCamera.previewKey), findsOneWidget);
    });

    testWidgets('closing the consent screen never opens the camera', (tester) async {
      await openFlow(tester);

      await tester.tap(find.byTooltip(VerificationCopy.closeLabel));
      await settle(tester);

      await expectFlowClosed(tester);
      expect(cameras.made, isEmpty);
      expect(http.sent('POST', attemptsPath), isEmpty);
    });

    testWidgets('the staff-only choice sends automatedCheck: false', (tester) async {
      await openFlow(tester);

      await tapText(tester, VerificationCopy.consentPersonInstead);

      final body = http.sent('POST', attemptsPath).single.data as Map;
      expect(body, {'consentVersion': '1', 'automatedCheck': false});
      expect(cameras.open, 1);
    });

    testWidgets('the privacy policy link opens the policy', (tester) async {
      await openFlow(tester);

      await tapText(tester, VerificationCopy.privacyPolicyLink);

      expect(links.privacyPolicy, 1);
    });

    testWidgets('fewer than 3 photos explains and links to the photo editor', (tester) async {
      http.responses['POST $attemptsPath'] = reply(409, apiError('PHOTOS_REQUIRED'));
      await openFlow(tester);

      await tapText(tester, VerificationCopy.consentAgree);

      expect(find.text(VerificationCopy.photosRequiredBody), findsOneWidget);
      expect(cameras.made, isEmpty);

      await tapText(tester, VerificationCopy.photosRequiredAction);

      expect(links.photoEditor, 1);
      // Back from the editor: consent again, to try with the new photos.
      expect(find.text(VerificationCopy.consentAgree), findsOneWidget);
    });

    testWidgets('an attempt already with staff shows that instead of consent', (tester) async {
      http.responses['GET $statusPath'] = reply(200, statusJson('IN_REVIEW', canStart: false));
      await openFlow(tester);

      expect(find.text(VerificationCopy.inReview), findsOneWidget);
      expect(find.text(VerificationCopy.consentAgree), findsNothing);
    });
  });

  group('camera screen', () {
    testWidgets('no gallery or flip control exists', (tester) async {
      await openFlow(tester);
      await tapText(tester, VerificationCopy.consentAgree);

      for (final icon in [
        Icons.photo_library,
        Icons.photo_library_outlined,
        Icons.photo,
        Icons.image,
        Icons.add_photo_alternate,
        Icons.flip_camera_ios,
        Icons.flip_camera_android,
        Icons.cameraswitch,
        Icons.switch_camera,
      ]) {
        expect(find.byIcon(icon), findsNothing, reason: '$icon');
      }
      expect(find.textContaining(RegExp('gallery|library|upload|flip', caseSensitive: false)),
          findsNothing);

      // The only controls are the shutter and close.
      final handle = tester.ensureSemantics();
      final buttons = find.byWidgetPredicate(
        (w) => w is IconButton || w is TextButton || w is ElevatedButton || w is OutlinedButton,
      );
      expect(buttons, findsOneWidget);
      expect(find.byTooltip(VerificationCopy.closeLabel), findsOneWidget);
      expect(find.bySemanticsLabel(VerificationCopy.shutterLabel), findsOneWidget);
      handle.dispose();
    });

    testWidgets('shows the pose, the tips and a labelled shutter to screen readers',
        (tester) async {
      final handle = tester.ensureSemantics();
      await openFlow(tester);
      await tapText(tester, VerificationCopy.consentAgree);

      expect(find.text('Raise your hand beside your face'), findsOneWidget);
      for (final tip in VerificationCopy.cameraTips) {
        expect(find.text(tip), findsOneWidget);
      }
      expect(
        tester.getSemantics(find.bySemanticsLabel(VerificationCopy.shutterLabel)),
        matchesSemantics(
          label: VerificationCopy.shutterLabel,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('permission denied explains and opens Settings, then retries on return',
        (tester) async {
      cameras.failWith = SelfieCameraIssue.permissionDenied;
      await openFlow(tester);
      await tapText(tester, VerificationCopy.consentAgree);

      expect(find.text(VerificationCopy.cameraPermissionDenied), findsOneWidget);
      expect(find.bySemanticsLabel(VerificationCopy.shutterLabel), findsNothing);

      // Coming back without going to Settings doesn't ask again.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(cameras.made, hasLength(1));

      await tapText(tester, VerificationCopy.openSettings);
      expect(links.settings, 1);

      // Allowed in Settings, then back to the app.
      cameras.failWith = null;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);

      expect(cameras.open, 1);
      expect(find.byKey(FakeSelfieCamera.previewKey), findsOneWidget);
    });

    testWidgets('a phone with no front camera says so', (tester) async {
      cameras.failWith = SelfieCameraIssue.noFrontCamera;
      await openFlow(tester);
      await tapText(tester, VerificationCopy.consentAgree);

      expect(find.text(VerificationCopy.noFrontCamera), findsOneWidget);
      await tapText(tester, VerificationCopy.closeLabel);
      await expectFlowClosed(tester);
    });

    testWidgets('going to the background releases the camera and coming back reopens it',
        (tester) async {
      await openFlow(tester);
      await tapText(tester, VerificationCopy.consentAgree);
      expect(cameras.open, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await settle(tester);
      expect(cameras.open, 0);
      expect(cameras.made.single.disposed, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(cameras.made, hasLength(2));
      expect(cameras.open, 1);
      expect(find.byKey(FakeSelfieCamera.previewKey), findsOneWidget);
    });

    testWidgets('the camera is released on the review screen and when the flow closes',
        (tester) async {
      await openFlow(tester);
      await tapText(tester, VerificationCopy.consentAgree);
      await shutter(tester);

      expect(find.text(VerificationCopy.useThis), findsOneWidget);
      expect(cameras.open, 0);

      await tapText(tester, VerificationCopy.retake);
      expect(cameras.open, 1);

      await tester.tap(find.byTooltip(VerificationCopy.closeLabel));
      await settle(tester);
      await expectFlowClosed(tester);
      expect(cameras.open, 0);
    });
  });

  group('sending', () {
    testWidgets('success says we\'re checking, refreshes the status and deletes the picture',
        (tester) async {
      await openFlow(tester);
      final statusFetches = http.sent('GET', statusPath).length;

      await agreeCaptureAndSend(tester);

      expect(processor.prepared, [FakeCameraRig.picturePath(1)]);
      expect(http.sentBodies[http.requests.indexOf(http.sent('PUT', _s3Path).single)],
          FakeSelfieProcessor.bytes);
      expect(http.sent('POST', submitPath), hasLength(1));
      expect(find.text(VerificationCopy.submitted), findsOneWidget);
      expect(processor.discarded, [FakeCameraRig.picturePath(1)]);
      expect(http.sent('GET', statusPath).length, greaterThan(statusFetches));

      await tapText(tester, VerificationCopy.done);
      await expectFlowClosed(tester);
    });

    testWidgets('an automatic approval says you\'re verified', (tester) async {
      http.responses['POST $submitPath'] = reply(200, {'state': 'VERIFIED'});
      await openFlow(tester);
      http.responses['GET $statusPath'] = reply(200, statusJson('VERIFIED', canStart: false));

      await agreeCaptureAndSend(tester);

      expect(find.text(VerificationCopy.verified), findsOneWidget);
    });

    testWidgets('retake deletes the picture and opens the camera again', (tester) async {
      await openFlow(tester);
      await tapText(tester, VerificationCopy.consentAgree);
      await shutter(tester);

      await tapText(tester, VerificationCopy.retake);

      expect(processor.discarded, [FakeCameraRig.picturePath(1)]);
      expect(find.byKey(FakeSelfieCamera.previewKey), findsOneWidget);
      expect(http.sent('PUT', _s3Path), isEmpty);
    });

    testWidgets('closing the flow on the review screen deletes the picture', (tester) async {
      await openFlow(tester);
      await tapText(tester, VerificationCopy.consentAgree);
      await shutter(tester);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.popUntil((route) => route.isFirst);
      await settle(tester);

      expect(processor.discarded, [FakeCameraRig.picturePath(1)]);
    });

    testWidgets('an unusable selfie returns to the camera with its message and reuses the '
        'attempt', (tester) async {
      http.responses['POST $submitPath'] = reply(422, verificationFixture('selfie_unusable'));
      await openFlow(tester);

      await agreeCaptureAndSend(tester);

      // Back on the camera, with the problem's wording.
      expect(find.byKey(FakeSelfieCamera.previewKey), findsOneWidget);
      expect(find.text(VerificationCopy.selfieProblem(SelfieProblem.tooDark)), findsOneWidget);
      expect(processor.discarded, [FakeCameraRig.picturePath(1)]);

      http.responses['POST $submitPath'] = reply(200, {'state': 'IN_REVIEW'});
      await shutter(tester);
      await tapText(tester, VerificationCopy.useThis);

      // The same attempt, uploaded to the fresh link from the 422.
      expect(http.sent('POST', attemptsPath), hasLength(1));
      expect(uploadSignatures(), ['abc', 'fresh']);
      expect(http.sent('POST', submitPath), hasLength(2));
      expect(find.text(VerificationCopy.submitted), findsOneWidget);
      expect(processor.discarded, [FakeCameraRig.picturePath(1), FakeCameraRig.picturePath(2)]);
    });

    testWidgets('an unusable selfie with no fresh link starts a new attempt for the retake',
        (tester) async {
      http.responses['POST $submitPath'] =
          reply(422, {...apiError('SELFIE_UNUSABLE'), 'problem': 'SUNGLASSES'});
      await openFlow(tester);

      await agreeCaptureAndSend(tester);

      expect(http.sent('POST', attemptsPath), hasLength(2));
      expect(
        (http.sent('POST', attemptsPath).last.data as Map)['automatedCheck'],
        isTrue,
      );
      expect(find.text(VerificationCopy.selfieProblem(SelfieProblem.sunglasses)),
          findsOneWidget);
      expect(find.byKey(FakeSelfieCamera.previewKey), findsOneWidget);
    });

    testWidgets('an expired upload link fails, deletes the picture, and retry starts a new '
        'attempt', (tester) async {
      http.responses['PUT $_s3Path'] = reply(403, null);
      await openFlow(tester);
      await tapText(tester, VerificationCopy.consentPersonInstead);
      await shutter(tester);
      await tapText(tester, VerificationCopy.useThis);

      expect(find.text(VerificationCopy.somethingWentWrong), findsOneWidget);
      expect(processor.discarded, [FakeCameraRig.picturePath(1)]);
      expect(http.sent('POST', submitPath), isEmpty);

      await tapText(tester, VerificationCopy.tryAgain);

      final starts = http.sent('POST', attemptsPath);
      expect(starts, hasLength(2));
      // The consent choice carries over.
      expect((starts.last.data as Map)['automatedCheck'], isFalse);
      expect(find.byKey(FakeSelfieCamera.previewKey), findsOneWidget);
    });

    testWidgets('a picture that can\'t be prepared fails and is still deleted', (tester) async {
      processor.failWith = const SelfieEncodingException();
      await openFlow(tester);

      await agreeCaptureAndSend(tester);

      expect(find.text(VerificationCopy.somethingWentWrong), findsOneWidget);
      expect(processor.discarded, [FakeCameraRig.picturePath(1)]);
      expect(http.sent('PUT', _s3Path), isEmpty);
    });

    testWidgets('a network failure on submit says something went wrong', (tester) async {
      http.responses['POST $submitPath'] = reply(500, apiError('INTERNAL_ERROR'));
      await openFlow(tester);

      await agreeCaptureAndSend(tester);

      expect(find.text(VerificationCopy.somethingWentWrong), findsOneWidget);
      expect(processor.discarded, [FakeCameraRig.picturePath(1)]);
    });
  });

  group('limits', () {
    testWidgets('429 closes the flow with its message', (tester) async {
      http.responses['POST $attemptsPath'] =
          reply(429, apiError('TOO_MANY_ATTEMPTS'), headers: {'retry-after': '7200'});
      await openFlow(tester);
      final statusFetches = http.sent('GET', statusPath).length;

      await tapText(tester, VerificationCopy.consentAgree);

      expect(
        find.text(VerificationCopy.limitReached(const Duration(hours: 2))),
        findsOneWidget,
      );
      expect(find.textContaining('about 2 hours'), findsOneWidget);
      expect(cameras.made, isEmpty);
      // The state is refetched, not inferred.
      expect(http.sent('GET', statusPath).length, greaterThan(statusFetches));
      // Nothing to continue with: the only way on is out.
      expect(find.text(VerificationCopy.tryAgain), findsNothing);

      await tapText(tester, VerificationCopy.done);
      await expectFlowClosed(tester);
    });

    testWidgets('429 on submit closes the flow too', (tester) async {
      http.responses['POST $submitPath'] = reply(429, apiError('TOO_MANY_ATTEMPTS'));
      await openFlow(tester);

      await agreeCaptureAndSend(tester);

      expect(find.text(VerificationCopy.limitReached(null)), findsOneWidget);
      expect(processor.discarded, [FakeCameraRig.picturePath(1)]);
      await tapText(tester, VerificationCopy.done);
      await expectFlowClosed(tester);
    });

    testWidgets('429 once locked says to contact support', (tester) async {
      http.responses['POST $attemptsPath'] = reply(429, apiError('TOO_MANY_ATTEMPTS'));
      await openFlow(tester);
      http.responses['GET $statusPath'] = reply(200, statusJson('LOCKED', canStart: false));

      await tapText(tester, VerificationCopy.consentAgree);

      expect(find.text(VerificationCopy.locked), findsOneWidget);
      await tapText(tester, VerificationCopy.done);
      await expectFlowClosed(tester);
    });

    testWidgets('a locked status says to contact support before consent', (tester) async {
      http.responses['GET $statusPath'] = reply(200, statusJson('LOCKED', canStart: false));
      await openFlow(tester);

      expect(find.text(VerificationCopy.locked), findsOneWidget);
      expect(find.text(VerificationCopy.consentAgree), findsNothing);
    });
  });

  test('no retry wording or copy line shows a number from a score', () {
    // Rule 21: reasons, not scores. The only number in the flow's copy is a wait time.
    for (final problem in SelfieProblem.values) {
      expect(VerificationCopy.selfieProblem(problem), isNot(contains(RegExp(r'\d'))));
    }
  });
}
