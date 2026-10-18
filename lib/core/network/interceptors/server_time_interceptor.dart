import 'package:dio/dio.dart';

import '../../time/server_clock.dart';

/// Feeds `X-Server-Time` and `X-Clock-Offset-Seconds` from every response into
/// [ServerClock] (RFC-003 §5.6).
///
/// Error responses carry the headers too (a 409 still has the server time), so
/// [onError] reads them whenever `err.response` is present.
class ServerTimeInterceptor extends Interceptor {
  static const String serverTimeHeader = 'x-server-time';
  static const String clockOffsetHeader = 'x-clock-offset-seconds';

  final ServerClock _clock;
  final DateTime Function() _deviceNow;

  ServerTimeInterceptor({ServerClock? clock, DateTime Function()? deviceNow})
    : _clock = clock ?? ServerClock.instance,
      _deviceNow = deviceNow ?? DateTime.now;

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _update(response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response != null) {
      _update(response);
    }
    handler.next(err);
  }

  void _update(Response response) {
    _clock.updateFromHeaders(
      serverTime: response.headers.value(serverTimeHeader),
      offsetSeconds: response.headers.value(clockOffsetHeader),
      receivedAt: _deviceNow(),
    );
  }
}
