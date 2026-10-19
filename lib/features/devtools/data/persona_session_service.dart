import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eros_app/core/auth/sign_out_service.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/features/auth/data/repositories/auth_repository.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/auth/presentation/providers/marketing_consent_provider.dart';
import 'package:eros_app/features/dates/presentation/providers/cancel_provider.dart';
import 'package:eros_app/features/dates/presentation/providers/date_detail_provider.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_list_provider.dart';
import 'package:eros_app/features/matching/presentation/providers/match_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/photo_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/qa_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:eros_app/features/wallet/presentation/providers/purchase_provider.dart';
import 'package:eros_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'devtools_api.dart';

/// SharedPreferences key holding the uids of the last personas signed in as,
/// most recent first.
///
/// Listed in `SignOutService`'s keep-list, so it survives the sign-out that
/// every persona switch performs.
const String recentPersonasPrefsKey = 'devtools_recent_personas';

/// Signs in with a Firebase custom token. Production code never does this;
/// it lives in devtools on purpose (not in `AuthRepository`).
typedef CustomTokenSignIn = Future<void> Function(String customToken);

/// Completes once the app's auth state (`currentUserProvider`) shows [uid],
/// or nobody when [uid] is null.
typedef AwaitAuthUid = Future<void> Function(String? uid);

/// A persona switch failed.
///
/// [signedOut] is true when the previous user had already been signed out
/// before the failure (the custom token sign-in itself failed). When the
/// token could not be minted, [signedOut] is false and the previous user is
/// still signed in.
class PersonaSwitchException implements Exception {
  final String message;
  final bool signedOut;
  final Object? cause;

  const PersonaSwitchException(
    this.message, {
    required this.signedOut,
    this.cause,
  });

  @override
  String toString() => 'PersonaSwitchException: $message';
}

/// The last [maxEntries] personas signed in as, most recent first.
class RecentPersonasStore {
  static const int maxEntries = 5;

  final SharedPreferences _prefs;

  RecentPersonasStore(this._prefs);

  List<String> read() =>
      _prefs.getStringList(recentPersonasPrefsKey) ?? const [];

  /// Moves [uid] to the front, dropping duplicates and anything past
  /// [maxEntries].
  Future<void> record(String uid) async {
    final next = [
      uid,
      ...read().where((u) => u != uid),
    ].take(maxEntries).toList();
    await _prefs.setStringList(recentPersonasPrefsKey, next);
  }

  Future<void> remove(String uid) async {
    final current = read();
    if (!current.contains(uid)) return;
    await _prefs.setStringList(
      recentPersonasPrefsKey,
      current.where((u) => u != uid).toList(),
    );
  }
}

/// Every provider that holds state belonging to the signed-in user.
///
/// Most of them already rebuild when the user changes, because
/// `apiClientProvider` watches `currentUserProvider` and the repositories
/// watch `apiClientProvider`. That chain is implicit and easy to break, and
/// a few providers (Q&A drafts, marketing consent, profile creation draft,
/// cancellation state) are not on it at all, so a persona switch invalidates
/// all of them explicitly.
///
/// When a feature adds a provider that caches per-user data and is not
/// `autoDispose`, add it here.
final List<ProviderOrFamily> userScopedProviders = [
  // Root of the per-user network graph: rebuilding it rebuilds every
  // repository, and every provider that watches one.
  apiClientProvider,
  // Profile
  userProfileProvider,
  profileCreationProvider,
  photoUploadProvider,
  qaDraftsProvider,
  marketingConsentProvider,
  // Matches
  matchBatchProvider,
  last24HoursProvider,
  // Dates
  activeDatesProvider,
  pastDatesProvider,
  cancelledDatesProvider,
  dateDetailProvider,
  cancelProvider,
  // Wallet
  walletBalanceProvider,
  transactionHistoryProvider,
  purchaseProvider,
];

/// Switches the app to a dev persona (RFC-003 §4.1).
///
/// Order matters: the custom token is minted **before** anything else, so a
/// failed mint (backend down, unknown uid, wrong key) leaves whoever is
/// signed in untouched.
class PersonaSessionService {
  final DevtoolsApi _api;
  final SignOutService _signOutService;
  final CustomTokenSignIn _signInWithCustomToken;
  final AwaitAuthUid _awaitAuthUid;
  final VoidCallback _resetUserState;
  final RecentPersonasStore _recent;
  final Logger _logger;

  PersonaSessionService({
    required DevtoolsApi api,
    required SignOutService signOutService,
    required CustomTokenSignIn signInWithCustomToken,
    required AwaitAuthUid awaitAuthUid,
    required VoidCallback resetUserState,
    required RecentPersonasStore recentPersonas,
    Logger? logger,
  }) : _api = api,
       _signOutService = signOutService,
       _signInWithCustomToken = signInWithCustomToken,
       _awaitAuthUid = awaitAuthUid,
       _resetUserState = resetUserState,
       _recent = recentPersonas,
       _logger = logger ?? Logger();

  /// Signs out whoever is signed in and signs in as [uid].
  ///
  /// 1. `POST /dev/personas/{uid}/token`. If this fails, nothing else
  ///    happens and the error is rethrown as-is (an `ApiException`).
  /// 2. Full sign-out through [SignOutService] (clears SharedPreferences
  ///    except its keep-list).
  /// 3. `signInWithCustomToken`.
  /// 4. Waits for the app's auth state to show [uid], then invalidates
  ///    [userScopedProviders] so nothing of the previous user is left.
  /// 5. Records [uid] in the recent list.
  ///
  /// The caller then navigates to the `AuthLoadingScreen` route so the
  /// normal routing decides where to land.
  ///
  /// Throws [PersonaSwitchException] if steps 2 or 3 fail.
  Future<void> signInAs(String uid) async {
    _logger.i('🛠️ Switching to persona $uid');

    // 1. Mint first. A failure here must not sign anyone out.
    final token = await _api.getPersonaToken(uid);

    // 2. Sign out the previous user.
    try {
      await _signOutService.signOut();
      await _awaitAuthUid(null);
    } catch (e) {
      throw PersonaSwitchException(
        'Could not sign out before switching to $uid: $e',
        signedOut: false,
        cause: e,
      );
    }

    // 3. Sign in as the persona.
    try {
      await _signInWithCustomToken(token.customToken);
    } catch (e) {
      // The previous user is gone; do not leave their state behind either.
      _resetUserState();
      throw PersonaSwitchException(
        'Signed out, but signing in as $uid failed: ${_describe(e)}',
        signedOut: true,
        cause: e,
      );
    }

    // 4. Let the app see the new user, then drop every per-user cache.
    await _awaitAuthUid(uid);
    _resetUserState();

    // 5. Remember it. Best-effort: the switch itself has succeeded.
    try {
      await _recent.record(uid);
    } catch (e) {
      _logger.w('🛠️ Could not record recent persona $uid', error: e);
    }

    _logger.i('🛠️ Signed in as persona $uid');
  }

  /// Signs out whoever is signed in and drops every per-user cache.
  ///
  /// Used after `POST /dev/reset` has deleted the signed-in persona. Same
  /// steps as the sign-out half of [signInAs]: [SignOutService], wait for
  /// the app's auth state to show nobody, then invalidate
  /// [userScopedProviders]. The caller then navigates to the
  /// `AuthLoadingScreen` route, which sends a signed-out app to welcome.
  ///
  /// Throws whatever [SignOutService.signOut] throws.
  Future<void> signOut() async {
    _logger.i('🛠️ Signing out persona');
    await _signOutService.signOut();
    await _awaitAuthUid(null);
    _resetUserState();
  }

  String _describe(Object e) =>
      e is FirebaseAuthException ? (e.message ?? e.code) : e.toString();
}

/// Signs in to Firebase with a custom token.
final customTokenSignInProvider = Provider<CustomTokenSignIn>((ref) {
  return (customToken) async {
    await ref.read(firebaseAuthProvider).signInWithCustomToken(customToken);
  };
});

/// The recent personas list, persisted in SharedPreferences.
final recentPersonasStoreProvider = Provider<RecentPersonasStore>((ref) {
  return RecentPersonasStore(ref.watch(sharedPreferencesProvider));
});

/// How long [PersonaSessionService] waits for `authStateProvider` to catch up
/// with Firebase after a sign-out or sign-in.
const Duration personaAuthStateTimeout = Duration(seconds: 10);

/// The [PersonaSessionService] used by the Personas tab (and scenarios,
/// DT-F5, to sign in as `loginAs`).
final personaSessionServiceProvider = Provider<PersonaSessionService>((ref) {
  return PersonaSessionService(
    api: ref.watch(devtoolsApiProvider),
    signOutService: ref.watch(signOutServiceProvider),
    signInWithCustomToken: ref.watch(customTokenSignInProvider),
    recentPersonas: ref.watch(recentPersonasStoreProvider),
    awaitAuthUid: (uid) => _awaitAuthUid(ref, uid),
    resetUserState: () {
      // Through the container, not `ref.invalidate`: in debug builds
      // `ref.invalidate` first creates the provider to check the dependency
      // graph, which would build every per-user provider just to dispose it.
      // The container only invalidates providers that already exist.
      final container = ref.container;
      for (final provider in userScopedProviders) {
        container.invalidate(provider);
      }
    },
  );
});

/// `authStateProvider` follows Firebase through a stream, so it lags behind
/// `signOut`/`signInWithCustomToken` by an event. `AuthLoadingScreen` reads
/// it exactly once, so wait until it agrees before navigating there.
Future<void> _awaitAuthUid(Ref ref, String? uid) async {
  final uidProvider = currentUserProvider.select((user) => user?.uid);
  if (ref.read(uidProvider) == uid) return;

  final reached = Completer<void>();
  final subscription = ref.listen<String?>(uidProvider, (_, next) {
    if (next == uid && !reached.isCompleted) reached.complete();
  });
  try {
    await reached.future.timeout(personaAuthStateTimeout);
  } on TimeoutException {
    // Firebase itself has switched; carry on rather than fail the switch.
    Logger().w(
      '🛠️ Auth state did not show ${uid ?? 'signed out'} '
      'within $personaAuthStateTimeout',
    );
  } finally {
    subscription.close();
  }
}
