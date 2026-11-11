import 'package:eros_app/features/verification/domain/models/verification_models.dart';
import 'package:eros_app/features/verification/presentation/screens/verification_flow_screen.dart';
import 'package:eros_app/features/verification/presentation/screens/verification_status_screen.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_profile_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_selfie_capture.dart';
import '../fake_verification_http.dart';
import 'verification_status_harness.dart';

final Finder anyButton = find.byWidgetPredicate((w) => w is ElevatedButton || w is TextButton);

/// VF-F3 acceptance: the status screen in each state, over a real repository on stubbed HTTP.
void main() {
  late StubHttp http;
  late SharedPreferences prefs;
  late FakeVerificationLinks links;

  setUp(() async {
    http = StubHttp();
    links = FakeVerificationLinks();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpScreen(WidgetTester tester, Map<String, dynamic> status) async {
    http.responses['GET $statusPath'] = reply(200, status);
    await pumpVerificationApp(
      tester,
      http: http,
      prefs: prefs,
      links: links,
      home: const VerificationStatusScreen(),
    );
  }

  Finder button(String label) => find.widgetWithText(ElevatedButton, label);

  Future<void> pullToRefresh(WidgetTester tester) async {
    await tester.fling(find.byType(SingleChildScrollView), const Offset(0, 400), 1000);
    await settle(tester);
  }

  testWidgets('NOT_VERIFIED: why we ask, what it takes, and Verify now', (tester) async {
    await pumpScreen(tester, statusJson('NOT_VERIFIED'));

    expect(find.text(VerificationCopy.whyWeAsk), findsOneWidget);
    expect(find.text(VerificationCopy.whatItTakes), findsOneWidget);
    expect(button(VerificationCopy.verifyNow), findsOneWidget);
    // Three attempts left: nothing to say about them.
    expect(find.textContaining('attempt'), findsNothing);
  });

  testWidgets('IN_REVIEW: we\'re checking it, and nothing to start', (tester) async {
    await pumpScreen(tester, statusJson('IN_REVIEW', canStart: false));

    expect(find.text(VerificationCopy.inReview), findsOneWidget);
    expect(find.text(VerificationCopy.inReviewDetail), findsOneWidget);
    expect(anyButton, findsNothing);
  });

  group('RETRY', () {
    const photoReasons = {RetryReason.notSamePerson, RetryReason.profilePhotosUnsuitable};
    const wire = {
      RetryReason.poseMissing: 'POSE_MISSING',
      RetryReason.unclear: 'UNCLEAR',
      RetryReason.notSamePerson: 'NOT_SAME_PERSON',
      RetryReason.profilePhotosUnsuitable: 'PROFILE_PHOTOS_UNSUITABLE',
      RetryReason.other: 'OTHER',
    };

    for (final reason in RetryReason.values) {
      final photos = photoReasons.contains(reason);
      testWidgets('${wire[reason]}: the reason, Try again${photos ? ', and the photo editor' : ''}',
          (tester) async {
        await pumpScreen(tester, statusJson('RETRY', reason: wire[reason]));

        expect(find.text(VerificationCopy.retryTitle), findsOneWidget);
        expect(find.text(VerificationCopy.retryReason(reason)), findsOneWidget);
        expect(button(VerificationCopy.tryAgain), findsOneWidget);
        expect(
          find.widgetWithText(TextButton, VerificationCopy.updatePhotos),
          photos ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets('the photo editor link opens the editor, then refetches the status',
        (tester) async {
      await pumpScreen(tester, statusJson('RETRY', reason: 'NOT_SAME_PERSON'));
      final before = statusFetches(http);

      await tester.tap(find.text(VerificationCopy.updatePhotos));
      await settle(tester);

      expect(links.photoEditor, 1);
      expect(statusFetches(http), before + 1);
    });

    testWidgets('two attempts left: nothing said about them', (tester) async {
      await pumpScreen(tester, statusJson('RETRY', reason: 'UNCLEAR', attemptsLeftToday: 2));

      expect(find.textContaining('attempt'), findsNothing);
      expect(button(VerificationCopy.tryAgain), findsOneWidget);
    });

    testWidgets('one attempt left: says so, and Try again stays', (tester) async {
      await pumpScreen(tester, statusJson('RETRY', reason: 'UNCLEAR', attemptsLeftToday: 1));

      expect(find.text(VerificationCopy.attemptsLeft(1)), findsOneWidget);
      expect(button(VerificationCopy.tryAgain), findsOneWidget);
    });

    testWidgets('none left: says so, with no Try again that can only be refused', (tester) async {
      await pumpScreen(
        tester,
        statusJson('RETRY', reason: 'UNCLEAR', attemptsLeftToday: 0, canStart: false),
      );

      expect(find.text(VerificationCopy.attemptsLeft(0)), findsOneWidget);
      expect(button(VerificationCopy.tryAgain), findsNothing);
      expect(find.text(VerificationCopy.retryReason(RetryReason.unclear)), findsOneWidget);
    });
  });

  testWidgets('VERIFIED: "You\'re verified", and nothing else', (tester) async {
    await pumpScreen(tester, statusJson('VERIFIED', canStart: false));

    expect(find.text(VerificationCopy.verified), findsOneWidget);
    expect(anyButton, findsNothing);
    expect(find.text(VerificationCopy.whyWeAsk), findsNothing);
  });

  testWidgets('LOCKED: the locked message, and nothing to start', (tester) async {
    await pumpScreen(tester, statusJson('LOCKED', attemptsLeftToday: 0, canStart: false));

    expect(find.text(VerificationCopy.locked), findsOneWidget);
    expect(anyButton, findsNothing);
  });

  testWidgets('an unknown state reads as NOT_VERIFIED, and is refetched once', (tester) async {
    await pumpScreen(tester, statusJson('SOMETHING_NEW'));

    expect(find.text(VerificationCopy.whyWeAsk), findsOneWidget);
    expect(button(VerificationCopy.verifyNow), findsOneWidget);
    // The first load, then one refresh, and no loop while the server keeps saying it.
    expect(statusFetches(http), 2);
    await settle(tester);
    expect(statusFetches(http), 2);
  });

  testWidgets('pull to refresh refetches the status and shows the new state', (tester) async {
    await pumpScreen(tester, statusJson('IN_REVIEW', canStart: false));
    expect(find.text(VerificationCopy.inReview), findsOneWidget);

    http.responses['GET $statusPath'] = reply(200, statusJson('VERIFIED', canStart: false));
    await pullToRefresh(tester);

    expect(statusFetches(http), 2);
    expect(find.text(VerificationCopy.verified), findsOneWidget);
    expect(find.text(VerificationCopy.inReview), findsNothing);
  });

  testWidgets('a status that can\'t be loaded says so, and pull to refresh recovers',
      (tester) async {
    http.responses['GET $statusPath'] = reply(500, apiError('INTERNAL'));
    await pumpVerificationApp(
      tester,
      http: http,
      prefs: prefs,
      home: const VerificationStatusScreen(),
    );

    expect(find.text(VerificationCopy.statusFailed), findsOneWidget);
    expect(anyButton, findsNothing);

    http.responses['GET $statusPath'] = reply(200, statusJson('NOT_VERIFIED'));
    await pullToRefresh(tester);

    expect(find.text(VerificationCopy.statusFailed), findsNothing);
    expect(button(VerificationCopy.verifyNow), findsOneWidget);
  });

  testWidgets('Verify now opens the selfie flow, and the status is read again when it closes',
      (tester) async {
    await pumpScreen(tester, statusJson('NOT_VERIFIED'));

    await tester.tap(button(VerificationCopy.verifyNow));
    await settle(tester);
    expect(find.byType(VerificationFlowScreen), findsOneWidget);

    final before = statusFetches(http);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await settle(tester);

    expect(find.byType(VerificationFlowScreen), findsNothing);
    expect(statusFetches(http), before + 1);
  });

  testWidgets('Try again opens the selfie flow', (tester) async {
    await pumpScreen(tester, statusJson('RETRY', reason: 'POSE_MISSING'));

    await tester.tap(button(VerificationCopy.tryAgain));
    await settle(tester);

    expect(find.byType(VerificationFlowScreen), findsOneWidget);
  });

  testWidgets('a status already loaded elsewhere is refetched when the screen opens',
      (tester) async {
    http.responses['GET $statusPath'] = reply(200, statusJson('IN_REVIEW', canStart: false));
    await pumpVerificationApp(
      tester,
      http: http,
      prefs: prefs,
      // Keeps the status loaded, as the Profile row does.
      home: const Scaffold(body: VerificationProfileRow()),
    );
    expect(statusFetches(http), 1);

    http.responses['GET $statusPath'] = reply(200, statusJson('VERIFIED', canStart: false));
    await tester.tap(find.text(VerificationCopy.verifyYourProfile));
    await settle(tester);

    expect(statusFetches(http), 2);
    expect(find.text(VerificationCopy.verified), findsOneWidget);
  });

  testWidgets('a status loaded just now for the screen isn\'t fetched twice', (tester) async {
    await pumpScreen(tester, statusJson('IN_REVIEW', canStart: false));

    expect(statusFetches(http), 1);
  });
}
