import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';

/// Remembers, per user uid on this device, that the "Turn on notifications" prompt (RFC-006 §6.4)
/// has been shown, so it's shown once.
///
/// The key is per-user, so `SignOutService` clears it with the rest of the user's data.
class PushPromptStore {
  PushPromptStore(this._prefs);

  final SharedPreferences _prefs;

  static String shownKey(String uid) => 'push_prompt_shown_$uid';

  bool hasShown(String uid) => _prefs.getBool(shownKey(uid)) ?? false;

  Future<void> markShown(String uid) => _prefs.setBool(shownKey(uid), true);
}

final pushPromptStoreProvider = Provider<PushPromptStore>((ref) {
  return PushPromptStore(ref.watch(sharedPreferencesProvider));
});
