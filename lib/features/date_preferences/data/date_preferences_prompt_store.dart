import 'package:shared_preferences/shared_preferences.dart';

/// Remembers, per user uid on this device, which date preference prompts (RFC-005 §6.3) the user
/// has already seen: the one-time sheet after onboarding and the Dates tab card.
///
/// The keys are per-user, so `SignOutService` clears them with the rest of the user's data.
class DatePreferencesPromptStore {
  DatePreferencesPromptStore(this._prefs);

  final SharedPreferences _prefs;

  static String sheetShownKey(String uid) => 'date_preferences_sheet_shown_$uid';
  static String cardDismissedKey(String uid) => 'date_preferences_card_dismissed_$uid';

  /// Whether the "Set your date preferences?" sheet has been shown to [uid] on this device.
  bool hasShownSheet(String uid) => _prefs.getBool(sheetShownKey(uid)) ?? false;

  Future<void> markSheetShown(String uid) => _prefs.setBool(sheetShownKey(uid), true);

  /// Whether [uid] has dismissed the Dates tab card on this device.
  bool isCardDismissed(String uid) => _prefs.getBool(cardDismissedKey(uid)) ?? false;

  Future<void> dismissCard(String uid) => _prefs.setBool(cardDismissedKey(uid), true);
}
