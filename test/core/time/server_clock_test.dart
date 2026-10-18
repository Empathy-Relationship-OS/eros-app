import 'package:eros_app/core/time/server_clock.dart';
import 'package:eros_app/core/time/server_clock_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Device clock frozen at a fixed instant so every assertion is exact.
  final deviceNow = DateTime.utc(2026, 10, 16, 12);
  late ServerClock clock;

  setUp(() {
    clock = ServerClock(deviceNow: () => deviceNow);
  });

  group('ServerClock.now', () {
    test('equals device time in UTC before any header is seen', () {
      expect(clock.now(), deviceNow);
      expect(clock.now().isUtc, isTrue);
      expect(clock.skew, Duration.zero);
    });

    test('applies the skew between X-Server-Time and receivedAt', () {
      clock.updateFromHeaders(
        serverTime: '2026-10-17T13:00:00.000Z',
        offsetSeconds: null,
        receivedAt: deviceNow,
      );

      expect(clock.skew, const Duration(hours: 25));
      expect(clock.now(), DateTime.utc(2026, 10, 17, 13));
    });

    test('applies a negative skew when the device clock runs fast', () {
      clock.updateFromHeaders(
        serverTime: '2026-10-16T11:55:00Z',
        offsetSeconds: null,
        receivedAt: deviceNow,
      );

      expect(clock.now(), DateTime.utc(2026, 10, 16, 11, 55));
    });

    test('ignores a skew change under 2 seconds', () {
      clock.updateFromHeaders(
        serverTime: '2026-10-16T12:10:00Z',
        offsetSeconds: null,
        receivedAt: deviceNow,
      );
      clock.updateFromHeaders(
        serverTime: '2026-10-16T12:10:01.900Z',
        offsetSeconds: null,
        receivedAt: deviceNow,
      );

      expect(clock.skew, const Duration(minutes: 10));
    });

    test('ignores an initial skew under 2 seconds', () {
      clock.updateFromHeaders(
        serverTime: '2026-10-16T12:00:01.500Z',
        offsetSeconds: null,
        receivedAt: deviceNow,
      );

      expect(clock.now(), deviceNow);
    });

    test('accepts a skew change of 2 seconds or more', () {
      clock.updateFromHeaders(
        serverTime: '2026-10-16T12:00:02Z',
        offsetSeconds: null,
        receivedAt: deviceNow,
      );

      expect(clock.skew, const Duration(seconds: 2));
    });

    test('keeps the previous skew when X-Server-Time is missing', () {
      clock.updateFromHeaders(
        serverTime: '2026-10-16T13:00:00Z',
        offsetSeconds: null,
        receivedAt: deviceNow,
      );
      clock.updateFromHeaders(
        serverTime: null,
        offsetSeconds: null,
        receivedAt: deviceNow,
      );

      expect(clock.skew, const Duration(hours: 1));
    });

    test('keeps the previous skew when X-Server-Time is unparsable', () {
      clock.updateFromHeaders(
        serverTime: '2026-10-16T13:00:00Z',
        offsetSeconds: null,
        receivedAt: deviceNow,
      );
      clock.updateFromHeaders(
        serverTime: 'not-a-date',
        offsetSeconds: null,
        receivedAt: deviceNow,
      );

      expect(clock.skew, const Duration(hours: 1));
    });
  });

  group('ServerClock.devOffset', () {
    test('is zero by default', () {
      expect(clock.devOffset.value, Duration.zero);
    });

    test('is set from X-Clock-Offset-Seconds', () {
      clock.updateFromHeaders(
        serverTime: '2026-10-17T13:00:00Z',
        offsetSeconds: '90000',
        receivedAt: deviceNow,
      );

      expect(clock.devOffset.value, const Duration(seconds: 90000));
    });

    test('resets to zero when X-Clock-Offset-Seconds is absent', () {
      clock.updateFromHeaders(
        serverTime: '2026-10-17T13:00:00Z',
        offsetSeconds: '90000',
        receivedAt: deviceNow,
      );
      clock.updateFromHeaders(
        serverTime: '2026-10-16T12:00:00Z',
        offsetSeconds: null,
        receivedAt: deviceNow,
      );

      expect(clock.devOffset.value, Duration.zero);
    });

    test('ignores an unparsable X-Clock-Offset-Seconds', () {
      clock.updateFromHeaders(
        serverTime: '2026-10-17T13:00:00Z',
        offsetSeconds: '90000',
        receivedAt: deviceNow,
      );
      clock.updateFromHeaders(
        serverTime: '2026-10-17T13:00:00Z',
        offsetSeconds: 'abc',
        receivedAt: deviceNow,
      );

      expect(clock.devOffset.value, const Duration(seconds: 90000));
    });

    test('is left alone when X-Server-Time is missing', () {
      clock.updateFromHeaders(
        serverTime: '2026-10-17T13:00:00Z',
        offsetSeconds: '90000',
        receivedAt: deviceNow,
      );
      clock.updateFromHeaders(
        serverTime: null,
        offsetSeconds: null,
        receivedAt: deviceNow,
      );

      expect(clock.devOffset.value, const Duration(seconds: 90000));
    });

    test('notifies listeners when it changes', () {
      var notifications = 0;
      clock.devOffset.addListener(() => notifications++);

      clock.updateFromHeaders(
        serverTime: '2026-10-17T13:00:00Z',
        offsetSeconds: '3600',
        receivedAt: deviceNow,
      );

      expect(notifications, 1);
    });
  });

  group('devClockOffsetProvider', () {
    test('tracks ServerClock.devOffset', () {
      final container = ProviderContainer(
        overrides: [serverClockProvider.overrideWithValue(clock)],
      );
      addTearDown(container.dispose);

      expect(container.read(devClockOffsetProvider), Duration.zero);

      final seen = <Duration>[];
      container.listen<Duration>(
        devClockOffsetProvider,
        (_, next) => seen.add(next),
      );

      clock.updateFromHeaders(
        serverTime: '2026-10-17T13:00:00Z',
        offsetSeconds: '90000',
        receivedAt: deviceNow,
      );
      expect(
        container.read(devClockOffsetProvider),
        const Duration(seconds: 90000),
      );

      clock.updateFromHeaders(
        serverTime: '2026-10-16T12:00:00Z',
        offsetSeconds: null,
        receivedAt: deviceNow,
      );
      expect(container.read(devClockOffsetProvider), Duration.zero);
      expect(seen, [const Duration(seconds: 90000), Duration.zero]);
    });

    test('serverClockProvider defaults to the shared instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(serverClockProvider), same(ServerClock.instance));
    });
  });
}
