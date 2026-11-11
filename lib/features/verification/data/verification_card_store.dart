import 'package:shared_preferences/shared_preferences.dart';
import 'package:eros_app/features/verification/domain/models/verification_models.dart';

/// Remembers, per user uid on this device, that the "Verify before your first date" card on the
/// Matches tab was dismissed, and in which verification state (RFC-008 VF-F3). The state lets
/// the card come back when the user lands in retry after dismissing it.
///
/// It holds a state name only, nothing about a selfie. The key is per-user, so `SignOutService`
/// clears it with the rest of the user's data.
class VerificationCardStore {
  VerificationCardStore(this._prefs);

  final SharedPreferences _prefs;

  static String dismissedKey(String uid) => 'verification_card_dismissed_$uid';

  /// The state [uid] was in when they last dismissed the card, or null if they haven't.
  VerificationState? dismissedIn(String uid) {
    final name = _prefs.getString(dismissedKey(uid));
    if (name == null) return null;
    for (final state in VerificationState.values) {
      if (state.name == name) return state;
    }
    return VerificationState.unknown;
  }

  Future<void> dismiss(String uid, VerificationState state) =>
      _prefs.setString(dismissedKey(uid), state.name);
}
