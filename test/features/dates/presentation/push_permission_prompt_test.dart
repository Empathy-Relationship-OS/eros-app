import 'package:eros_app/core/notifications/messaging_client.dart';
import 'package:eros_app/core/notifications/push_prompt_store.dart';
import 'package:eros_app/core/notifications/push_service.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/data/repositories/dates_repository.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_repository_provider.dart';
import 'package:eros_app/features/dates/presentation/widgets/booking_card.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';
import 'package:eros_app/features/dates/presentation/widgets/push_permission_prompt.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/notifications/fake_messaging.dart';

class _FakeDatesRepository implements DatesRepository {
  int confirmCalls = 0;

  PresenceConfirmationStatus _status({required bool meConfirmed}) => PresenceConfirmationStatus(
        dateId: 7,
        user1: ParticipantPresence(userId: 'user1', confirmed: meConfirmed),
        user2: const ParticipantPresence(userId: 'user2', confirmed: false),
      );

  @override
  Future<PresenceConfirmationStatus> getPresenceStatus(String dateId) async =>
      _status(meConfirmed: false);

  @override
  Future<PresenceConfirmationStatus> confirmPresence(String dateId) async {
    confirmCalls++;
    return _status(meConfirmed: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DateDetail _date() => DateDetail(
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
      state: DateState.awaitingPresenceConfirmation,
      availabilityRound: 1,
      venueName: 'The Ivy',
      venueAddress: '1 West St',
      depositStatus: const DepositStatus(
        user1: ParticipantDepositStatus.paid,
        user2: ParticipantDepositStatus.paid,
      ),
      cancellable: false,
      timeline: const [],
      createdAt: DateTime.utc(2026, 10, 23),
      updatedAt: DateTime.utc(2026, 10, 23),
    );

const _promptText = "Turn on notifications so you don't miss Sam's messages.";

void main() {
  late SharedPreferences prefs;
  late FakeMessagingClient messaging;
  late _FakeDatesRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    messaging = FakeMessagingClient();
    repository = _FakeDatesRepository();
  });

  Future<void> pumpCard(WidgetTester tester, {String uid = 'user1'}) async {
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        datesRepositoryProvider.overrideWithValue(repository),
        pushServiceProvider.overrideWith(
          (ref) => PushService(messaging: messaging, apiClient: () => FakeDevicesApi(), platform: 'IOS'),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: BookingCard(dateDetail: _date(), currentUid: uid)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.text(DatesCopy.presenceButtonText));
    await tester.pumpAndSettle();
  }

  test('the copy has the partner\'s name and no em dash', () {
    expect(DatesCopy.pushPromptBody('Sam'), _promptText);
    expect(DatesCopy.pushPromptBody('Sam'), isNot(contains('—')));
  });

  testWidgets('never shows before the user confirms', (tester) async {
    await pumpCard(tester);

    expect(find.text(_promptText), findsNothing);
  });

  testWidgets('after a successful confirm, asks; the button requests permission', (tester) async {
    await pumpCard(tester);
    await confirm(tester);

    expect(repository.confirmCalls, 1);
    expect(find.text(_promptText), findsOneWidget);

    await tester.tap(find.text(DatesCopy.pushPromptTurnOn));
    await tester.pumpAndSettle();

    expect(messaging.requestPermissionCalls, 1);
    expect(find.text(_promptText), findsNothing);
  });

  testWidgets('"Not now" closes it without asking the OS', (tester) async {
    await pumpCard(tester);
    await confirm(tester);

    await tester.tap(find.text(DatesCopy.pushPromptLater));
    await tester.pumpAndSettle();

    expect(messaging.requestPermissionCalls, 0);
    expect(find.text(_promptText), findsNothing);
  });

  testWidgets('shows once per user', (tester) async {
    await pumpCard(tester);
    await confirm(tester);
    await tester.tap(find.text(DatesCopy.pushPromptLater));
    await tester.pumpAndSettle();
    expect(prefs.getBool(PushPromptStore.shownKey('user1')), isTrue);

    // The same user confirms another date.
    await pumpCard(tester);
    await confirm(tester);
    expect(find.text(_promptText), findsNothing);

    // Another account on the same phone still gets asked.
    await pumpCard(tester, uid: 'user2');
    await confirm(tester);
    expect(find.text(_promptText), findsOneWidget);
  });

  testWidgets('if notifications are already on, it is not shown, and not again', (tester) async {
    messaging.permission = PushPermission.granted;
    await pumpCard(tester);
    await confirm(tester);

    expect(find.text(_promptText), findsNothing);
    expect(prefs.getBool(PushPromptStore.shownKey('user1')), isTrue);
  });

  testWidgets('maybeShowPushPermissionPrompt shows the sheet with the name', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        pushServiceProvider.overrideWith(
          (ref) => PushService(messaging: messaging, apiClient: () => FakeDevicesApi(), platform: 'IOS'),
        ),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => maybeShowPushPermissionPrompt(context, ref, uid: 'u', partnerName: 'Alex'),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text("Turn on notifications so you don't miss Alex's messages."), findsOneWidget);
  });
}
