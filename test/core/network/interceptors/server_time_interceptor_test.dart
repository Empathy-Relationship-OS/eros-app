import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eros_app/core/network/interceptors/server_time_interceptor.dart';
import 'package:eros_app/core/time/server_clock.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns a canned response with the given status and headers.
class _FakeAdapter implements HttpClientAdapter {
  int statusCode = 200;
  Map<String, List<String>> headers = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({'ok': statusCode < 400}),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Formats [t] like the backend does: `2026-10-17T13:00:00.000Z`.
String _header(DateTime t) => t.toUtc().toIso8601String();

void main() {
  late _FakeAdapter adapter;

  Dio buildDio({
    ServerClock? clock,
    DateTime Function()? deviceNow,
    bool throwOn4xx = false,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:8080',
        // ApiClient only treats 5xx as errors. throwOn4xx exercises onError.
        validateStatus: (s) => s != null && s < (throwOn4xx ? 400 : 500),
      ),
    );
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(
      ServerTimeInterceptor(clock: clock, deviceNow: deviceNow),
    );
    return dio;
  }

  setUp(() {
    adapter = _FakeAdapter();
    ServerClock.instance.reset();
  });

  tearDown(() => ServerClock.instance.reset());

  group('with an injected device clock (exact)', () {
    final deviceNow = DateTime.utc(2026, 10, 16, 12);
    late ServerClock clock;

    setUp(() => clock = ServerClock(deviceNow: () => deviceNow));

    test('moves now() to the X-Server-Time from RFC-003 §5.6', () async {
      adapter.headers = {
        'X-Server-Time': ['2026-10-17T13:00:00.000Z'],
        'X-Clock-Offset-Seconds': ['90000'],
      };

      await buildDio(clock: clock, deviceNow: () => deviceNow).get('/x');

      expect(clock.now(), DateTime.utc(2026, 10, 17, 13));
      expect(clock.devOffset.value, const Duration(seconds: 90000));
    });

    test(
      'resets devOffset when a later response has no offset header',
      () async {
        final dio = buildDio(clock: clock, deviceNow: () => deviceNow);
        adapter.headers = {
          'X-Server-Time': ['2026-10-17T13:00:00.000Z'],
          'X-Clock-Offset-Seconds': ['90000'],
        };
        await dio.get('/x');

        adapter.headers = {
          'X-Server-Time': ['2026-10-16T12:00:00.000Z'],
        };
        await dio.get('/x');

        expect(clock.devOffset.value, Duration.zero);
        expect(clock.now(), deviceNow);
      },
    );

    test('keeps the previous skew when the header is missing', () async {
      final dio = buildDio(clock: clock, deviceNow: () => deviceNow);
      adapter.headers = {
        'X-Server-Time': ['2026-10-16T13:00:00.000Z'],
      };
      await dio.get('/x');

      adapter.headers = {};
      await dio.get('/x');

      expect(clock.now(), DateTime.utc(2026, 10, 16, 13));
    });
  });

  group('ServerClock.instance', () {
    test('moves forward after a 200 response', () async {
      final serverTime = DateTime.now().toUtc().add(const Duration(hours: 25));
      adapter.headers = {
        'X-Server-Time': [_header(serverTime)],
        'X-Clock-Offset-Seconds': ['90000'],
      };

      await buildDio().get('/x');

      final ahead = ServerClock.instance.now().difference(DateTime.now());
      expect(ahead.inSeconds, closeTo(const Duration(hours: 25).inSeconds, 5));
      expect(
        ServerClock.instance.devOffset.value,
        const Duration(seconds: 90000),
      );
    });

    test(
      'moves forward on a 409 that ApiClient passes to onResponse',
      () async {
        final serverTime = DateTime.now().toUtc().add(
          const Duration(hours: 25),
        );
        adapter
          ..statusCode = 409
          ..headers = {
            'X-Server-Time': [_header(serverTime)],
          };

        final response = await buildDio().get('/x');

        expect(response.statusCode, 409);
        final ahead = ServerClock.instance.now().difference(DateTime.now());
        expect(
          ahead.inSeconds,
          closeTo(const Duration(hours: 25).inSeconds, 5),
        );
      },
    );

    test('moves forward on a 409 delivered through onError', () async {
      final serverTime = DateTime.now().toUtc().add(const Duration(hours: 25));
      adapter
        ..statusCode = 409
        ..headers = {
          'X-Server-Time': [_header(serverTime)],
          'X-Clock-Offset-Seconds': ['90000'],
        };

      await expectLater(
        buildDio(throwOn4xx: true).get('/x'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            409,
          ),
        ),
      );

      final ahead = ServerClock.instance.now().difference(DateTime.now());
      expect(ahead.inSeconds, closeTo(const Duration(hours: 25).inSeconds, 5));
      expect(
        ServerClock.instance.devOffset.value,
        const Duration(seconds: 90000),
      );
    });
  });
}
