import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/time/server_clock.dart';
import 'package:eros_app/core/time/server_clock_provider.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/screens/date_detail_screen.dart';
import 'package:eros_app/features/dates/presentation/widgets/terminal_panel.dart';
import 'package:eros_app/features/safety/data/models/safety_models.dart';
import 'package:eros_app/features/safety/presentation/providers/report_provider.dart';
import 'package:eros_app/features/safety/presentation/screens/report_result_screen.dart';
import 'package:eros_app/features/safety/presentation/widgets/safety_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import '../fake_safety_api.dart';

/// When the fixture dates finished (`updatedAt`).
final _finishedAt = DateTime.utc(2026, 10, 23, 12);

const _cancelResponse = {
  'dateId': 7,
  'tier': 'POST_COMMITMENT',
  'refunds': <String, dynamic>{},
  'cancellationSource': 'USER',
  'cancelledAt': '2026-11-02T12:00:00Z',
};

void main() {
  late FakeSafetyApi api;
  late FakeImagePicker picker;

  setUp(() {
    api = FakeSafetyApi();
    picker = FakeImagePicker();
  });

  /// Tall enough that the sheet and the cancel dialog fit without scrolling.
  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget app(Widget home, {DateTime? now}) => ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(FakeAuthService()),
          apiClientProvider.overrideWithValue(api),
          evidenceImagePickerProvider.overrideWithValue(picker),
          if (now != null) serverClockProvider.overrideWithValue(ServerClock(deviceNow: () => now)),
        ],
        child: MaterialApp(home: home),
      );

  Future<void> pumpDetail(
    WidgetTester tester,
    Map<String, dynamic> date, {
    DateTime? now,
  }) async {
    tallScreen(tester);
    api.responses['GET /dates/7'] = date;
    await tester.pumpWidget(app(const DateDetailScreen(dateId: '7'), now: now));
    await tester.pumpAndSettle();
  }

  Future<void> openOverflow(WidgetTester tester, String item) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic>? lastReport() {
    final sent = api.sent('POST', '/dates/7/report');
    return sent.isEmpty ? null : sent.last as Map<String, dynamic>;
  }

  group('report sheet', () {
    testWidgets('shows the reasons from the API', (tester) async {
      api.responses['GET /safety/reasons'] = [
        {'code': 'FEELS_UNSAFE', 'label': 'I feel unsafe'},
        {'code': 'NEW_REASON', 'label': 'A reason only the server knows'},
      ];
      await pumpDetail(tester, dateDetailJson());
      await openOverflow(tester, SafetyCopy.reportAndBlock);

      expect(api.sent('GET', '/safety/reasons'), hasLength(1));
      expect(find.text('I feel unsafe'), findsOneWidget);
      expect(find.text('A reason only the server knows'), findsOneWidget);
      expect(find.text('Harassment'), findsNothing);
    });

    testWidgets('says it ends an active date', (tester) async {
      await pumpDetail(tester, dateDetailJson());
      await openOverflow(tester, SafetyCopy.reportAndBlock);

      expect(find.text(SafetyCopy.sheetIntro('Sam', dateFinished: false)), findsOneWidget);
      expect(find.textContaining('This ends your date'), findsOneWidget);
    });

    testWidgets('does not say it ends a finished date', (tester) async {
      await pumpDetail(
        tester,
        dateDetailJson(state: 'COMPLETED', cancellable: false),
        now: _finishedAt.add(const Duration(days: 1)),
      );
      await tester.tap(find.text(SafetyCopy.report));
      await tester.pumpAndSettle();

      expect(find.text(SafetyCopy.sheetIntro('Sam', dateFinished: true)), findsOneWidget);
      expect(find.textContaining('This ends your date'), findsNothing);
    });

    testWidgets('asks for confirmation, then sends origin REPORT and shows the result',
        (tester) async {
      await pumpDetail(tester, dateDetailJson());
      await openOverflow(tester, SafetyCopy.reportAndBlock);

      await tester.tap(find.text('Harassment'));
      await tester.enterText(find.byType(TextField), 'They kept messaging');
      await tester.tap(find.text(SafetyCopy.reviewButton));
      await tester.pumpAndSettle();

      // Nothing is sent until the confirmation.
      expect(find.text(SafetyCopy.confirmTitle), findsOneWidget);
      expect(lastReport(), isNull);

      await tester.tap(find.text(SafetyCopy.confirmButton));
      await tester.pumpAndSettle();

      expect(lastReport(), {
        'origin': 'REPORT',
        'reason': 'HARASSMENT',
        'description': 'They kept messaging',
        'evidenceIds': <String>[],
      });
      expect(find.byType(ReportResultScreen), findsOneWidget);
      expect(find.text('We\'ve refunded your deposit.'), findsOneWidget);
      expect(find.text('If you\'re in danger, call 999.'), findsOneWidget);
      // Date detail was fetched again.
      expect(api.sent('GET', '/dates/7'), hasLength(2));
    });

    testWidgets('needs a reason before confirming', (tester) async {
      await pumpDetail(tester, dateDetailJson());
      await openOverflow(tester, SafetyCopy.reportAndBlock);

      await tester.tap(find.text(SafetyCopy.reviewButton));
      await tester.pumpAndSettle();

      expect(find.text(SafetyCopy.chooseReason), findsOneWidget);
      expect(find.text(SafetyCopy.confirmTitle), findsNothing);
    });

    testWidgets('a failed image upload keeps the description and still sends the report',
        (tester) async {
      api.failUploads = true;
      picker.next = XFile.fromData(pngBytes, path: 'evidence.png', mimeType: 'image/png');
      await pumpDetail(tester, dateDetailJson());
      await openOverflow(tester, SafetyCopy.reportAndBlock);

      await tester.tap(find.text('Harassment'));
      await tester.enterText(find.byType(TextField), 'They kept messaging');
      await tester.tap(find.bySemanticsLabel(SafetyCopy.addImage));
      await tester.pumpAndSettle();

      expect(find.text(SafetyCopy.imageFailed), findsOneWidget);
      expect(find.text('They kept messaging'), findsOneWidget);

      await tester.tap(find.text(SafetyCopy.reviewButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(SafetyCopy.confirmButton));
      await tester.pumpAndSettle();

      expect(lastReport()!['description'], 'They kept messaging');
      expect(lastReport()!['evidenceIds'], isEmpty);
      expect(find.byType(ReportResultScreen), findsOneWidget);
    });

    testWidgets('a failed image can be removed', (tester) async {
      api.failUploads = true;
      picker.next = XFile.fromData(pngBytes, path: 'evidence.png', mimeType: 'image/png');
      await pumpDetail(tester, dateDetailJson());
      await openOverflow(tester, SafetyCopy.reportAndBlock);

      await tester.tap(find.bySemanticsLabel(SafetyCopy.addImage));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(SafetyCopy.removeImage));
      await tester.pumpAndSettle();

      expect(find.text(SafetyCopy.imageFailed), findsNothing);
      expect(find.byTooltip(SafetyCopy.removeImage), findsNothing);
    });

    testWidgets('a 409 says the date was already reported', (tester) async {
      api.responses['POST /dates/7/report'] = const ConflictException('Already reported');
      await pumpDetail(tester, dateDetailJson());
      await openOverflow(tester, SafetyCopy.reportAndBlock);

      await tester.tap(find.text('Something else'));
      await tester.tap(find.text(SafetyCopy.reviewButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(SafetyCopy.confirmButton));
      await tester.pumpAndSettle();

      expect(find.text(SafetyCopy.alreadyReported), findsOneWidget);
      expect(find.byType(ReportResultScreen), findsNothing);
    });
  });

  group('result screen', () {
    Future<void> pumpResult(WidgetTester tester, RefundOutcome refund, String city) async {
      await tester.pumpWidget(MaterialApp(
        home: ReportResultScreen(
          result: ReportResult(reportId: 7, dateEnded: true, yourRefund: refund),
          cityName: city,
        ),
      ));
    }

    testWidgets('REFUNDED says the deposit is refunded', (tester) async {
      await pumpResult(tester, RefundOutcome.refunded, 'London');

      expect(find.text('We\'ve refunded your deposit.'), findsOneWidget);
      expect(find.textContaining('let you know about your deposit'), findsNothing);
    });

    testWidgets('UNDER_REVIEW says we will review the deposit', (tester) async {
      await pumpResult(tester, RefundOutcome.underReview, 'London');

      expect(find.text('We\'ll review this and let you know about your deposit.'), findsOneWidget);
      expect(find.text('We\'ve refunded your deposit.'), findsNothing);
    });

    testWidgets('NONE has no deposit line', (tester) async {
      await pumpResult(tester, RefundOutcome.none, 'London');

      expect(find.textContaining('deposit'), findsNothing);
    });

    testWidgets('gives 999 in the UK and 911 in the US', (tester) async {
      await pumpResult(tester, RefundOutcome.none, 'London');
      expect(find.text('If you\'re in danger, call 999.'), findsOneWidget);

      await pumpResult(tester, RefundOutcome.none, 'Houston');
      expect(find.text('If you\'re in danger, call 911.'), findsOneWidget);

      await pumpResult(tester, RefundOutcome.none, 'Paris');
      expect(find.text('If you\'re in danger, call your local emergency number.'), findsOneWidget);
    });
  });

  group('terminal panel', () {
    Future<void> pumpPanel(
      WidgetTester tester, {
      DateState state = DateState.completed,
      required DateTime now,
      bool underReview = false,
      VoidCallback? onReport,
    }) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          serverClockProvider.overrideWithValue(ServerClock(deviceNow: () => now)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TerminalPanel(
              state: state,
              finishedAt: _finishedAt,
              refundUnderReview: underReview,
              onReport: onReport ?? () {},
            ),
          ),
        ),
      ));
    }

    testWidgets('shows Report inside 30 days, by the server clock', (tester) async {
      await pumpPanel(tester, now: _finishedAt.add(const Duration(days: 29, hours: 23)));
      expect(find.text(SafetyCopy.report), findsOneWidget);
    });

    testWidgets('hides Report after 30 days', (tester) async {
      await pumpPanel(tester, now: _finishedAt.add(const Duration(days: 30, minutes: 1)));
      expect(find.text(SafetyCopy.report), findsNothing);
    });

    testWidgets('Report opens the sheet from date detail', (tester) async {
      await pumpDetail(
        tester,
        dateDetailJson(state: 'CANCELLED', cancellable: false),
        now: _finishedAt.add(const Duration(days: 2)),
      );
      await tester.tap(find.text(SafetyCopy.report));
      await tester.pumpAndSettle();

      expect(find.text(SafetyCopy.reasonHeading), findsOneWidget);
    });

    testWidgets('shows the held-deposit copy only when the refund is under review',
        (tester) async {
      final now = _finishedAt.add(const Duration(days: 1));

      await pumpPanel(tester, state: DateState.cancelled, now: now, underReview: true);
      expect(find.text(SafetyCopy.depositOnHold), findsOneWidget);
      expect(find.textContaining('check your wallet'), findsNothing);

      await pumpPanel(tester, state: DateState.cancelled, now: now);
      expect(find.text(SafetyCopy.depositOnHold), findsNothing);
      expect(find.textContaining('check your wallet'), findsOneWidget);
    });

    testWidgets('date detail passes yourRefundUnderReview through', (tester) async {
      await pumpDetail(
        tester,
        dateDetailJson(state: 'CANCELLED', cancellable: false, yourRefundUnderReview: true),
        now: _finishedAt.add(const Duration(days: 1)),
      );

      expect(find.text(SafetyCopy.depositOnHold), findsOneWidget);
    });
  });

  group('date detail overflow menu', () {
    testWidgets('offers Report and block even when the date cannot be cancelled',
        (tester) async {
      await pumpDetail(tester, dateDetailJson(cancellable: false));
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text(SafetyCopy.reportAndBlock), findsOneWidget);
      expect(find.text('Cancel date'), findsNothing);
    });

    testWidgets('has no menu on a finished date', (tester) async {
      await pumpDetail(
        tester,
        dateDetailJson(state: 'COMPLETED', cancellable: false),
        now: _finishedAt.add(const Duration(days: 1)),
      );

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });
  });

  group('cancel dialog', () {
    testWidgets('a plain cancel sends what it did before', (tester) async {
      api.responses['POST /dates/7/cancel'] = _cancelResponse;
      await pumpDetail(tester, dateDetailJson());
      await openOverflow(tester, 'Cancel date');

      expect(find.text(SafetyCopy.cancelSomethingCameUp), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Work trip');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel date'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', '/dates/7/cancel').single, {'reason': 'Work trip'});
      expect(lastReport(), isNull);
      expect(api.sent('GET', '/safety/reasons'), isEmpty);
    });

    testWidgets('"I don\'t feel safe" sends origin CANCEL and shows the result',
        (tester) async {
      await pumpDetail(tester, dateDetailJson());
      await openOverflow(tester, 'Cancel date');

      await tester.tap(find.text(SafetyCopy.cancelNotSafe));
      await tester.pumpAndSettle();

      expect(find.text(SafetyCopy.cancelSafetyBody), findsOneWidget);
      expect(find.text('Add a note (optional)'), findsNothing);
      expect(find.text(SafetyCopy.descriptionHint), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel date'));
      await tester.pumpAndSettle();

      expect(lastReport(), {
        'origin': 'CANCEL',
        'reason': 'FEELS_UNSAFE', // preselected
        'evidenceIds': <String>[],
      });
      expect(api.sent('POST', '/dates/7/cancel'), isEmpty);
      expect(find.byType(ReportResultScreen), findsOneWidget);
    });
  });
}
