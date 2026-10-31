import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/time/server_clock.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/data/repositories/dates_repository.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_repository_provider.dart';
import 'package:eros_app/features/dates/presentation/screens/availability_picker_screen.dart';
import 'package:eros_app/features/dates/presentation/screens/date_detail_screen.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

const _closedReason = 'Not enough places for Dinner are open at this time';
const _otherDateReason = 'You have a date scheduled from 19:00 to 21:00';
const _newCodeReason = 'Blocked for a reason this build has never heard of';
const _submitError = 'Slot 2026-11-20T19:00:00Z can\'t be chosen. $_closedReason.';

class _FakeUser implements User {
  @override
  String get uid => 'user1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthService implements AuthService {
  @override
  User? get currentUser => _FakeUser();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Each availability read takes the next view, and the last one repeats.
class _FakeDatesRepository implements DatesRepository {
  _FakeDatesRepository(this.views, {this.date});

  final List<AvailabilityView> views;
  DateDetail? date;

  /// Thrown by the next submit. [dateAfterSubmitError] then replaces [date].
  ApiException? submitError;
  DateDetail? dateAfterSubmitError;

  int availabilityReads = 0;
  int listReads = 0;
  final List<SubmitAvailabilityRequest> submissions = [];

  @override
  Future<AvailabilityView> getAvailability(String dateId) async {
    final view = views[availabilityReads.clamp(0, views.length - 1)];
    availabilityReads++;
    return view;
  }

  @override
  Future<AvailabilityView> submitAvailability(
    String dateId,
    SubmitAvailabilityRequest request,
  ) async {
    submissions.add(request);
    final error = submitError;
    if (error != null) {
      date = dateAfterSubmitError ?? date;
      throw error;
    }
    return views.last;
  }

  @override
  Future<DateDetail?> getDateById(String dateId) async => date;

  @override
  Future<List<DateSummary>> fetchDates({DateListFilter? filter}) async {
    listReads++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Far enough ahead that the 48-hour limit can't remove any of its slots.
DateTime _testDay() {
  final local = ServerClock.instance.now().toLocal().add(const Duration(days: 4));
  return DateTime(local.year, local.month, local.day);
}

/// The same instant the picker builds for [hour]:[minute] on [day].
DateTime _slot(DateTime day, int hour, [int minute = 0]) =>
    day.toUtc().add(Duration(hours: hour, minutes: minute));

/// Every slot the picker offers on [day], earlier ones included.
List<DateTime> _wholeDay(DateTime day) => [
      for (var hour = 9; hour <= 22; hour++)
        for (final minute in [0, 30])
          if (!(hour == 22 && minute == 30)) _slot(day, hour, minute),
    ];

String _label(DateTime slot) => DateFormat('HH:mm').format(slot.toLocal());

Map<String, dynamic> _blocked(DateTime slot, String code, String reason) => {
      'slotStart': slot.toIso8601String(),
      'code': code,
      'reason': reason,
    };

Map<String, dynamic> _closed(DateTime slot) => _blocked(slot, 'ACTIVITY_CLOSED', _closedReason);

Map<String, dynamic> _otherDate(DateTime slot) => _blocked(slot, 'ANOTHER_DATE', _otherDateReason);

AvailabilityView _view({
  String activityName = 'Dinner',
  int durationMinutes = 120,
  List<Map<String, dynamic>> blockedSlots = const [],
  List<Map<String, dynamic>> mySlots = const [],
}) =>
    AvailabilityView.fromJson({
      'dateId': 7,
      'activityName': activityName,
      'durationMinutes': durationMinutes,
      'currentRound': 1,
      'mySlots': mySlots,
      'partnerSlots': <Object>[],
      'blockedSlots': blockedSlots,
    });

DateDetail _date(DateState state, {DateTime? scheduledStart, DateTime? scheduledEnd}) => DateDetail(
      dateId: 7,
      matchId: 1007,
      user1Id: 'user1',
      user2Id: 'user2',
      partnerName: 'Sam',
      activityId: 1,
      activityName: 'Dinner',
      durationMinutes: 120,
      tokenCost: '1.00',
      cityId: 1,
      cityName: 'London',
      state: state,
      availabilityRound: 1,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      depositStatus: const DepositStatus(
        user1: ParticipantDepositStatus.pending,
        user2: ParticipantDepositStatus.pending,
      ),
      cancellable: true,
      timeline: const [],
      createdAt: DateTime.utc(2026, 10, 23),
      updatedAt: DateTime.utc(2026, 10, 23),
    );

void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Pumps the picker over a home route, so leaving it is visible, on the date [_testDay].
Future<void> _pumpPicker(WidgetTester tester, _FakeDatesRepository repository) async {
  _useTallScreen(tester);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(_FakeAuthService()),
      datesRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AvailabilityPickerScreen(dateId: '7', round: 1),
            )),
            child: const Text('Open picker'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Open picker'));
  await tester.pumpAndSettle();
  await _selectDay(tester, _testDay());
}

Future<void> _selectDay(WidgetTester tester, DateTime day) async {
  await tester.tap(find.text('${day.day}'));
  await tester.pumpAndSettle();
}

Future<void> _mark(WidgetTester tester, Iterable<DateTime> slots) async {
  for (final slot in slots) {
    await tester.tap(find.text(_label(slot)));
    await tester.pump();
  }
}

Future<void> _send(WidgetTester tester) async {
  await tester.tap(find.text(DatesCopy.availabilitySendButton));
  await tester.pumpAndSettle();
}

/// The row around the time label of [slot].
BoxDecoration _rowDecoration(WidgetTester tester, DateTime slot) {
  final row = tester.widget<Container>(
    find
        .ancestor(of: find.text(_label(slot)), matching: find.byType(Container))
        .first,
  );
  return row.decoration! as BoxDecoration;
}

Finder _pickedCount(int count) => find.text(DatesCopy.availabilityCounter(count, 3));

void main() {
  final day = _testDay();
  final closed = _slot(day, 15);
  final otherDate = _slot(day, 15, 30);
  final newCode = _slot(day, 16);
  final open = _slot(day, 16, 30);

  AvailabilityView bothCodes() => _view(blockedSlots: [
        _closed(closed),
        _otherDate(otherDate),
        _blocked(newCode, 'SOME_NEW_CODE', _newCodeReason),
      ]);

  group('blocked slots', () {
    testWidgets('neither code, nor an unknown one, can be selected', (tester) async {
      await _pumpPicker(tester, _FakeDatesRepository([bothCodes()]));

      await _mark(tester, [closed, otherDate, newCode]);
      expect(_pickedCount(0), findsOneWidget);

      await _mark(tester, [open]);
      expect(_pickedCount(1), findsOneWidget);
    });

    for (final (name, slot, reason) in [
      ('ACTIVITY_CLOSED', closed, _closedReason),
      ('ANOTHER_DATE', otherDate, _otherDateReason),
      ('an unknown code', newCode, _newCodeReason),
    ]) {
      testWidgets('tapping $name shows the server\'s reason as sent', (tester) async {
        await _pumpPicker(tester, _FakeDatesRepository([bothCodes()]));
        expect(find.text(reason), findsNothing);

        await tester.tap(find.text(_label(slot)));
        await tester.pump();

        expect(find.text(reason), findsOneWidget);
      });
    }

    testWidgets('tapping a second blocked slot replaces the first reason', (tester) async {
      await _pumpPicker(tester, _FakeDatesRepository([bothCodes()]));

      await tester.tap(find.text(_label(closed)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_label(otherDate)));
      await tester.pumpAndSettle();

      expect(find.text(_closedReason), findsNothing);
      expect(find.text(_otherDateReason), findsOneWidget);
    });

    testWidgets('ACTIVITY_CLOSED is lighter than ANOTHER_DATE', (tester) async {
      await _pumpPicker(tester, _FakeDatesRepository([bothCodes()]));

      final closedRow = _rowDecoration(tester, closed);
      expect(closedRow.border, isNull);
      expect(closedRow.color, Colors.transparent);

      final otherDateRow = _rowDecoration(tester, otherDate);
      expect(otherDateRow.border, isNotNull);
      expect(otherDateRow.color, const Color(0xFFF5F5F5));
    });

    testWidgets('an unknown code looks like ANOTHER_DATE', (tester) async {
      await _pumpPicker(tester, _FakeDatesRepository([bothCodes()]));

      expect(_rowDecoration(tester, newCode).border, isNotNull);
    });

    testWidgets('long-press fill skips blocked slots', (tester) async {
      final repository = _FakeDatesRepository([bothCodes()]);
      await _pumpPicker(tester, repository);

      // From 14:30 the fill crosses all three blocked slots; 12 of the 15 slots to 22:00 are left
      await tester.tap(find.text('Earlier'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text(_label(_slot(day, 14, 30))));
      await tester.pump();

      expect(find.text('Filled 13 slots'), findsOneWidget);
      expect(_pickedCount(13), findsOneWidget);

      await _send(tester);

      final sent = repository.submissions.single.slots.map((s) => s.slotStart).toSet();
      expect(sent, isNot(contains(closed)));
      expect(sent, isNot(contains(otherDate)));
      expect(sent, isNot(contains(newCode)));
    });

    testWidgets('a saved slot that is now blocked is not counted, and is cleared on send',
        (tester) async {
      final view = _view(
        blockedSlots: [_closed(closed)],
        mySlots: [
          {'slotStart': closed.toIso8601String(), 'availability': 'AVAILABLE'},
          {'slotStart': open.toIso8601String(), 'availability': 'AVAILABLE'},
        ],
      );
      final repository = _FakeDatesRepository([view]);
      await _pumpPicker(tester, repository);

      expect(_pickedCount(1), findsOneWidget);

      await _mark(tester, [_slot(day, 17), _slot(day, 17, 30)]);
      await _send(tester);

      final sent = repository.submissions.single.slots;
      expect(
        sent.singleWhere((s) => s.slotStart == closed).availability,
        SlotAvailability.noPreference,
      );
    });
  });

  group('a closed day', () {
    testWidgets('collapses to one line when every slot is ACTIVITY_CLOSED', (tester) async {
      final view = _view(blockedSlots: _wholeDay(day).map(_closed).toList());
      await _pumpPicker(tester, _FakeDatesRepository([view]));

      expect(find.text('No Dinner places open this day'), findsOneWidget);
      expect(find.text(_label(closed)), findsNothing);
      expect(find.text('Earlier'), findsNothing);
    });

    testWidgets('does not collapse while a hidden earlier slot is open', (tester) async {
      final allButMorning = _wholeDay(day).where((s) => s != _slot(day, 10));
      final view = _view(blockedSlots: allButMorning.map(_closed).toList());
      await _pumpPicker(tester, _FakeDatesRepository([view]));

      expect(find.text('No Dinner places open this day'), findsNothing);

      await tester.tap(find.text('Earlier'));
      await tester.pumpAndSettle();
      await _mark(tester, [_slot(day, 10)]);

      expect(_pickedCount(1), findsOneWidget);
    });

    testWidgets('does not collapse when another date blocks one of its slots', (tester) async {
      final blocked = _wholeDay(day).map((s) => s == closed ? _otherDate(s) : _closed(s));
      await _pumpPicker(tester, _FakeDatesRepository([_view(blockedSlots: blocked.toList())]));

      expect(find.text('No Dinner places open this day'), findsNothing);
      expect(find.text(_label(closed)), findsOneWidget);
    });

    testWidgets('an unknown code on one slot keeps the day visible', (tester) async {
      final blocked = _wholeDay(day).map(
        (s) => s == closed ? _blocked(s, 'SOME_NEW_CODE', _newCodeReason) : _closed(s),
      );
      await _pumpPicker(tester, _FakeDatesRepository([_view(blockedSlots: blocked.toList())]));

      expect(find.text('No Dinner places open this day'), findsNothing);
    });

    testWidgets('only applies to that day', (tester) async {
      final view = _view(blockedSlots: _wholeDay(day).map(_closed).toList());
      await _pumpPicker(tester, _FakeDatesRepository([view]));

      final nextDay = DateTime(day.year, day.month, day.day + 1);
      await _selectDay(tester, nextDay);

      expect(find.text('No Dinner places open this day'), findsNothing);
      expect(find.text(_label(_slot(nextDay, 15))), findsOneWidget);
    });

    testWidgets('a day with no slots at all is not called closed', (tester) async {
      // Puts the 48-hour limit at 23:00, after the last slot of the first day
      final localNow = DateTime.now();
      final limit = DateTime(localNow.year, localNow.month, localNow.day, 23);
      final serverNow = limit.subtract(const Duration(hours: 48)).toUtc();
      void setServerTime(DateTime time) => ServerClock.instance.updateFromHeaders(
            serverTime: time.toIso8601String(),
            offsetSeconds: null,
            receivedAt: DateTime.now().toUtc(),
          );
      setServerTime(serverNow);
      addTearDown(() => setServerTime(DateTime.now().toUtc()));

      _useTallScreen(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          datesRepositoryProvider.overrideWithValue(_FakeDatesRepository([_view()])),
        ],
        child: const MaterialApp(home: AvailabilityPickerScreen(dateId: '7', round: 1)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Earlier'), findsOneWidget);
      expect(find.text('No Dinner places open this day'), findsNothing);
    });
  });

  group('the header', () {
    testWidgets('shows the activity and length', (tester) async {
      await _pumpPicker(tester, _FakeDatesRepository([_view()]));

      expect(find.text('Dinner, about 2 hours'), findsOneWidget);
    });

    testWidgets('shows a 90-minute date in minutes', (tester) async {
      final view = _view(activityName: 'Coffee', durationMinutes: 90);
      await _pumpPicker(tester, _FakeDatesRepository([view]));

      expect(find.text('Coffee, about 90 minutes'), findsOneWidget);
    });
  });

  group('a 400 from POST', () {
    testWidgets('refreshes the grid, shows the message and stays', (tester) async {
      final slots = [_slot(day, 17), _slot(day, 17, 30), _slot(day, 18)];
      final repository = _FakeDatesRepository([
        _view(),
        _view(blockedSlots: [_closed(slots.first)]),
      ])
        ..submitError = const ValidationException(_submitError, statusCode: 400);
      await _pumpPicker(tester, repository);
      await _mark(tester, slots);
      expect(_pickedCount(3), findsOneWidget);

      await _send(tester);

      expect(repository.availabilityReads, 2);
      expect(find.text(_submitError), findsOneWidget);
      expect(find.byType(AvailabilityPickerScreen), findsOneWidget);
    });

    testWidgets('drops the mark on the slot that became blocked', (tester) async {
      final slots = [_slot(day, 17), _slot(day, 17, 30), _slot(day, 18)];
      final repository = _FakeDatesRepository([
        _view(),
        _view(blockedSlots: [_closed(slots.first)]),
      ])
        ..submitError = const ValidationException(_submitError, statusCode: 400);
      await _pumpPicker(tester, repository);
      await _mark(tester, slots);

      await _send(tester);

      expect(_pickedCount(2), findsOneWidget);
      final send = tester.widget<ElevatedButton>(find.widgetWithText(
        ElevatedButton,
        DatesCopy.availabilitySendButton,
      ));
      expect(send.onPressed, isNull);
      expect(_rowDecoration(tester, slots.first).border, isNull);
    });
  });

  group('a 409 from POST', () {
    testWidgets('leaves the picker with no error, and refetches the dates list', (tester) async {
      final repository = _FakeDatesRepository([_view()])
        ..submitError = const ConflictException('Date is in EXPIRED state.', statusCode: 409);
      await _pumpPicker(tester, repository);
      await _mark(tester, [_slot(day, 17), _slot(day, 17, 30), _slot(day, 18)]);

      await _send(tester);

      expect(find.byType(AvailabilityPickerScreen), findsNothing);
      expect(find.text('Open picker'), findsOneWidget);
      expect(find.textContaining('EXPIRED'), findsNothing);
      expect(repository.listReads, isPositive);
    });

    testWidgets('lands on the existing expired panel when opened from the detail screen',
        (tester) async {
      final repository = _FakeDatesRepository(
        [_view()],
        date: _date(DateState.awaitingAvailability),
      )
        ..submitError = const ConflictException('Date is in EXPIRED state.', statusCode: 409)
        ..dateAfterSubmitError = _date(DateState.expired);
      _useTallScreen(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(_FakeAuthService()),
          datesRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: DateDetailScreen(dateId: '7')),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Pick your times'));
      await tester.pumpAndSettle();
      await _selectDay(tester, day);
      await _mark(tester, [_slot(day, 17), _slot(day, 17, 30), _slot(day, 18)]);

      await _send(tester);

      expect(find.byType(AvailabilityPickerScreen), findsNothing);
      expect(find.text('This date ran out of time'), findsOneWidget);
    });
  });
}
