import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/dates/presentation/providers/date_detail_provider.dart';
import 'package:eros_app/features/verification/presentation/providers/verification_provider.dart';

/// Whether the verification wall is up on a date for the viewer (RFC-008 §5.3, VF-F4).
///
/// Up when the server's `verificationRequired` says so, or once an action on the date came
/// back 403 `VERIFICATION_REQUIRED` (a build that raced the state, or a verification reset
/// mid-date). It describes the viewer only, never the partner (D-7).
final dateVerificationWallProvider = Provider.autoDispose.family<bool, String>((ref, dateId) {
  final required = ref.watch(
    dateDetailProvider(dateId).select((s) => s.dateDetail?.verificationRequired ?? false),
  );
  return required || ref.watch(dateVerificationRaisedProvider(dateId));
});

/// Set when an action on the date failed with `VerificationRequiredFailure`. Read
/// [dateVerificationWallProvider] for whether the wall shows.
final dateVerificationRaisedProvider =
    NotifierProvider.autoDispose.family<DateVerificationNotifier, bool, String>(
  DateVerificationNotifier.new,
);

class DateVerificationNotifier extends AutoDisposeFamilyNotifier<bool, String> {
  bool _disposed = false;

  @override
  bool build(String dateId) {
    ref.onDispose(() => _disposed = true);
    return false;
  }

  /// An action on the date came back 403 `VERIFICATION_REQUIRED`: shows the wall at once,
  /// then refetches the date and the status so it reads right.
  Future<void> raise() async {
    state = true;
    await Future.wait([
      ref.read(dateDetailProvider(arg).notifier).refresh(),
      ref.read(verificationStatusNotifierProvider).refresh(),
    ]);
  }

  /// The status turned verified: refetches the date, and takes the wall down once the server
  /// no longer requires verification on it.
  Future<void> afterVerified() async {
    await ref.read(dateDetailProvider(arg).notifier).refresh();
    if (_disposed) return;
    final detail = ref.read(dateDetailProvider(arg)).dateDetail;
    if (detail != null && !detail.verificationRequired) state = false;
  }
}
