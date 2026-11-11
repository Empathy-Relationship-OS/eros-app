import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/screens/availability_picker_screen.dart';
import 'package:eros_app/features/dates/presentation/screens/date_detail_screen.dart';
import 'package:eros_app/features/dates/presentation/screens/deposit_sheet.dart';
import 'package:eros_app/features/dates/presentation/screens/venue_ranking_screen.dart';
import 'package:eros_app/features/dates/presentation/widgets/booking_card.dart';
import 'package:eros_app/features/dates/presentation/widgets/cancel_date_dialog.dart';
import 'package:eros_app/features/dates/presentation/widgets/date_card.dart';
import 'package:eros_app/features/dates/presentation/widgets/date_formats.dart';
import 'package:eros_app/features/dates/presentation/widgets/date_verification_wall.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';
import 'package:eros_app/features/safety/presentation/widgets/safety_copy.dart';
import 'package:eros_app/features/verification/presentation/providers/verification_provider.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../safety/fake_safety_api.dart';
import 'verification_wall_harness.dart';

/// One of the four steps the gate covers, with the action the wall replaces.
typedef _Step = ({String state, String action});

const List<_Step> _steps = [
  (state: 'AWAITING_AVAILABILITY', action: 'Pick your times'),
  (state: 'AWAITING_DEPOSIT', action: 'Commit 5'),
  (state: 'AWAITING_VENUE_RANKING', action: 'Rank venues'),
  (state: 'AWAITING_PRESENCE_CONFIRMATION', action: DatesCopy.presenceButtonText),
];

Finder get _wall => find.text(VerificationCopy.wallTitle);

/// The step's action button. The status pill can carry the same words.
Finder _action(_Step step) =>
    find.descendant(of: find.byType(ElevatedButton), matching: find.textContaining(step.action));

Future<void> _pumpDetail(WidgetTester tester, FakeSafetyApi api) =>
    pumpWall(tester, api, const DateDetailScreen(dateId: '7'));

Future<void> _openOverflow(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
}

/// Three free slots four days out, so the picker can send.
List<Map<String, dynamic>> _threeFreeSlots() {
  final day = DateTime.now().toUtc().add(const Duration(days: 4));
  final start = DateTime.utc(day.year, day.month, day.day, 17);
  return [
    for (var i = 0; i < 3; i++)
      {
        'slotStart': start.add(Duration(minutes: 30 * i)).toIso8601String(),
        'availability': 'AVAILABLE',
      },
  ];
}

Map<String, dynamic> _availabilityJson({List<Map<String, dynamic>> mySlots = const []}) => {
      'dateId': 7,
      'activityName': 'Dinner',
      'durationMinutes': 120,
      'currentRound': 1,
      'mySlots': mySlots,
      'partnerSlots': <Object>[],
      'blockedSlots': <Object>[],
    };

DateDetail _detail(String state, {bool verificationRequired = false}) =>
    DateDetail.fromJson(wallDateJson(state, verificationRequired: verificationRequired));

void main() {
  group('date detail: the wall on each step', () {
    final states = <({String name, Map<String, dynamic> status, List<String> shows})>[
      (
        name: 'NOT_VERIFIED',
        status: statusJson('NOT_VERIFIED'),
        shows: [VerificationCopy.verifyNow],
      ),
      (name: 'IN_REVIEW', status: statusJson('IN_REVIEW'), shows: [VerificationCopy.inReview]),
      (
        name: 'RETRY',
        status: statusJson('RETRY', reason: 'UNCLEAR'),
        shows: ['The picture was too dark or blurry', VerificationCopy.tryAgain],
      ),
      (name: 'LOCKED', status: statusJson('LOCKED'), shows: [VerificationCopy.locked]),
    ];

    for (final step in _steps) {
      for (final state in states) {
        testWidgets('${step.state}, ${state.name}: the wall replaces "${step.action}"',
            (tester) async {
          await _pumpDetail(tester, wallApi(date: wallDateJson(step.state), status: state.status));

          expect(_wall, findsOneWidget);
          for (final text in state.shows) {
            expect(find.text(text), findsOneWidget);
          }
          expect(_action(step), findsNothing);
          // Buttons only where there's something to start.
          final buttons = state.name == 'NOT_VERIFIED' || state.name == 'RETRY' ? 1 : 0;
          final wallButtons = find.descendant(
            of: find.byType(DateVerificationWall),
            matching: find.byType(ElevatedButton),
          );
          expect(wallButtons, findsNWidgets(buttons));
          // The partner header and the rest of the screen still show.
          expect(find.text('Sam'), findsOneWidget);
          expect(find.byIcon(Icons.more_vert), findsOneWidget);
        });
      }
    }

    testWidgets('shows the deposit deadline', (tester) async {
      const deadline = '2026-11-20T18:00:00Z';
      await _pumpDetail(
        tester,
        wallApi(date: wallDateJson('AWAITING_DEPOSIT', depositDeadline: deadline)),
      );

      final by = DateFormats.formatDateTime(DateTime.parse(deadline));
      expect(find.text(VerificationCopy.keepYourDate(by)), findsOneWidget);
    });

    testWidgets('shows the ranking deadline', (tester) async {
      const deadline = '2026-11-21T09:30:00Z';
      await _pumpDetail(
        tester,
        wallApi(date: wallDateJson('AWAITING_VENUE_RANKING', rankingDeadline: deadline)),
      );

      final by = DateFormats.formatDateTime(DateTime.parse(deadline));
      expect(find.text(VerificationCopy.keepYourDate(by)), findsOneWidget);
    });

    testWidgets('a step with no deadline shows none', (tester) async {
      await _pumpDetail(tester, wallApi(date: wallDateJson('AWAITING_AVAILABILITY')));

      expect(find.textContaining('Do this by'), findsNothing);
    });

    testWidgets('waiting on the partner shows the usual line, not the wall', (tester) async {
      final date = wallDateJson('AWAITING_DEPOSIT')
        ..['depositStatus'] = {'user1': 'PAID', 'user2': 'PENDING'};
      await _pumpDetail(tester, wallApi(date: date));

      expect(_wall, findsNothing);
      expect(find.text('You\'ve committed. Waiting for Sam.'), findsOneWidget);
    });

    testWidgets('never shows anything about the partner\'s verification', (tester) async {
      await _pumpDetail(tester, wallApi(date: wallDateJson('AWAITING_AVAILABILITY')));

      expect(find.textContaining('Sam is'), findsNothing);
      expect(find.textContaining('verified'), findsNothing);
    });
  });

  group('cancel and report behind the wall', () {
    testWidgets('both stay in the overflow menu', (tester) async {
      await _pumpDetail(tester, wallApi(date: wallDateJson('AWAITING_AVAILABILITY')));
      expect(_wall, findsOneWidget);

      await _openOverflow(tester);

      expect(find.text('Cancel date'), findsOneWidget);
      expect(find.text(SafetyCopy.reportAndBlock), findsOneWidget);
    });

    testWidgets('cancel opens the cancel dialog', (tester) async {
      await _pumpDetail(tester, wallApi(date: wallDateJson('AWAITING_DEPOSIT')));

      await _openOverflow(tester);
      await tester.tap(find.text('Cancel date'));
      await tester.pumpAndSettle();

      expect(find.byType(CancelDateDialog), findsOneWidget);
    });

    testWidgets('report opens the report sheet', (tester) async {
      final api = wallApi(date: wallDateJson('AWAITING_VENUE_RANKING'));
      await _pumpDetail(tester, api);

      await _openOverflow(tester);
      await tester.tap(find.text(SafetyCopy.reportAndBlock));
      await tester.pumpAndSettle();

      expect(find.text(SafetyCopy.sheetIntro('Sam', dateFinished: false)), findsOneWidget);
      expect(count(api, 'GET /safety/reasons'), 1);
    });
  });

  group('verificationRequired false or absent', () {
    for (final step in _steps) {
      for (final value in [false, null]) {
        testWidgets('${step.state}, ${value ?? 'absent'}: "${step.action}" as before',
            (tester) async {
          final api = wallApi(date: wallDateJson(step.state, verificationRequired: value));
          await _pumpDetail(tester, api);

          expect(_action(step), findsOneWidget);
          expect(find.byType(DateVerificationWall), findsNothing);
          expect(_wall, findsNothing);
          // The status isn't even fetched.
          expect(count(api, statusRequest), 0);
        });
      }
    }

    test('parses as false when absent, on the detail and the list', () {
      final detail = wallDateJson('AWAITING_DEPOSIT', verificationRequired: null);
      expect(DateDetail.fromJson(detail).verificationRequired, isFalse);

      final summary = {
        'dateId': 7,
        'matchId': 1007,
        'partnerId': 'user2',
        'partnerName': 'Sam',
        'state': 'AWAITING_DEPOSIT',
        'createdAt': '2026-10-20T12:00:00Z',
        'activityName': 'Dinner',
      };
      expect(DateSummary.fromJson(summary).verificationRequired, isFalse);
      expect(DateSummary.fromJson({...summary, 'verificationRequired': true}).verificationRequired,
          isTrue);
    });
  });

  group('after verifying', () {
    testWidgets('the wall goes away when the status turns verified', (tester) async {
      final api = wallApi(date: wallDateJson('AWAITING_AVAILABILITY'));
      await _pumpDetail(tester, api);
      expect(_wall, findsOneWidget);
      final dateReads = count(api, dateRequest);

      // Approved: the server's next answers say so.
      api.responses[statusRequest] = statusJson('VERIFIED');
      api.responses[dateRequest] =
          wallDateJson('AWAITING_AVAILABILITY', verificationRequired: false);
      await containerOf(tester, find.byType(DateDetailScreen))
          .read(verificationStatusNotifierProvider)
          .refresh();
      await tester.pumpAndSettle();

      expect(count(api, dateRequest), dateReads + 1);
      expect(_wall, findsNothing);
      expect(_action(_steps.first), findsOneWidget);
    });

    testWidgets('the app coming back refetches the status, and the wall goes', (tester) async {
      final api = wallApi(date: wallDateJson('AWAITING_DEPOSIT'));
      await _pumpDetail(tester, api);
      final statusReads = count(api, statusRequest);

      api.responses[statusRequest] = statusJson('VERIFIED');
      api.responses[dateRequest] = wallDateJson('AWAITING_DEPOSIT', verificationRequired: false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(count(api, statusRequest), statusReads + 1);
      expect(_wall, findsNothing);
      expect(find.textContaining('Commit 5'), findsOneWidget);
    });

    testWidgets('the wall stays while the server still requires verification', (tester) async {
      final api = wallApi(date: wallDateJson('AWAITING_AVAILABILITY'));
      await _pumpDetail(tester, api);

      api.responses[statusRequest] = statusJson('VERIFIED');
      await containerOf(tester, find.byType(DateDetailScreen))
          .read(verificationStatusNotifierProvider)
          .refresh();
      await tester.pumpAndSettle();

      expect(_wall, findsOneWidget);
      expect(_action(_steps.first), findsNothing);
    });
  });

  group('entry screens opened behind the wall', () {
    testWidgets('the availability picker shows the wall, not the grid', (tester) async {
      final api = wallApi(date: wallDateJson('AWAITING_AVAILABILITY'))
        ..responses['GET /dates/7/availability'] = _availabilityJson();
      await pumpWall(tester, api, const AvailabilityPickerScreen(dateId: '7', round: 1));

      expect(_wall, findsOneWidget);
      expect(find.text(DatesCopy.availabilitySendButton), findsNothing);
      expect(find.text('Cancel this date'), findsOneWidget);
    });

    testWidgets('the venue ranking shows the wall, with its deadline', (tester) async {
      final deadline = DateTime.utc(2026, 11, 21, 9, 30);
      final api = wallApi(date: wallDateJson('AWAITING_VENUE_RANKING'));
      await pumpWall(
        tester,
        api,
        VenueRankingScreen(dateId: '7', rankingDeadline: deadline),
      );

      expect(_wall, findsOneWidget);
      expect(
        find.text(VerificationCopy.keepYourDate(DateFormats.formatDateTime(deadline))),
        findsOneWidget,
      );
      expect(find.text(DatesCopy.venueRankingSendButton), findsNothing);
      expect(find.text('Cancel this date'), findsOneWidget);
    });

    testWidgets('a ranking already sent is a read: no wall', (tester) async {
      final api = wallApi(date: wallDateJson('AWAITING_VENUE_RANKING'));
      await pumpWall(tester, api, const VenueRankingScreen(dateId: '7', readOnly: true));

      expect(_wall, findsNothing);
      expect(find.text('The Ivy'), findsOneWidget);
    });

    testWidgets('the deposit sheet shows the wall, not the commit button', (tester) async {
      final api = wallApi(date: wallDateJson('AWAITING_DEPOSIT'));
      await pumpWall(
        tester,
        api,
        Scaffold(
          body: DepositSheet(
            dateDetail: _detail('AWAITING_DEPOSIT', verificationRequired: true),
            currentUid: 'user1',
            agreedTimeRange: 'Fri 20 Nov, 19:00 - 21:00',
          ),
        ),
      );

      expect(_wall, findsOneWidget);
      expect(find.text('Commit 5.00'), findsNothing);
      expect(find.text('Cancel this date'), findsOneWidget);
    });
  });

  group('a 403 VERIFICATION_REQUIRED shows the wall, not a toast', () {
    // Each starts with the server saying nothing is required, as a build that raced the
    // state sees, and the action answering 403.

    testWidgets('from sending availability', (tester) async {
      final api = wallApi(date: wallDateJson('AWAITING_AVAILABILITY', verificationRequired: false))
        ..responses['GET /dates/7/availability'] = _availabilityJson(mySlots: _threeFreeSlots())
        ..responses['POST /dates/7/availability'] = verificationRequiredError;
      await pumpWall(tester, api, const AvailabilityPickerScreen(dateId: '7', round: 1));
      final statusReads = count(api, statusRequest);

      await tester.tap(find.text(DatesCopy.availabilitySendButton));
      await tester.pumpAndSettle();

      expect(count(api, 'POST /dates/7/availability'), 1);
      expect(_wall, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(AvailabilityPickerScreen), findsOneWidget);
      expect(count(api, statusRequest), greaterThan(statusReads));
    });

    testWidgets('from committing the deposit', (tester) async {
      final api = wallApi(date: wallDateJson('AWAITING_DEPOSIT', verificationRequired: false))
        ..responses['POST /dates/7/deposit'] = verificationRequiredError;
      await pumpWall(
        tester,
        api,
        Scaffold(
          body: DepositSheet(
            dateDetail: _detail('AWAITING_DEPOSIT'),
            currentUid: 'user1',
            agreedTimeRange: 'Fri 20 Nov, 19:00 - 21:00',
          ),
        ),
      );

      await tester.tap(find.text('Commit 5.00'));
      await tester.pumpAndSettle();

      expect(count(api, 'POST /dates/7/deposit'), 1);
      expect(_wall, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('from sending the venue ranking', (tester) async {
      final api = wallApi(date: wallDateJson('AWAITING_VENUE_RANKING', verificationRequired: false))
        ..responses['POST /dates/7/venue-rankings'] = verificationRequiredError;
      await pumpWall(tester, api, const VenueRankingScreen(dateId: '7'));

      await tester.tap(find.text(DatesCopy.venueRankingSendButton));
      await tester.pumpAndSettle();

      expect(count(api, 'POST /dates/7/venue-rankings'), 1);
      expect(_wall, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(VenueRankingScreen), findsOneWidget);
    });

    testWidgets('a failed date refetch after verifying keeps the raised wall', (tester) async {
      final api = wallApi(date: wallDateJson('AWAITING_VENUE_RANKING', verificationRequired: false))
        ..responses['POST /dates/7/venue-rankings'] = verificationRequiredError;
      await pumpWall(tester, api, const VenueRankingScreen(dateId: '7'));
      await tester.tap(find.text(DatesCopy.venueRankingSendButton));
      await tester.pumpAndSettle();
      expect(_wall, findsOneWidget);

      // Verified, but the date can't be read: the cached detail still says false.
      api.responses[statusRequest] = statusJson('VERIFIED');
      api.responses[dateRequest] = const NetworkException('offline');
      final dateReads = count(api, dateRequest);
      await containerOf(tester, find.byType(VenueRankingScreen))
          .read(verificationStatusNotifierProvider)
          .refresh();
      await tester.pumpAndSettle();

      expect(count(api, dateRequest), dateReads + 1);
      expect(_wall, findsOneWidget);
      expect(find.text(DatesCopy.venueRankingSendButton), findsNothing);
    });

    testWidgets('from confirming presence', (tester) async {
      final api = wallApi(
        date: wallDateJson('AWAITING_PRESENCE_CONFIRMATION', verificationRequired: false),
      )..responses['POST /dates/7/confirm-presence'] = verificationRequiredError;
      await pumpWall(
        tester,
        api,
        Scaffold(
          body: SingleChildScrollView(
            child: BookingCard(
              dateDetail: _detail('AWAITING_PRESENCE_CONFIRMATION'),
              currentUid: 'user1',
            ),
          ),
        ),
      );

      await tester.tap(find.text(DatesCopy.presenceButtonText));
      await tester.pumpAndSettle();

      expect(count(api, 'POST /dates/7/confirm-presence'), 1);
      expect(_wall, findsOneWidget);
      expect(find.text(DatesCopy.presenceButtonText), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('the buttons', () {
    testWidgets('Verify now and Try again both start the flow', (tester) async {
      for (final (status, label) in [
        (statusJson('NOT_VERIFIED'), VerificationCopy.verifyNow),
        (statusJson('RETRY', reason: 'POSE_MISSING'), VerificationCopy.tryAgain),
      ]) {
        await _pumpDetail(
          tester,
          wallApi(date: wallDateJson('AWAITING_AVAILABILITY'), status: status),
        );

        await tester.tap(find.text(label));
        await tester.pump();

        // TODO(VF-F2): expect the consent screen once `startVerification` is wired in.
        expect(find.text('Selfie verification is coming soon'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  group('dates list', () {
    DateSummary summary(String state, {bool verificationRequired = false}) => DateSummary(
          dateId: 7,
          matchId: 1007,
          partnerId: 'user2',
          partnerName: 'Sam',
          state: DateState.values.firstWhere((s) => s.name == state),
          createdAt: DateTime.utc(2026, 10, 20),
          activityName: 'Dinner',
          verificationRequired: verificationRequired,
        );

    Future<void> pumpCard(WidgetTester tester, DateSummary date) => tester.pumpWidget(MaterialApp(
          home: Scaffold(body: DateCard(date: date, currentUserId: 'user1', onTap: () {})),
        ));

    testWidgets('a date waiting on the viewer says "Verify to continue"', (tester) async {
      for (final state in [
        'awaitingAvailability',
        'awaitingDeposit',
        'awaitingVenueRanking',
        'awaitingPresenceConfirmation',
      ]) {
        await pumpCard(tester, summary(state, verificationRequired: true));
        expect(find.text(VerificationCopy.verifyToContinue), findsOneWidget, reason: state);
      }
    });

    testWidgets('otherwise the usual call to action', (tester) async {
      await pumpCard(tester, summary('awaitingDeposit'));
      expect(find.text('Commit with deposit'), findsOneWidget);
      expect(find.text(VerificationCopy.verifyToContinue), findsNothing);

      await pumpCard(tester, summary('booked', verificationRequired: true));
      expect(find.text(VerificationCopy.verifyToContinue), findsNothing);
    });
  });
}
