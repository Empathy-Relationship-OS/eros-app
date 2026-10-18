import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'server_clock.dart';

/// The app's [ServerClock]. Override in tests to inject a fake device clock.
final serverClockProvider = Provider<ServerClock>(
  (ref) => ServerClock.instance,
);

/// The backend's dev clock offset (`X-Clock-Offset-Seconds`), as a [Duration].
///
/// [Duration.zero] when the backend clock is not shifted. Rebuilds watchers
/// whenever [ServerClock.devOffset] changes.
final devClockOffsetProvider =
    NotifierProvider<DevClockOffsetNotifier, Duration>(
      DevClockOffsetNotifier.new,
    );

/// Mirrors [ServerClock.devOffset] into Riverpod state.
class DevClockOffsetNotifier extends Notifier<Duration> {
  @override
  Duration build() {
    final listenable = ref.watch(serverClockProvider).devOffset;
    void onChange() => state = listenable.value;
    listenable.addListener(onChange);
    ref.onDispose(() => listenable.removeListener(onChange));
    return listenable.value;
  }
}
