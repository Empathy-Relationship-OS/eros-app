import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/notifications/push_host.dart';
import 'package:eros_app/features/verification/data/verification_repository.dart';
import 'package:eros_app/features/verification/domain/models/verification_models.dart';

final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return VerificationRepository(apiClient);
});

/// The signed-in user's verification status, from `GET /users/me/verification`.
///
/// The server owns the state (primer rule 22): call [VerificationStatusNotifier.refresh] through
/// [verificationStatusNotifierProvider] after a submit, a decision push or a resume, and never
/// set it locally. It holds the status only, never a selfie (rule 19).
///
/// A status belongs to one user. Each user's lives in its own [verificationStatusForUserProvider]
/// entry, so a new user starts from loading and never sees the previous user's status, even for
/// a moment.
final verificationStatusProvider = Provider.autoDispose<AsyncValue<VerificationStatus>>(
  (ref) => ref.watch(verificationStatusForUserProvider(ref.watch(signedInUidProvider))),
);

/// The notifier behind [verificationStatusProvider], for [VerificationStatusNotifier.refresh].
final verificationStatusNotifierProvider = Provider.autoDispose<VerificationStatusNotifier>(
  (ref) => ref.watch(verificationStatusForUserProvider(ref.watch(signedInUidProvider)).notifier),
);

/// One entry per user id. Read [verificationStatusProvider] instead: this is keyed so that no
/// user's status is ever held in another user's entry.
final verificationStatusForUserProvider = AsyncNotifierProvider.autoDispose
    .family<VerificationStatusNotifier, VerificationStatus, String?>(
  VerificationStatusNotifier.new,
);

class VerificationStatusNotifier extends AutoDisposeFamilyAsyncNotifier<VerificationStatus, String?> {
  /// Bumped by every build, refresh and dispose. A fetch whose number is no longer current has
  /// been superseded, so its result is dropped rather than overwriting a newer status.
  int _generation = 0;

  @override
  Future<VerificationStatus> build(String? uid) {
    _generation++;
    ref.onDispose(() => _generation++);
    return ref.watch(verificationRepositoryProvider).getStatus();
  }

  /// Refetches the status. The last known one stays visible while it loads, and if the
  /// refetch fails: a failed refresh must not turn a verified user's screen into an error.
  /// When refreshes overlap, only the latest one's result is kept.
  Future<void> refresh() async {
    final generation = ++_generation;
    final previous = state;
    final next = await AsyncValue.guard(
      () => ref.read(verificationRepositoryProvider).getStatus(),
    );
    if (generation != _generation) return;
    state = next.hasError && previous.hasValue ? previous : next;
  }
}
