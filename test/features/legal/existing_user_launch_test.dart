import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/auth/data/repositories/auth_repository.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/auth/presentation/screens/auth_loading_screen.dart';
import 'package:eros_app/features/legal/data/repositories/age_signal_repository.dart';
import 'package:eros_app/features/legal/domain/models/store_age_signal.dart';
import 'package:eros_app/features/legal/presentation/providers/age_signal_providers.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_age_signals_platform.dart';

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

class _FakeAuthRepository implements AuthRepository {
  @override
  User? get currentUser => _FakeUser();

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({required this.exists});

  final bool exists;

  @override
  Future<UserExistsResponse> checkUserExists() async =>
      UserExistsResponse(exists: exists, userId: 'user1');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingRepository implements AgeSignalRepository {
  final sent = <StoreAgeSignal>[];

  @override
  Future<bool> send(StoreAgeSignal signal) async {
    sent.add(signal);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Launches the real [AuthLoadingScreen] [launches] times on the same phone.
Future<({FixedAgeSignalService service, _RecordingRepository repository})> _launch(
  WidgetTester tester, {
  required bool exists,
  int launches = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final service = FixedAgeSignalService(minorSignal);
  final repository = _RecordingRepository();
  for (var i = 0; i < launches; i++) {
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(_FakeAuthService()),
        authStateProvider.overrideWith((ref) => AuthStateNotifier(_FakeAuthRepository())),
        profileRepositoryProvider.overrideWithValue(_FakeProfileRepository(exists: exists)),
        existingUserAgeSignalProvider.overrideWithValue(
          ExistingUserAgeSignal(service, repository, prefs),
        ),
      ],
      child: MaterialApp(
        home: const AuthLoadingScreen(),
        routes: {
          '/match': (_) => const Text('Match'),
          '/profile-creation/name': (_) => const Text('Profile creation'),
        },
      ),
    ));
    await tester.pumpAndSettle();
  }
  return (service: service, repository: repository);
}

void main() {
  testWidgets('an existing user sends the signal on the first launch only', (tester) async {
    final (:service, :repository) = await _launch(tester, exists: true, launches: 2);

    expect(find.text('Match'), findsOneWidget);
    expect(service.reads, 1);
    expect(repository.sent, [minorSignal]);
  });

  testWidgets('someone still signing up is not asked at launch', (tester) async {
    final (:service, :repository) = await _launch(tester, exists: false);

    expect(find.text('Profile creation'), findsOneWidget);
    expect(service.reads, 0);
    expect(repository.sent, isEmpty);
  });
}
