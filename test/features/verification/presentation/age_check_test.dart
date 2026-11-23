import 'package:eros_app/core/constants/support_contact.dart';
import 'package:eros_app/features/verification/domain/models/verification_models.dart';
import 'package:eros_app/features/verification/presentation/providers/verification_card_provider.dart';
import 'package:eros_app/features/verification/presentation/screens/verification_status_screen.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_profile_row.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_prompt_card.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_wall.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_selfie_capture.dart';
import '../fake_verification_http.dart';
import 'verification_status_harness.dart';

/// CF-F2 acceptance: the `AGE_CHECK` state on the status screen, the Profile row, the Matches
/// card and the wall on a date, over a real repository on stubbed HTTP.
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

  Future<void> pump(WidgetTester tester, Map<String, dynamic> status, Widget home) async {
    http.responses['GET $statusPath'] = reply(200, status);
    await pumpVerificationApp(tester, http: http, prefs: prefs, links: links, home: home);
  }

  Future<void> pumpScreen(WidgetTester tester, {required bool canStartIdCheck}) => pump(
        tester,
        ageCheckStatusJson(canStartIdCheck: canStartIdCheck),
        const VerificationStatusScreen(),
      );

  Finder button(String label) => find.widgetWithText(ElevatedButton, label);
  Finder link(String label) => find.widgetWithText(TextButton, label);

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await settle(tester);
  }

  /// The app goes to the background (the browser opens) and comes back.
  Future<void> backgroundAndResume(WidgetTester tester) async {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await settle(tester);
  }

  group('status screen', () {
    testWidgets('with an ID check: the step, why, and Confirm my age, with no support link yet',
        (tester) async {
      await pumpScreen(tester, canStartIdCheck: true);

      expect(find.text(VerificationCopy.ageCheckTitle), findsOneWidget);
      expect(find.text(VerificationCopy.ageCheckBody), findsOneWidget);
      expect(button(VerificationCopy.confirmMyAge), findsOneWidget);
      expect(link(VerificationCopy.emailSupport), findsNothing);
      // Not the selfie's "in review" or "verify" screens.
      expect(find.text(VerificationCopy.inReview), findsNothing);
      expect(button(VerificationCopy.verifyNow), findsNothing);
    });

    testWidgets('without one: the team will be in touch, and a support email', (tester) async {
      await pumpScreen(tester, canStartIdCheck: false);

      expect(find.text(VerificationCopy.ageCheckByStaff), findsOneWidget);
      expect(button(VerificationCopy.confirmMyAge), findsNothing);

      await tap(tester, link(VerificationCopy.emailSupport));

      expect(links.supportEmails, [VerificationCopy.ageCheckEmailSubject]);
      expect(http.sent('POST', ageCheckPath), isEmpty);
    });

    testWidgets('no mail app: the address is shown instead', (tester) async {
      links.mailAppOpens = false;
      await pumpScreen(tester, canStartIdCheck: false);

      await tap(tester, link(VerificationCopy.emailSupport));

      expect(find.text(VerificationCopy.noMailApp(SupportContact.email)), findsOneWidget);
    });

    testWidgets('Confirm my age opens Didit\'s link, and the status is read again on return',
        (tester) async {
      http.responses['POST $ageCheckPath'] = reply(200, {'url': diditLink});
      await pumpScreen(tester, canStartIdCheck: true);

      await tap(tester, button(VerificationCopy.confirmMyAge));

      expect(http.sent('POST', ageCheckPath), hasLength(1));
      expect(links.ageChecks, [Uri.parse(diditLink)]);

      // Didit's webhook passed the age while the user was away: staff look at the selfie next.
      http.responses['GET $statusPath'] = reply(200, statusJson('IN_REVIEW', canStart: false));
      final before = statusFetches(http);
      await backgroundAndResume(tester);

      expect(statusFetches(http), before + 1);
      expect(find.text(VerificationCopy.inReview), findsOneWidget);
      expect(find.text(VerificationCopy.ageCheckTitle), findsNothing);
    });

    testWidgets('503: says it isn\'t available, and offers the support email', (tester) async {
      http.responses['POST $ageCheckPath'] = reply(503, apiError('AGE_CHECK_UNAVAILABLE'));
      await pumpScreen(tester, canStartIdCheck: true);

      await tap(tester, button(VerificationCopy.confirmMyAge));

      expect(find.text(VerificationCopy.ageCheckUnavailable), findsOneWidget);
      expect(links.ageChecks, isEmpty);
      await tap(tester, link(VerificationCopy.emailSupport));
      expect(links.supportEmails, [VerificationCopy.ageCheckEmailSubject]);
      // Still possible to try again.
      expect(button(VerificationCopy.confirmMyAge), findsOneWidget);
    });

    testWidgets('the daily limit: says when, at once, and offers the support email',
        (tester) async {
      http.responses['POST $ageCheckPath'] =
          reply(429, apiError('AGE_CHECK_LIMIT'), headers: {'retry-after': '${5 * 3600}'});
      await pumpScreen(tester, canStartIdCheck: true);

      await tap(tester, button(VerificationCopy.confirmMyAge));

      // Answered straight away: the client doesn't sit on a long Retry-After.
      expect(http.sent('POST', ageCheckPath), hasLength(1));
      expect(
        find.text(VerificationCopy.ageCheckLimit(const Duration(hours: 5))),
        findsOneWidget,
      );
      expect(link(VerificationCopy.emailSupport), findsOneWidget);
    });

    testWidgets('a link the browser won\'t open says so', (tester) async {
      links.ageCheckOpens = false;
      http.responses['POST $ageCheckPath'] = reply(200, {'url': diditLink});
      await pumpScreen(tester, canStartIdCheck: true);

      await tap(tester, button(VerificationCopy.confirmMyAge));

      expect(find.text(VerificationCopy.ageCheckCouldNotOpen), findsOneWidget);
      expect(link(VerificationCopy.emailSupport), findsOneWidget);
    });

    testWidgets('a server error says something went wrong', (tester) async {
      http.responses['POST $ageCheckPath'] = reply(500, apiError('INTERNAL'));
      await pumpScreen(tester, canStartIdCheck: true);

      await tap(tester, button(VerificationCopy.confirmMyAge));

      expect(find.text(VerificationCopy.ageCheckFailed), findsOneWidget);
    });

    testWidgets('AGE_CHECK_BY_STAFF: the team will be in touch instead', (tester) async {
      http.responses['POST $ageCheckPath'] = reply(409, apiError('AGE_CHECK_BY_STAFF'));
      await pumpScreen(tester, canStartIdCheck: true);
      final before = statusFetches(http);

      await tap(tester, button(VerificationCopy.confirmMyAge));

      expect(statusFetches(http), before + 1);
      expect(find.text(VerificationCopy.ageCheckByStaff), findsOneWidget);
      expect(button(VerificationCopy.confirmMyAge), findsNothing);
    });

    testWidgets('AGE_CHECK_NOT_NEEDED: the status is read again and shown', (tester) async {
      http.responses['POST $ageCheckPath'] = reply(409, apiError('AGE_CHECK_NOT_NEEDED'));
      await pumpScreen(tester, canStartIdCheck: true);
      http.responses['GET $statusPath'] = reply(200, statusJson('VERIFIED', canStart: false));

      await tap(tester, button(VerificationCopy.confirmMyAge));

      expect(find.text(VerificationCopy.verified), findsOneWidget);
    });
  });

  testWidgets('Profile row: "Action needed"', (tester) async {
    await pump(
      tester,
      ageCheckStatusJson(canStartIdCheck: true),
      const Scaffold(body: VerificationProfileRow()),
    );

    expect(find.text('Action needed'), findsOneWidget);
  });

  group('Matches card', () {
    testWidgets('shows "Action needed: confirm your age"', (tester) async {
      await pump(
        tester,
        ageCheckStatusJson(canStartIdCheck: true),
        const Scaffold(body: VerificationPromptCard()),
      );

      expect(find.text(VerificationCopy.ageCheckCard), findsOneWidget);
    });

    test('comes back for the age check after a dismissal elsewhere, and stays dismissed in it',
        () {
      const ageCheck = VerificationState.ageCheck;
      expect(shouldShowVerificationCard(ageCheck, null), isTrue);
      expect(shouldShowVerificationCard(ageCheck, VerificationState.notVerified), isTrue);
      expect(shouldShowVerificationCard(ageCheck, VerificationState.retry), isTrue);
      expect(shouldShowVerificationCard(ageCheck, ageCheck), isFalse);
    });
  });

  group('wall on a date', () {
    testWidgets('Confirm my age opens the status screen at the age step', (tester) async {
      await pump(
        tester,
        ageCheckStatusJson(canStartIdCheck: true),
        const Scaffold(body: Padding(padding: EdgeInsets.all(24), child: VerificationWall())),
      );

      expect(find.text(VerificationCopy.ageCheckTitle), findsOneWidget);
      await tap(tester, button(VerificationCopy.confirmMyAge));

      expect(find.byType(VerificationStatusScreen), findsOneWidget);
      expect(find.text(VerificationCopy.ageCheckBody), findsOneWidget);
    });

    testWidgets('the compact wall in chat offers it too', (tester) async {
      await pump(
        tester,
        ageCheckStatusJson(canStartIdCheck: true),
        const Scaffold(body: VerificationWall(compact: true)),
      );

      await tap(tester, link(VerificationCopy.confirmMyAge));

      expect(find.byType(VerificationStatusScreen), findsOneWidget);
    });
  });
}
