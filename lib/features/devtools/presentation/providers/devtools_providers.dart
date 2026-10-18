import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import '../../data/devtools_api.dart';
import '../../data/models/devtools_models.dart';

/// Backend devtools health for the dev menu header.
///
/// Errors are the API's exceptions: `DevtoolsDisabledException` when the
/// backend has devtools off, `DevtoolsKeyMissingException` when the app was
/// built without `DEVTOOLS_KEY`, `NetworkException` when the backend is down.
/// Call `ref.invalidate(devtoolsHealthProvider)` to refresh, for example after
/// moving the clock.
final devtoolsHealthProvider =
    FutureProvider.autoDispose<DevtoolsHealth>((ref) {
  return ref.watch(devtoolsApiProvider).health();
});

/// Firebase uid of whoever is signed in, or null when signed out.
final devtoolsSignedInUidProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.uid;
});
