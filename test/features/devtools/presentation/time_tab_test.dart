import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/dates/presentation/providers/date_detail_provider.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_list_provider.dart';
import 'package:eros_app/features/dates/presentation/providers/presence_provider.dart';
import 'package:eros_app/features/devtools/data/devtools_api.dart';
import 'package:eros_app/features/devtools/data/models/devtools_models.dart';
import 'package:eros_app/features/devtools/presentation/providers/devtools_providers.dart';
import 'package:eros_app/features/devtools/presentation/tabs/time_tab.dart';
import 'package:eros_app/features/devtools/presentation/time_travel.dart';
import 'package:eros_app/features/matching/presentation/providers/match_provider.dart';
import 'package:eros_app/features/wallet/presentation/providers/wallet_provider.dart';

// ClockDTO examples from RFC-003 §5.2.
final _realTime = DateTime.utc(2026, 10, 16, 12);
final _clockReal = ClockInfo(
  realTime: _realTime,
  serverTime: _realTime,
  offsetSeconds: 0,
);
final _clockShifted = ClockInfo(
  realTime: _realTime,
  serverTime: DateTime.utc(2026, 10, 17, 13),
  offsetSeconds: 90000,
);

/// Records clock calls and answers with RFC-shaped [ClockInfo]s.
class _FakeDevtoolsApi extends DevtoolsApi {
  _FakeDevtoolsApi() : super(devKey: 'test-dev-key-123456');

  final List<String> calls = [];
  final List<Map<String, int>> advances = [];
  ClockInfo clock = _clockReal;
  ApiException? advanceError;

  @override
  Future<ClockInfo> getClock() async {
    calls.add('get');
    return clock;
  }

  @override
  Future<ClockInfo> advanceClock({
    int days = 0,
    int hours = 0,
    int minutes = 0,
  }) async {
    calls.add('advance');
    advances.add({'days': days, 'hours': hours, 'minutes': minutes});
    if (advanceError != null) throw advanceError!;
    return clock = _clockShifted;
  }

  @override
  Future<ClockInfo> advanceClockTo(DateTime instant) async {
    calls.add('advance-to');
    return clock = _clockShifted;
  }

  @override
  Future<ClockInfo> resetClock() async {
    calls.add('reset');
    return clock = _clockReal;
  }
}

class _Harness {
  final _FakeDevtoolsApi api = _FakeDevtoolsApi();
  int healthBuilds = 0;

  Widget app() => ProviderScope(
    overrides: [
      devtoolsApiProvider.overrideWithValue(api),
      // devtoolsHealthProvider is in timeSensitiveProviders, so counting
      // its builds shows whether invalidateTimeSensitiveState ran.
      devtoolsHealthProvider.overrideWith((ref) async {
        healthBuilds++;
        return DevtoolsHealth(
          enabled: true,
          serverTime: api.clock.serverTime,
          offsetSeconds: api.clock.offsetSeconds,
        );
      }),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            // Keeps devtoolsHealthProvider alive, like the dev menu header.
            Consumer(
              builder: (context, ref, _) {
                ref.watch(devtoolsHealthProvider);
                return const SizedBox.shrink();
              },
            ),
            const Expanded(child: TimeTab()),
          ],
        ),
      ),
    ),
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('readout', () {
    testWidgets(
      'loads GET /dev/clock on open and shows both times and the offset',
      (tester) async {
        final h = _Harness()..api.clock = _clockShifted;
        await tester.pumpWidget(h.app());
        await tester.pumpAndSettle();

        expect(h.api.calls, ['get']);
        expect(
          tester.widget<Text>(find.byKey(const Key('timeTabServerTime'))).data,
          formatLocalTimeWithZone(_clockShifted.serverTime),
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('timeTabRealTime'))).data,
          formatLocalTimeWithZone(_realTime),
        );
        expect(find.text('+1d 1h 0m'), findsOneWidget);
        expect(
          find.text('Moves time for everyone using this backend.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows the offset as none when the clock is real', (
      tester,
    ) async {
      final h = _Harness();
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      expect(find.text('none'), findsOneWidget);
    });
  });

  group('quick buttons', () {
    testWidgets('+25h calls advance with hours: 25', (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      await _tap(tester, find.text('+25h'));

      expect(h.api.advances, [
        {'days': 0, 'hours': 25, 'minutes': 0},
      ]);
    });

    testWidgets('offers +1h, +6h, +24h, +25h and +48h', (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      for (final label in ['+1h', '+6h', '+24h', '+25h', '+48h']) {
        expect(find.widgetWithText(OutlinedButton, label), findsOneWidget);
      }
    });
  });

  group('after a clock change', () {
    testWidgets('updates the readout, invalidates time-sensitive state and '
        'shows the new server time', (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      expect(h.healthBuilds, 1);

      await _tap(tester, find.text('+25h'));

      expect(h.healthBuilds, 2);
      expect(find.text('+1d 1h 0m'), findsOneWidget);
      expect(
        find.text(
          'Server time is now ${formatLocalTimeShort(_clockShifted.serverTime)}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a failed advance shows the error and invalidates nothing', (
      tester,
    ) async {
      final h = _Harness()
        ..api.advanceError = const ValidationException(
          'total must be positive',
        );
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      await _tap(tester, find.text('+1h'));

      expect(find.text('total must be positive'), findsOneWidget);
      expect(h.healthBuilds, 1);
      expect(find.text('none'), findsOneWidget);
    });
  });

  group('custom advance', () {
    testWidgets('rejects all-zero input without calling the backend', (
      tester,
    ) async {
      final h = _Harness();
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('timeTabCustom_days')), '0');
      await tester.enterText(find.byKey(const Key('timeTabCustom_hours')), '0');
      await tester.enterText(
        find.byKey(const Key('timeTabCustom_minutes')),
        '0',
      );
      await _tap(tester, find.byKey(const Key('timeTabCustomAdvance')));

      expect(find.byKey(const Key('timeTabCustomError')), findsOneWidget);
      expect(h.api.advances, isEmpty);
    });

    testWidgets('rejects empty input', (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      await _tap(tester, find.byKey(const Key('timeTabCustomAdvance')));

      expect(find.byKey(const Key('timeTabCustomError')), findsOneWidget);
      expect(h.api.advances, isEmpty);
    });

    testWidgets('sends days, hours and minutes, treating blanks as 0', (
      tester,
    ) async {
      final h = _Harness();
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('timeTabCustom_days')), '1');
      await tester.enterText(
        find.byKey(const Key('timeTabCustom_minutes')),
        '30',
      );
      await _tap(tester, find.byKey(const Key('timeTabCustomAdvance')));

      expect(find.byKey(const Key('timeTabCustomError')), findsNothing);
      expect(h.api.advances, [
        {'days': 1, 'hours': 0, 'minutes': 30},
      ]);
      expect(h.healthBuilds, 2);
    });
  });

  group('reset', () {
    testWidgets('asks for confirmation and does nothing on cancel', (
      tester,
    ) async {
      final h = _Harness()..api.clock = _clockShifted;
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Reset clock'));

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(h.api.calls, isNot(contains('reset')));

      await _tap(tester, find.widgetWithText(TextButton, 'Cancel'));

      expect(find.byType(AlertDialog), findsNothing);
      expect(h.api.calls, isNot(contains('reset')));
      expect(h.healthBuilds, 1);
    });

    testWidgets('resets after confirming', (tester) async {
      final h = _Harness()..api.clock = _clockShifted;
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Reset clock'));
      await _tap(tester, find.widgetWithText(TextButton, 'Reset'));

      expect(h.api.calls, contains('reset'));
      expect(find.text('none'), findsOneWidget);
      expect(h.healthBuilds, 2);
    });
  });

  group('invalidateTimeSensitiveState', () {
    test('covers dates, date detail, matching, wallet and the dev header', () {
      expect(
        timeSensitiveProviders,
        containsAll(<ProviderOrFamily>[
          activeDatesProvider,
          pastDatesProvider,
          cancelledDatesProvider,
          dateDetailProvider,
          presenceProvider,
          matchBatchProvider,
          walletBalanceProvider,
          devtoolsHealthProvider,
        ]),
      );
    });
  });

  group('formatShortOffset', () {
    test('leaves out zero units', () {
      expect(formatShortOffset(const Duration(seconds: 90000)), '+1d 1h');
      expect(formatShortOffset(const Duration(hours: 6)), '+6h');
      expect(
        formatShortOffset(const Duration(hours: 1, minutes: 30)),
        '+1h 30m',
      );
      expect(formatShortOffset(const Duration(days: 2)), '+2d');
      expect(formatShortOffset(const Duration(minutes: 45)), '+45m');
      expect(formatShortOffset(const Duration(seconds: 20)), '+20s');
    });
  });
}
