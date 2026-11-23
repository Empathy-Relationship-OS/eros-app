import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/notifications/push_host.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/verification/data/verification_card_store.dart';
import 'package:eros_app/features/verification/domain/models/verification_models.dart';

final verificationCardStoreProvider = Provider<VerificationCardStore>((ref) {
  return VerificationCardStore(ref.watch(sharedPreferencesProvider));
});

/// The state the signed-in user was in when they dismissed the Matches card, or null if they
/// haven't dismissed it (VF-F3).
final verificationCardDismissalProvider =
    NotifierProvider.autoDispose<VerificationCardDismissalNotifier, VerificationState?>(
  VerificationCardDismissalNotifier.new,
);

class VerificationCardDismissalNotifier extends AutoDisposeNotifier<VerificationState?> {
  @override
  VerificationState? build() {
    final uid = ref.watch(signedInUidProvider);
    if (uid == null) return null;
    return ref.watch(verificationCardStoreProvider).dismissedIn(uid);
  }

  /// Remembers that the card was dismissed while the user was in [state]. Also used to move a
  /// dismissal made in retry on to the next state, so that the following retry shows it again.
  Future<void> dismiss(VerificationState state) async {
    final uid = ref.read(signedInUidProvider);
    if (uid == null) return;
    this.state = state;
    await ref.read(verificationCardStoreProvider).dismiss(uid, state);
  }
}

/// States where the card comes back after a dismissal made in another state: each asks the
/// user for something new (another selfie, or the age check).
const Set<VerificationState> verificationCardReturnsIn = {
  VerificationState.retry,
  VerificationState.ageCheck,
};

/// Whether the Matches card shows for someone in [state] who dismissed it in [dismissedIn].
///
/// Only where there's something to do: not verified (an unknown state counts), retry or the age
/// check. Not in review or locked, where a "verify" prompt has nothing to start, and never once
/// verified. A dismissal holds until the user lands in one of [verificationCardReturnsIn] from
/// another state.
bool shouldShowVerificationCard(VerificationState state, VerificationState? dismissedIn) {
  final actionable = state == VerificationState.notVerified ||
      state == VerificationState.unknown ||
      verificationCardReturnsIn.contains(state);
  if (!actionable) return false;
  if (dismissedIn == null) return true;
  return verificationCardReturnsIn.contains(state) && dismissedIn != state;
}
