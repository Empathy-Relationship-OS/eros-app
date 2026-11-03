import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/settings/presentation/providers/app_settings_provider.dart';

/// Remembers which chats have shown the one-time "Keep it about meeting up" line.
///
/// Stored per user and per date, so two personas on one device each see it once.
/// `SignOutService` clears it with the other per-user keys, and that's fine.
class ChatIntroStore {
  final SharedPreferences _prefs;

  ChatIntroStore(this._prefs);

  static String key(String uid, String dateId) => 'chat_intro_seen_${uid}_$dateId';

  bool hasSeen(String uid, String dateId) => _prefs.getBool(key(uid, dateId)) ?? false;

  Future<void> markSeen(String uid, String dateId) => _prefs.setBool(key(uid, dateId), true);
}

final chatIntroStoreProvider = Provider<ChatIntroStore>(
  (ref) => ChatIntroStore(ref.watch(sharedPreferencesProvider)),
);

/// Remembers that this user has seen the one-time contact details tip (RFC-006 D-6).
///
/// Stored per user, not per chat: it shows the first time the app shows any flagged
/// message. `SignOutService` clears it with the other per-user keys, and that's fine.
class ContactTipStore {
  final SharedPreferences _prefs;

  ContactTipStore(this._prefs);

  static String key(String uid) => 'chat_contact_tip_seen_$uid';

  bool hasSeen(String uid) => _prefs.getBool(key(uid)) ?? false;

  Future<void> markSeen(String uid) => _prefs.setBool(key(uid), true);
}

final contactTipStoreProvider = Provider<ContactTipStore>(
  (ref) => ContactTipStore(ref.watch(sharedPreferencesProvider)),
);

/// Whether the system lets the app show notifications, for the "notifications are off"
/// banner. The chat screen refreshes it when the app comes back to the foreground.
final chatNotificationsEnabledProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(notificationPermissionServiceProvider).isNotificationPermissionGranted(),
);
