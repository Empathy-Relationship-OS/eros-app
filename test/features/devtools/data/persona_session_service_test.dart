import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eros_app/core/auth/sign_out_service.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/auth/data/repositories/auth_repository.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/dates/data/repositories/dates_repository.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_list_provider.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_repository_provider.dart';
import 'package:eros_app/features/devtools/data/devtools_api.dart';
import 'package:eros_app/features/devtools/data/models/devtools_models.dart';
import 'package:eros_app/features/devtools/data/persona_session_service.dart';
import 'package:eros_app/features/matching/data/repositories/match_repository.dart';
import 'package:eros_app/features/matching/presentation/providers/match_provider.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/qa_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:eros_app/features/wallet/data/repositories/wallet_repository.dart';
import 'package:eros_app/features/wallet/presentation/providers/wallet_provider.dart';
import '../fake_devtools_api.dart';

// ====================
// FAKES
// ====================

/// Records the order of every step into a shared log.
class _FakeSignOutService implements SignOutService {
  final List<String> log;
  final void Function()? onSignOut;
  Object? error;

  _FakeSignOutService(this.log, {this.onSignOut});

  @override
  Future<void> signOut() async {
    log.add('signOut');
    if (error != null) throw error!;
    onSignOut?.call();
  }

  @override
  Future<void> clearAllData() async => log.add('clearAllData');
}

class _LoggingApi extends FakeDevtoolsApi {
  final List<String> log;

  _LoggingApi(this.log);

  @override
  Future<CustomToken> getPersonaToken(String uid) async {
    log.add('mint:$uid');
    return super.getPersonaToken(uid);
  }
}

class _FakeUser implements User {
  @override
  final String uid;

  _FakeUser(this.uid);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  int signOutCalls = 0;

  @override
  Future<void> signOut() async => signOutCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Repositories whose async calls never complete, so notifiers that load on
// creation stay idle.
class _IdleWalletRepository implements WalletRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Completer<Never>().future;
}

class _IdleDatesRepository implements DatesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Completer<Never>().future;
}

class _IdleMatchRepository implements MatchRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Completer<Never>().future;
}

class _IdleProfileRepository implements ProfileRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Completer<Never>().future;
}

PersonaSessionService _service({
  required DevtoolsApi api,
  required SignOutService signOutService,
  required List<String> log,
  required SharedPreferences prefs,
  Object? signInError,
}) {
  return PersonaSessionService(
    api: api,
    signOutService: signOutService,
    signInWithCustomToken: (token) async {
      log.add('signIn:$token');
      if (signInError != null) throw signInError;
    },
    awaitAuthUid: (uid) async => log.add('await:${uid ?? 'none'}'),
    resetUserState: () => log.add('reset'),
    recentPersonas: RecentPersonasStore(prefs),
  );
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('PersonaSessionService.signInAs', () {
    test(
      'mints, then signs out, then signs in, then resets user state',
      () async {
        final log = <String>[];
        final service = _service(
          api: _LoggingApi(log),
          signOutService: _FakeSignOutService(log),
          log: log,
          prefs: prefs,
        );

        await service.signInAs('dev_bob');

        expect(log, [
          'mint:dev_bob',
          'signOut',
          'await:none',
          'signIn:custom-token-for-dev_bob',
          'await:dev_bob',
          'reset',
        ]);
      },
    );

    test('does not sign out the current user when minting fails', () async {
      final log = <String>[];
      final api = _LoggingApi(log)
        ..tokenError = const NotFoundException('No such persona: dev_zed');
      final service = _service(
        api: api,
        signOutService: _FakeSignOutService(log),
        log: log,
        prefs: prefs,
      );

      await expectLater(
        service.signInAs('dev_zed'),
        throwsA(
          isA<NotFoundException>().having(
            (e) => e.message,
            'message',
            'No such persona: dev_zed',
          ),
        ),
      );

      expect(log, ['mint:dev_zed']);
      expect(RecentPersonasStore(prefs).read(), isEmpty);
    });

    test(
      'reports signed out and still resets state when sign-in fails',
      () async {
        final log = <String>[];
        final service = _service(
          api: _LoggingApi(log),
          signOutService: _FakeSignOutService(log),
          log: log,
          prefs: prefs,
          signInError: FirebaseAuthException(
            code: 'invalid-custom-token',
            message: 'Bad token',
          ),
        );

        await expectLater(
          service.signInAs('dev_bob'),
          throwsA(
            isA<PersonaSwitchException>()
                .having((e) => e.signedOut, 'signedOut', isTrue)
                .having((e) => e.message, 'message', contains('Bad token')),
          ),
        );
        expect(log.last, 'reset');
        expect(RecentPersonasStore(prefs).read(), isEmpty);
      },
    );

    test('does not sign in when sign-out fails', () async {
      final log = <String>[];
      final signOut = _FakeSignOutService(log)..error = Exception('boom');
      final service = _service(
        api: _LoggingApi(log),
        signOutService: signOut,
        log: log,
        prefs: prefs,
      );

      await expectLater(
        service.signInAs('dev_bob'),
        throwsA(
          isA<PersonaSwitchException>().having(
            (e) => e.signedOut,
            'signedOut',
            isFalse,
          ),
        ),
      );
      expect(log, ['mint:dev_bob', 'signOut']);
    });

    test('records the persona in the recent list', () async {
      final log = <String>[];
      final service = _service(
        api: _LoggingApi(log),
        signOutService: _FakeSignOutService(log),
        log: log,
        prefs: prefs,
      );

      await service.signInAs('dev_alice');
      await service.signInAs('dev_bob');

      expect(RecentPersonasStore(prefs).read(), ['dev_bob', 'dev_alice']);
    });
  });

  group('PersonaSessionService.signOut', () {
    test('signs out, waits for nobody, then resets user state', () async {
      final log = <String>[];
      final service = _service(
        api: _LoggingApi(log),
        signOutService: _FakeSignOutService(log),
        log: log,
        prefs: prefs,
      );

      await service.signOut();

      expect(log, ['signOut', 'await:none', 'reset']);
    });

    test('rethrows a sign-out failure without resetting', () async {
      final log = <String>[];
      final signOut = _FakeSignOutService(log)..error = Exception('boom');
      final service = _service(
        api: _LoggingApi(log),
        signOutService: signOut,
        log: log,
        prefs: prefs,
      );

      await expectLater(service.signOut(), throwsException);
      expect(log, ['signOut']);
    });
  });

  group('RecentPersonasStore', () {
    test('keeps the last 5, most recent first, without duplicates', () async {
      final store = RecentPersonasStore(prefs);
      for (final uid in ['a', 'b', 'c', 'd', 'e', 'f', 'c']) {
        await store.record('dev_$uid');
      }

      expect(store.read(), ['dev_c', 'dev_f', 'dev_e', 'dev_d', 'dev_b']);
    });

    test('remove drops a uid', () async {
      final store = RecentPersonasStore(prefs);
      await store.record('dev_alice');
      await store.record('dev_bob');
      await store.remove('dev_alice');

      expect(store.read(), ['dev_bob']);
    });

    test('survives SignOutService.signOut', () async {
      final store = RecentPersonasStore(prefs);
      await store.record('dev_alice');
      await prefs.setString('some_user_key', 'alice data');
      final auth = _FakeFirebaseAuth();

      await SignOutService(firebaseAuth: auth, sharedPrefs: prefs).signOut();

      expect(auth.signOutCalls, 1);
      expect(prefs.getString('some_user_key'), isNull);
      expect(store.read(), ['dev_alice']);
      expect(prefs.getKeys(), {recentPersonasPrefsKey});
    });
  });

  group('personaSessionServiceProvider', () {
    late ProviderContainer container;
    late StateController<User?> firebaseUser;
    late FakeDevtoolsApi api;
    late List<String> log;

    // Simulates Firebase: the app's auth state follows sign-out/sign-in one
    // event later, as `AuthStateNotifier` does through `authStateChanges`.
    final fakeFirebaseUser = StateProvider<User?>((ref) => null);

    setUp(() {
      log = [];
      api = FakeDevtoolsApi(personas: standardCast());
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          devtoolsApiProvider.overrideWithValue(api),
          currentUserProvider.overrideWith(
            (ref) => ref.watch(fakeFirebaseUser),
          ),
          signOutServiceProvider.overrideWith(
            (ref) => _FakeSignOutService(
              log,
              onSignOut: () {
                Future(() => firebaseUser.state = null);
              },
            ),
          ),
          customTokenSignInProvider.overrideWith(
            (ref) => (token) async {
              log.add('signIn:$token');
              final uid = token.replaceFirst('custom-token-for-', '');
              Future(() => firebaseUser.state = _FakeUser(uid));
            },
          ),
          walletRepositoryProvider.overrideWithValue(_IdleWalletRepository()),
          datesRepositoryProvider.overrideWithValue(_IdleDatesRepository()),
          matchRepositoryProvider.overrideWithValue(_IdleMatchRepository()),
          profileRepositoryProvider.overrideWithValue(_IdleProfileRepository()),
        ],
      );
      firebaseUser = container.read(fakeFirebaseUser.notifier);
      firebaseUser.state = _FakeUser('dev_alice');
    });

    tearDown(() => container.dispose());

    test('waits for the app auth state to show the new persona', () async {
      await container.read(personaSessionServiceProvider).signInAs('dev_bob');

      expect(container.read(currentUserProvider)?.uid, 'dev_bob');
      expect(log, ['signOut', 'signIn:custom-token-for-dev_bob']);
    });

    test(
      're-signing in as the same persona still waits for the new session',
      () async {
        await container
            .read(personaSessionServiceProvider)
            .signInAs('dev_alice');

        expect(container.read(currentUserProvider)?.uid, 'dev_alice');
        expect(log, ['signOut', 'signIn:custom-token-for-dev_alice']);
      },
    );

    test("leaves none of the previous user's dates, matches, wallet or "
        'profile state behind', () async {
      // Alice's session: every per-user notifier exists and holds state.
      final aliceNotifiers = <String, Object>{
        'wallet': container.read(walletBalanceProvider.notifier),
        'transactions': container.read(transactionHistoryProvider.notifier),
        'activeDates': container.read(activeDatesProvider.notifier),
        'pastDates': container.read(pastDatesProvider.notifier),
        'cancelledDates': container.read(cancelledDatesProvider.notifier),
        'matchBatch': container.read(matchBatchProvider.notifier),
        'last24Hours': container.read(last24HoursProvider.notifier),
        'profile': container.read(userProfileProvider.notifier),
        'profileCreation': container.read(profileCreationProvider.notifier),
        'qaDrafts': container.read(qaDraftsProvider.notifier),
      };

      await container.read(personaSessionServiceProvider).signInAs('dev_bob');

      final bobNotifiers = <String, Object>{
        'wallet': container.read(walletBalanceProvider.notifier),
        'transactions': container.read(transactionHistoryProvider.notifier),
        'activeDates': container.read(activeDatesProvider.notifier),
        'pastDates': container.read(pastDatesProvider.notifier),
        'cancelledDates': container.read(cancelledDatesProvider.notifier),
        'matchBatch': container.read(matchBatchProvider.notifier),
        'last24Hours': container.read(last24HoursProvider.notifier),
        'profile': container.read(userProfileProvider.notifier),
        'profileCreation': container.read(profileCreationProvider.notifier),
        'qaDrafts': container.read(qaDraftsProvider.notifier),
      };
      for (final name in aliceNotifiers.keys) {
        expect(
          identical(aliceNotifiers[name], bobNotifiers[name]),
          isFalse,
          reason: '$name still holds the previous user\'s notifier',
        );
      }
    });

    test('a failed mint leaves the user and their state alone', () async {
      api.tokenError = const NetworkException('Cannot reach the backend');
      final wallet = container.read(walletBalanceProvider.notifier);

      await expectLater(
        container.read(personaSessionServiceProvider).signInAs('dev_bob'),
        throwsA(isA<NetworkException>()),
      );

      expect(log, isEmpty);
      expect(container.read(currentUserProvider)?.uid, 'dev_alice');
      expect(container.read(walletBalanceProvider.notifier), same(wallet));
    });
  });

  test('userScopedProviders covers dates, matches, wallet and profile', () {
    expect(
      userScopedProviders,
      containsAll(<Object>[
        activeDatesProvider,
        pastDatesProvider,
        cancelledDatesProvider,
        matchBatchProvider,
        last24HoursProvider,
        walletBalanceProvider,
        transactionHistoryProvider,
        userProfileProvider,
      ]),
    );
  });
}
