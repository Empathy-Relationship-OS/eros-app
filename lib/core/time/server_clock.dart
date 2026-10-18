import 'package:flutter/foundation.dart';

/// Estimates the backend's current time from the `X-Server-Time` response header.
///
/// Use [now] instead of `DateTime.now()` for anything compared against a server
/// timestamp (deadlines, countdowns, "starts in"). The phone's clock can be wrong,
/// and in dev builds the backend clock can be moved forward (RFC-003 §4.3, §5.6).
///
/// [ServerTimeInterceptor] feeds every API response into [updateFromHeaders].
class ServerClock {
  /// Shared instance used by the app. Tests may construct their own.
  static final ServerClock instance = ServerClock();

  /// Skew changes smaller than this are ignored so countdowns don't jitter from
  /// network latency.
  static const Duration skewThreshold = Duration(seconds: 2);

  ServerClock({DateTime Function()? deviceNow})
    : _deviceNow = deviceNow ?? DateTime.now;

  final DateTime Function() _deviceNow;
  Duration _skew = Duration.zero;
  final ValueNotifier<Duration> _devOffset = ValueNotifier(Duration.zero);

  /// Server time now (UTC), estimated from the latest `X-Server-Time` header.
  DateTime now() => _deviceNow().toUtc().add(_skew);

  /// Current estimate of `serverTime - deviceTime`.
  Duration get skew => _skew;

  /// Dev-only offset reported by `X-Clock-Offset-Seconds`.
  /// [Duration.zero] when the header is absent.
  ValueListenable<Duration> get devOffset => _devOffset;

  /// Updates the clock from one response's headers.
  ///
  /// - A missing or unparsable [serverTime] is ignored: the previous skew is kept,
  ///   and [devOffset] is left alone too, because a response without
  ///   `X-Server-Time` did not come from the backend (e.g. a proxy error page).
  /// - A skew change under [skewThreshold] is ignored.
  /// - A missing [offsetSeconds] resets [devOffset] to zero (the server sends it
  ///   only when its clock is shifted). An unparsable value is ignored.
  void updateFromHeaders({
    required String? serverTime,
    required String? offsetSeconds,
    required DateTime receivedAt,
  }) {
    final parsedServerTime = serverTime == null
        ? null
        : DateTime.tryParse(serverTime.trim());
    if (parsedServerTime == null) return;

    final newSkew = parsedServerTime.difference(receivedAt);
    if ((newSkew - _skew).abs() >= skewThreshold) {
      _skew = newSkew;
    }

    if (offsetSeconds == null) {
      _devOffset.value = Duration.zero;
    } else {
      final seconds = int.tryParse(offsetSeconds.trim());
      if (seconds != null) {
        _devOffset.value = Duration(seconds: seconds);
      }
    }
  }

  /// Restores the initial state (no skew, no dev offset).
  @visibleForTesting
  void reset() {
    _skew = Duration.zero;
    _devOffset.value = Duration.zero;
  }
}
