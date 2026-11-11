import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/features/verification/data/verification_repository.dart';
import 'package:eros_app/features/verification/domain/models/verification_models.dart';

final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return VerificationRepository(apiClient);
});

/// The signed-in user's verification status, from `GET /users/me/verification`.
///
/// The server owns the state (primer rule 22): call [VerificationStatusNotifier.refresh] after
/// a submit, a decision push or a resume, and never set it locally. It holds the status only,
/// never a selfie (rule 19). It rebuilds for a new user, since the repository follows the API
/// client.
final verificationStatusProvider =
    AsyncNotifierProvider<VerificationStatusNotifier, VerificationStatus>(
  VerificationStatusNotifier.new,
);

class VerificationStatusNotifier extends AsyncNotifier<VerificationStatus> {
  @override
  Future<VerificationStatus> build() => ref.watch(verificationRepositoryProvider).getStatus();

  /// Refetches the status. The last known one stays visible while it loads, and if the
  /// refetch fails: a failed refresh must not turn a verified user's screen into an error.
  Future<void> refresh() async {
    final previous = state;
    final next = await AsyncValue.guard(
      () => ref.read(verificationRepositoryProvider).getStatus(),
    );
    state = next.hasError && previous.hasValue ? previous : next;
  }
}
