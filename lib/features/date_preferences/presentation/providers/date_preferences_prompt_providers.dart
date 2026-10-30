import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/date_preferences/data/date_preferences_prompt_store.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preferences_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';

/// Where the date preference prompts (RFC-005 §6.3) remember what the user has seen.
final datePreferencesPromptStoreProvider = Provider<DatePreferencesPromptStore>((ref) {
  return DatePreferencesPromptStore(ref.watch(sharedPreferencesProvider));
});

/// Firebase uid of whoever is signed in, or null when signed out. The prompts are remembered
/// per uid.
final datePreferencesPromptUidProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider.select((user) => user?.uid));
});

/// Whether the signed-in user has dismissed the Dates tab card. True when nobody is signed in,
/// so the card never shows then.
class DatePreferencesCardDismissedNotifier extends Notifier<bool> {
  @override
  bool build() {
    final uid = ref.watch(datePreferencesPromptUidProvider);
    if (uid == null) return true;
    return ref.watch(datePreferencesPromptStoreProvider).isCardDismissed(uid);
  }

  Future<void> dismiss() async {
    final uid = ref.read(datePreferencesPromptUidProvider);
    if (uid == null) return;
    state = true;
    await ref.read(datePreferencesPromptStoreProvider).dismissCard(uid);
  }
}

final datePreferencesCardDismissedProvider =
    NotifierProvider<DatePreferencesCardDismissedNotifier, bool>(
  DatePreferencesCardDismissedNotifier.new,
);

/// Whether the Dates tab shows "Tell us what dates you like": while the user's preferences are
/// not set and they haven't dismissed the card. Hidden while loading or after a failed load.
/// Saving a section from the hub makes `isSet` true, which hides it.
final showDatePreferencesCardProvider = Provider<bool>((ref) {
  if (ref.watch(datePreferencesCardDismissedProvider)) return false;
  final preferences = ref.watch(datePreferencesProvider).valueOrNull;
  return preferences != null && !preferences.isSet;
});
