import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/match_preferences/data/match_preferences_banner_store.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';

/// Where the Match preferences screen remembers that its dealbreakers banner was dismissed.
final matchPreferencesBannerStoreProvider = Provider<MatchPreferencesBannerStore>((ref) {
  return MatchPreferencesBannerStore(ref.watch(sharedPreferencesProvider));
});

/// Firebase uid of whoever is signed in, or null when signed out. The banner is remembered per
/// uid.
final matchPreferencesBannerUidProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider.select((user) => user?.uid));
});

/// Whether the signed-in user has dismissed the dealbreakers banner. True when nobody is signed
/// in, so the banner never shows then.
class MatchPreferencesBannerDismissedNotifier extends Notifier<bool> {
  @override
  bool build() {
    final uid = ref.watch(matchPreferencesBannerUidProvider);
    if (uid == null) return true;
    return ref.watch(matchPreferencesBannerStoreProvider).isDismissed(uid);
  }

  Future<void> dismiss() async {
    final uid = ref.read(matchPreferencesBannerUidProvider);
    if (uid == null) return;
    state = true;
    await ref.read(matchPreferencesBannerStoreProvider).dismiss(uid);
  }
}

final matchPreferencesBannerDismissedProvider =
    NotifierProvider<MatchPreferencesBannerDismissedNotifier, bool>(
  MatchPreferencesBannerDismissedNotifier.new,
);
