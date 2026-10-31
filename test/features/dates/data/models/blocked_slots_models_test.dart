import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _availability({List<Map<String, dynamic>> blockedSlots = const []}) => {
      'dateId': 7,
      'activityName': 'Dinner',
      'durationMinutes': 120,
      'currentRound': 1,
      'mySlots': <Object>[],
      'partnerSlots': <Object>[],
      'blockedSlots': blockedSlots,
    };

Map<String, dynamic> _blocked(String? code) => {
      'slotStart': '2026-11-20T19:00:00Z',
      'code': code,
      'reason': 'From the server',
    };

Map<String, dynamic> _dateDetail({
  required int durationMinutes,
  String? scheduledStart,
  String? scheduledEnd,
}) =>
    {
      'dateId': 7,
      'matchId': 1007,
      'user1Id': 'user1',
      'user2Id': 'user2',
      'partnerName': 'Sam',
      'partnerThumbnailUrl': null,
      'activityId': 1,
      'activityName': 'Coffee',
      'durationMinutes': durationMinutes,
      'tokenCost': '0.50',
      'cityId': 1,
      'cityName': 'London',
      'state': 'AWAITING_DEPOSIT',
      'availabilityRound': 1,
      'scheduledStart': scheduledStart,
      'scheduledEnd': scheduledEnd,
      'depositStatus': {'user1': 'PENDING', 'user2': 'PENDING'},
      'cancellable': true,
      'timeline': <Object>[],
      'createdAt': '2026-10-23T10:00:00Z',
      'updatedAt': '2026-10-23T10:00:00Z',
    };

void main() {
  group('BlockedSlotDto.fromJson', () {
    test('reads both codes', () {
      expect(BlockedSlotDto.fromJson(_blocked('ANOTHER_DATE')).code, BlockedSlotCode.anotherDate);
      expect(
        BlockedSlotDto.fromJson(_blocked('ACTIVITY_CLOSED')).code,
        BlockedSlotCode.activityClosed,
      );
    });

    test('a new code is unknown, not a parse failure, and keeps the reason', () {
      final slot = BlockedSlotDto.fromJson(_blocked('VENUE_ON_FIRE'));

      expect(slot.code, BlockedSlotCode.unknown);
      expect(slot.reason, 'From the server');
    });

    test('a missing code is unknown', () {
      expect(BlockedSlotDto.fromJson(_blocked(null)).code, BlockedSlotCode.unknown);
    });
  });

  group('AvailabilityView.fromJson', () {
    test('reads the activity and length', () {
      final view = AvailabilityView.fromJson(_availability());

      expect(view.activityName, 'Dinner');
      expect(view.durationMinutes, 120);
    });

    test('indexes blocked slots by UTC start', () {
      final view = AvailabilityView.fromJson(_availability(
        blockedSlots: [_blocked('ACTIVITY_CLOSED')],
      ));

      expect(
        view.blockedByStart[DateTime.utc(2026, 11, 20, 19)]?.code,
        BlockedSlotCode.activityClosed,
      );
      expect(view.blockedByStart[DateTime.utc(2026, 11, 20, 19, 30)], isNull);
    });

    test('needs DP-B10: a response without the activity and length does not parse', () {
      final json = _availability()..remove('durationMinutes');

      expect(() => AvailabilityView.fromJson(json), throwsA(isA<TypeError>()));
    });
  });

  group('DateDetail', () {
    test('reads the length', () {
      expect(DateDetail.fromJson(_dateDetail(durationMinutes: 90)).durationMinutes, 90);
    });

    test('has no end time until a time is agreed', () {
      expect(DateDetail.fromJson(_dateDetail(durationMinutes: 90)).endTime, isNull);
    });

    test('ends at scheduledEnd', () {
      final date = DateDetail.fromJson(_dateDetail(
        durationMinutes: 90,
        scheduledStart: '2026-11-20T19:00:00Z',
        scheduledEnd: '2026-11-20T20:30:00Z',
      ));

      expect(date.endTime, DateTime.utc(2026, 11, 20, 20, 30));
    });

    test('falls back to the length when scheduledEnd is missing', () {
      final date = DateDetail.fromJson(_dateDetail(
        durationMinutes: 90,
        scheduledStart: '2026-11-20T19:00:00Z',
      ));

      expect(date.endTime, DateTime.utc(2026, 11, 20, 20, 30));
    });
  });

  group('DatesCopy.availabilityDateSummary', () {
    test('says whole hours in hours', () {
      expect(DatesCopy.availabilityDateSummary('Dinner', 120), 'Dinner, about 2 hours');
      expect(DatesCopy.availabilityDateSummary('Drinks', 60), 'Drinks, about 1 hour');
    });

    test('keeps anything else in minutes', () {
      expect(DatesCopy.availabilityDateSummary('Coffee', 90), 'Coffee, about 90 minutes');
    });
  });
}
