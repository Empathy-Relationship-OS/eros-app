import 'package:shared_preferences/shared_preferences.dart';

/// Remembers, per user uid on this device, whether the user has dismissed the banner on the Match
/// preferences screen that explains dealbreakers (RFC-007 §4.9).
///
/// The key is per-user, so `SignOutService` clears it with the rest of the user's data.
class MatchPreferencesBannerStore {
  MatchPreferencesBannerStore(this._prefs);

  final SharedPreferences _prefs;

  static String dismissedKey(String uid) => 'match_preferences_banner_dismissed_$uid';

  /// Whether [uid] has dismissed the dealbreakers banner on this device.
  bool isDismissed(String uid) => _prefs.getBool(dismissedKey(uid)) ?? false;

  Future<void> dismiss(String uid) => _prefs.setBool(dismissedKey(uid), true);
}
