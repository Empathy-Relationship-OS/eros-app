import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Payloads match the backend's DTOs (DP-B11): `priceRange` / `menuUrl` on a venue, and
/// `venuePriceRange` / `venueMenuUrl` on the flat date detail.
Map<String, dynamic> _option({String? menuUrl}) => {
      'venueId': 1,
      'name': 'The Ivy',
      'address': '1 West St',
      'thumbnailUrl': null,
      'optionOrder': 1,
      'priceRange': {'value': 'MID_RANGE', 'symbol': r'$$'},
      'menuUrl': menuUrl,
    };

Map<String, dynamic> _venueDetails({String? menuUrl}) => {
      'venueId': 1,
      'name': 'The Ivy',
      'address': '1 West St',
      'description': 'A classic',
      'imageUrl': null,
      'dressCode': 'SMART_CASUAL',
      'websiteUrl': 'https://theivy.example',
      'priceRange': {'value': 'LUXURY', 'symbol': '££££'},
      'menuUrl': menuUrl,
    };

Map<String, dynamic> _dateDetail({Map<String, dynamic>? priceRange, String? menuUrl}) => {
      'dateId': 7,
      'matchId': 1007,
      'user1Id': 'user1',
      'user2Id': 'user2',
      'partnerName': 'Sam',
      'partnerThumbnailUrl': null,
      'activityId': 1,
      'activityName': 'Dinner',
      'tokenCost': '1.00',
      'cityId': 1,
      'cityName': 'London',
      'state': 'BOOKED',
      'availabilityRound': 1,
      'venuePriceRange': priceRange,
      'venueMenuUrl': menuUrl,
      'depositStatus': {'user1': 'PAID', 'user2': 'PAID'},
      'cancellable': false,
      'timeline': <Object>[],
      'createdAt': '2026-10-23T10:00:00Z',
      'updatedAt': '2026-10-23T10:00:00Z',
    };

void main() {
  group('VenueOption', () {
    test('reads the price band and menu link', () {
      final option = VenueOption.fromJson(_option(menuUrl: 'https://theivy.example/menu'));

      expect(option.priceRange.value, 'MID_RANGE');
      expect(option.priceRange.symbol, r'$$');
      expect(option.menuUrl, 'https://theivy.example/menu');
    });

    test('has no menu link when the server sends null', () {
      expect(VenueOption.fromJson(_option()).menuUrl, isNull);
    });
  });

  group('VenuePublicInfo', () {
    test('reads the price band and menu link', () {
      final venue = VenuePublicInfo.fromJson(_venueDetails(menuUrl: 'https://theivy.example/menu'));

      expect(venue.priceRange.value, 'LUXURY');
      expect(venue.priceRange.symbol, '££££');
      expect(venue.menuUrl, 'https://theivy.example/menu');
    });

    test('has no menu link when the server sends null', () {
      expect(VenuePublicInfo.fromJson(_venueDetails()).menuUrl, isNull);
    });
  });

  group('DateDetail', () {
    test('reads the assigned venue\'s price band and menu link', () {
      final date = DateDetail.fromJson(_dateDetail(
        priceRange: {'value': 'BUDGET', 'symbol': '£'},
        menuUrl: 'https://theivy.example/menu',
      ));

      expect(date.venuePriceRange?.value, 'BUDGET');
      expect(date.venuePriceRange?.symbol, '£');
      expect(date.venueMenuUrl, 'https://theivy.example/menu');
    });

    test('has neither until a venue is assigned', () {
      final date = DateDetail.fromJson(_dateDetail());

      expect(date.venuePriceRange, isNull);
      expect(date.venueMenuUrl, isNull);
    });
  });
}
