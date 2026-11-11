import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/time/server_clock.dart';
import 'package:eros_app/core/time/server_clock_provider.dart';
import 'package:eros_app/features/chat/data/models/chat_models.dart';
import 'package:eros_app/features/chat/presentation/providers/chat_repository_provider.dart';
import 'package:eros_app/features/chat/presentation/providers/chat_screen_providers.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/data/repositories/dates_repository.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_repository_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/safety/data/repositories/safety_repository.dart';
import 'package:eros_app/features/safety/presentation/providers/report_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../safety/fake_safety_api.dart' as safety;
import 'fake_chat_repository.dart';

class _FakeUser implements User {
  @override
  String get uid => 'me';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthService implements AuthService {
  @override
  User? get currentUser => _FakeUser();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDatesRepository implements DatesRepository {
  FakeDatesRepository(this.date);

  DateDetail date;

  @override
  Future<DateDetail?> getDateById(String dateId) async => date;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DateDetail chatDate({
  DateState state = DateState.ready,
  ChatStatus chat = ChatStatus.open,
  bool verificationRequired = false,
}) =>
    DateDetail(
      dateId: 42,
      matchId: 1042,
      user1Id: 'me',
      user2Id: 'alex',
      partnerName: 'Alex',
      activityId: 2,
      activityName: 'Drinks',
      durationMinutes: 120,
      tokenCost: '5.00',
      cityId: 1,
      cityName: 'London',
      state: state,
      availabilityRound: 1,
      scheduledStart: DateTime.utc(2026, 11, 7, 19),
      scheduledEnd: DateTime.utc(2026, 11, 7, 21),
      venueName: 'The Fox',
      depositStatus: const DepositStatus(
        user1: ParticipantDepositStatus.paid,
        user2: ParticipantDepositStatus.paid,
      ),
      cancellable: false,
      timeline: const [],
      chat: ChatSummary(status: chat, closesAt: DateTime.utc(2026, 11, 7, 21)),
      createdAt: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 11, 6),
      verificationRequired: verificationRequired,
    );

/// Overrides for a chat screen or date detail test.
Future<List<Override>> chatOverrides({
  required FakeChatRepository chat,
  required DateDetail date,
  bool notificationsEnabled = true,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPreferences = await SharedPreferences.getInstance();
  return [
    authServiceProvider.overrideWithValue(FakeAuthService()),
    chatRepositoryProvider.overrideWithValue(chat),
    safetyRepositoryProvider.overrideWithValue(SafetyRepository(safety.FakeSafetyApi())),
    datesRepositoryProvider.overrideWithValue(FakeDatesRepository(date)),
    sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    chatNotificationsEnabledProvider.overrideWith((ref) async => notificationsEnabled),
    serverClockProvider.overrideWithValue(ServerClock(deviceNow: () => DateTime.utc(2026, 11, 7, 19))),
  ];
}
