import 'package:eros_app/features/chat/data/models/chat_models.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_chat_repository.dart';

Map<String, dynamic> _dateDetailJson({Object? chat = _absent}) => {
      'dateId': 42,
      'matchId': 1042,
      'user1Id': 'me',
      'user2Id': 'alex',
      'partnerName': 'Alex',
      'partnerThumbnailUrl': null,
      'activityId': 2,
      'activityName': 'Drinks',
      'durationMinutes': 120,
      'tokenCost': '5.00',
      'cityId': 1,
      'cityName': 'London',
      'state': 'VENUE_ASSIGNED',
      'availabilityRound': 1,
      'scheduledStart': '2026-11-07T19:00:00Z',
      'scheduledEnd': '2026-11-07T21:00:00Z',
      'depositDeadline': null,
      'rankingDeadline': null,
      'venueId': null,
      'venueName': null,
      'venueAddress': null,
      'venuePriceRange': null,
      'venueMenuUrl': null,
      'venueBookedAt': null,
      'bookingReference': null,
      'depositStatus': {'user1': 'PAID', 'user2': 'PAID'},
      'cancellable': true,
      'timeline': [],
      'createdAt': '2026-11-01T10:00:00Z',
      'updatedAt': '2026-11-06T10:00:00Z',
      if (chat != _absent) 'chat': chat,
    };

const _absent = Object();

void main() {
  group('ChatStatus', () {
    test('reads every known value', () {
      expect(ChatStatus.fromWire('NOT_OPEN'), ChatStatus.notOpen);
      expect(ChatStatus.fromWire('OPEN'), ChatStatus.open);
      expect(ChatStatus.fromWire('CLOSED'), ChatStatus.closed);
      expect(ChatStatus.fromWire('ARCHIVED'), ChatStatus.archived);
    });

    test('reads an unknown value from a newer backend as closed', () {
      expect(ChatStatus.fromWire('PAUSED'), ChatStatus.closed);
      expect(ChatStatus.fromWire(null), ChatStatus.closed);
    });
  });

  group('ChatState', () {
    test('reads NOT_OPEN with null times', () {
      final chat = ChatState.fromJson(chatFixture('get_chat_not_open') as Map<String, dynamic>);

      expect(chat.status, ChatStatus.notOpen);
      expect(chat.closesAt, isNull);
      expect(chat.unreadCount, 0);
    });
  });

  group('ChatMessage', () {
    test('never prints its text', () {
      final page = ChatMessagesPage.fromJson(chatFixture('get_messages') as Map<String, dynamic>);

      expect(page.messages.first.toString(), isNot(contains('parking')));
    });
  });

  group('DateDetail.chat', () {
    test('reads the chat summary', () {
      final detail = DateDetail.fromJson(_dateDetailJson(chat: {
        'status': 'OPEN',
        'closesAt': '2026-11-07T21:00:00Z',
        'readableUntil': '2026-12-07T21:00:00Z',
      }));

      expect(detail.state, DateState.venueAssigned);
      expect(detail.chat.status, ChatStatus.open);
      expect(detail.chat.closesAt, DateTime.utc(2026, 11, 7, 21));
      expect(detail.chat.readableUntil, DateTime.utc(2026, 12, 7, 21));
    });

    test('is NOT_OPEN when an older backend doesn\'t send it', () {
      expect(DateDetail.fromJson(_dateDetailJson()).chat.status, ChatStatus.notOpen);
      expect(DateDetail.fromJson(_dateDetailJson(chat: null)).chat.status, ChatStatus.notOpen);
    });
  });
}
