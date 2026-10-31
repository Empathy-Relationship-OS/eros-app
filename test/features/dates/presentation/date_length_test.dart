import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/data/repositories/dates_repository.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_repository_provider.dart';
import 'package:eros_app/features/dates/presentation/screens/availability_picker_screen.dart';
import 'package:eros_app/features/dates/presentation/screens/date_detail_screen.dart';
import 'package:eros_app/features/dates/presentation/widgets/booking_card.dart';
import 'package:eros_app/features/dates/presentation/widgets/date_formats.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';
import 'package:eros_app/features/dates/presentation/widgets/token_amount.dart';
import 'package:eros_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

const _calendarChannel = MethodChannel('add_2_calendar');

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

class _FakeWalletBalanceNotifier extends StateNotifier<WalletBalanceState>
    implements WalletBalanceNotifier {
  _FakeWalletBalanceNotifier() : super(const WalletBalanceState());

  @override
  Future<void> fetchBalance() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDatesRepository implements DatesRepository {
  _FakeDatesRepository(this.date);

  final DateDetail date;

  @override
  Future<DateDetail?> getDateById(String dateId) async => date;

  @override
  Future<AvailabilityView> getAvailability(String dateId) async => AvailabilityView(
        dateId: 7,
        activityName: 'Coffee',
        durationMinutes: 90,
        currentRound: 1,
        mySlots: const [],
        partnerSlots: const [],
        blockedSlots: const [],
      );

  @override
  Future<AvailabilityView> submitAvailability(
    String dateId,
    SubmitAvailabilityRequest request,
  ) =>
      getAvailability(dateId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _start = DateTime.utc(2030, 3, 20, 12);
final _end = _start.add(const Duration(minutes: 90));
final _twoHourEnd = _start.add(const Duration(hours: 2));

String _time(DateTime t) => DateFormat('HH:mm').format(t.toLocal());

DateDetail _coffee(DateState state) => DateDetail(
      dateId: 7,
      matchId: 1007,
      user1Id: 'user1',
      user2Id: 'user2',
      partnerName: 'Sam',
      activityId: 2,
      activityName: 'Coffee',
      durationMinutes: 90,
      tokenCost: '0.50',
      cityId: 1,
      cityName: 'London',
      state: state,
      availabilityRound: 1,
      scheduledStart: _start,
      scheduledEnd: _end,
      depositDeadline: DateTime.utc(2030, 3, 18),
      venueName: 'Monmouth',
      venueAddress: '27 Monmouth St',
      depositStatus: const DepositStatus(
        user1: ParticipantDepositStatus.pending,
        user2: ParticipantDepositStatus.pending,
      ),
      cancellable: true,
      timeline: const [],
      createdAt: DateTime.utc(2026, 10, 23),
      updatedAt: DateTime.utc(2026, 10, 23),
    );

Future<void> _pumpCard(WidgetTester tester, DateDetail date) async {
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: BookingCard(dateDetail: date, currentUid: 'user1')),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

List<Override> _overrides(DateDetail date) => [
      authServiceProvider.overrideWithValue(_FakeAuthService()),
      datesRepositoryProvider.overrideWithValue(_FakeDatesRepository(date)),
      walletBalanceProvider.overrideWith((ref) => _FakeWalletBalanceNotifier()),
    ];

void main() {
  final realRange = '${DateFormats.formatDate(_start)}, ${_time(_start)} - ${_time(_end)}';
  final agreedRange =
      '${DateFormat('EEE d MMM, HH:mm').format(_start.toLocal())} - ${_time(_end)}';
  final twoHourRange =
      '${DateFormats.formatDate(_start)}, ${_time(_start)} - ${_time(_twoHourEnd)}';

  group('a 90-minute date', () {
    testWidgets('shows its real end time on the booking card', (tester) async {
      await _pumpCard(tester, _coffee(DateState.booked));

      expect(find.text(realRange), findsOneWidget);
      expect(find.text(twoHourRange), findsNothing);
    });

    testWidgets('shows its real end time in the confirmed caption', (tester) async {
      await _pumpCard(tester, _coffee(DateState.ready));

      expect(
        find.text(DatesCopy.bookingConfirmedCaption('Monmouth', realRange)),
        findsOneWidget,
      );
    });

    testWidgets('goes in the calendar with its real end time', (tester) async {
      Map<Object?, Object?>? event;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(_calendarChannel, (call) async {
        event = call.arguments as Map<Object?, Object?>;
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(_calendarChannel, null));
      await _pumpCard(tester, _coffee(DateState.booked));

      await tester.tap(find.text(DatesCopy.bookingAddToCalendar));
      await tester.pumpAndSettle();

      expect(event?['startDate'], _start.millisecondsSinceEpoch);
      expect(event?['endDate'], _end.millisecondsSinceEpoch);
    });

    testWidgets('shows its real end time in the deposit sheet from the detail screen',
        (tester) async {
      final date = _coffee(DateState.awaitingDeposit);
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(date),
        child: const MaterialApp(home: DateDetailScreen(dateId: '7')),
      ));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.widgetWithText(
        ElevatedButton,
        'Commit ${TokenAmount.formatTokenAmount('0.50')}',
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(agreedRange), findsOneWidget);
    });

    testWidgets('shows its real end time in the deposit sheet after the picker finds a time',
        (tester) async {
      final date = _coffee(DateState.awaitingDeposit);
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(date),
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

      final local = DateTime.now().add(const Duration(days: 4));
      final day = DateTime(local.year, local.month, local.day);
      await tester.tap(find.text('${day.day}'));
      await tester.pumpAndSettle();
      for (final hour in [16, 17, 18]) {
        final slot = day.toUtc().add(Duration(hours: hour));
        await tester.tap(find.text(_time(slot)));
        await tester.pump();
      }

      await tester.tap(find.text(DatesCopy.availabilitySendButton));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(agreedRange), findsOneWidget);
    });
  });
}
