import 'package:eros_app/features/dates/presentation/widgets/date_formats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateFormats.formatTimeRemaining', () {
    // Fixed reference time, deliberately far from the device clock, so the
    // tests fail if the helper ever reads DateTime.now() again.
    final now = DateTime.utc(2030, 1, 1, 12);

    test('shows days and hours against the given now', () {
      final deadline = now.add(const Duration(days: 2, hours: 3, minutes: 10));

      expect(DateFormats.formatTimeRemaining(deadline, now: now), '2d 3h left');
    });

    test('shows hours and minutes under a day', () {
      final deadline = now.add(const Duration(hours: 5, minutes: 12));

      expect(
        DateFormats.formatTimeRemaining(deadline, now: now),
        '5h 12m left',
      );
    });

    test('shows minutes under an hour', () {
      final deadline = now.add(const Duration(minutes: 7, seconds: 30));

      expect(DateFormats.formatTimeRemaining(deadline, now: now), '7m left');
    });

    test('shows under a minute', () {
      final deadline = now.add(const Duration(seconds: 30));

      expect(
        DateFormats.formatTimeRemaining(deadline, now: now),
        'Under a minute',
      );
    });

    test("shows time's up once the deadline has passed", () {
      final deadline = now.subtract(const Duration(minutes: 1));

      expect(DateFormats.formatTimeRemaining(deadline, now: now), "Time's up");
    });

    test('a 25h advance of now removes 25h from the countdown', () {
      final deadline = now.add(const Duration(days: 3, hours: 4));
      final advanced = now.add(const Duration(hours: 25));

      expect(DateFormats.formatTimeRemaining(deadline, now: now), '3d 4h left');
      expect(
        DateFormats.formatTimeRemaining(deadline, now: advanced),
        '2d 3h left',
      );
    });

    test('compares instants, so a local deadline and a UTC now agree', () {
      final deadline = now.add(const Duration(hours: 2)).toLocal();

      expect(DateFormats.formatTimeRemaining(deadline, now: now), '2h 0m left');
    });
  });
}
