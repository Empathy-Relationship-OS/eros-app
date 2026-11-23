import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eros_app/features/legal/data/repositories/age_signal_repository.dart';
import 'package:eros_app/features/legal/data/services/age_signal_service.dart';
import 'package:eros_app/features/legal/domain/models/store_age_signal.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';

/// What the store said at sign-up, read once before the date of birth step (CF-F6).
///
/// Memory only, never the persisted draft: an age band stays off the phone's storage (primer
/// rule 19). If the app is closed before `POST /users`, sign-up goes without it, which never
/// blocks anyone.
@immutable
class SignupAgeCheck {
  /// The Firebase user it was read for. Another user signing up in the same app session is
  /// asked again.
  final String uid;

  /// Null when the store gave no signal.
  final StoreAgeSignal? signal;

  const SignupAgeCheck(this.uid, this.signal);
}

/// Null until the store has been asked during this sign-up.
final signupAgeCheckProvider = StateProvider<SignupAgeCheck?>((ref) => null);

/// Sends an existing user's age signal once (CF-F6 step 4, `POST /users/me/age-signal`).
///
/// "Asked" is remembered per user in SharedPreferences, as a flag only, never the band. Sign-out
/// clears it, so the next person to sign in on this phone is asked too; the backend ignores a
/// band it already has.
class ExistingUserAgeSignal {
  final AgeSignalService _service;
  final AgeSignalRepository _repository;
  final SharedPreferences _prefs;

  ExistingUserAgeSignal(this._service, this._repository, this._prefs);

  static String askedKey(String uid) => 'age_signal_asked_$uid';

  bool wasAsked(String uid) => _prefs.getBool(askedKey(uid)) ?? false;

  /// Marks [uid] as asked without asking: sign-up already sent the signal with `POST /users`.
  static Future<void> markAskedIn(SharedPreferences prefs, String uid) =>
      prefs.setBool(askedKey(uid), true);

  /// Reads the store and sends a signal if there is one, unless [uid] was asked before. A failed
  /// send isn't marked, so the next launch tries again. Never throws.
  Future<void> sendOnce(String uid) async {
    if (wasAsked(uid)) return;
    try {
      final signal = await _service.read();
      if (signal != null) await _repository.send(signal);
      await markAskedIn(_prefs, uid);
    } catch (e) {
      debugPrint('Age signal: not sent, will try on the next launch (${e.runtimeType})');
    }
  }
}

final existingUserAgeSignalProvider = Provider<ExistingUserAgeSignal>((ref) {
  return ExistingUserAgeSignal(
    ref.watch(ageSignalServiceProvider),
    ref.watch(ageSignalRepositoryProvider),
    ref.watch(sharedPreferencesProvider),
  );
});
