import 'package:flutter/foundation.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';

/// A `PATCH /users/me/date-preferences` body holding exactly one section (RFC-005 D-2).
///
/// The section sent replaces the server's copy; sections left out are unchanged.
@immutable
sealed class SectionPatch {
  const SectionPatch();

  /// The section's key in the request body.
  String get section;

  Map<String, dynamic> toJson();
}

/// One dating city in a [WherePatch]: its id and the pin the user confirmed, if any.
@immutable
class WhereCityPatch {
  final int cityId;

  /// Null leaves the city without a pin, so the city centre is used. The server rounds it and
  /// works out the district.
  final GeoPoint? start;

  const WhereCityPatch({required this.cityId, this.start});

  Map<String, dynamic> toJson() => {'cityId': cityId, 'start': start?.toJson()};
}

/// Replaces the "Where" section: `{ "where": { "cities": [...], "maxTravelMeters": ... } }`.
class WherePatch extends SectionPatch {
  final List<WhereCityPatch> cities;

  /// Null means "Anywhere".
  final int? maxTravelMeters;

  const WherePatch({required this.cities, required this.maxTravelMeters});

  @override
  String get section => 'where';

  @override
  Map<String, dynamic> toJson() => {
        section: {
          'cities': cities.map((c) => c.toJson()).toList(),
          'maxTravelMeters': maxTravelMeters,
        },
      };

  @override
  String toString() => 'WherePatch(${cities.length} cities)';
}

/// Replaces the activity levels: `{ "activities": [{ "activityId": ..., "level": ... }] }`.
///
/// Activities left out go back to [PreferenceLevel.ok].
class ActivitiesPatch extends SectionPatch {
  final List<ActivityPreference> activities;

  const ActivitiesPatch(this.activities);

  @override
  String get section => 'activities';

  @override
  Map<String, dynamic> toJson() => {section: activities.map((a) => a.toJson()).toList()};
}

/// Replaces the "Dinner" section: `{ "food": { ... } }`.
class FoodPatch extends SectionPatch {
  final FoodPreferences food;

  const FoodPatch(this.food);

  @override
  String get section => 'food';

  @override
  Map<String, dynamic> toJson() => {section: food.toJson()};
}

/// Replaces the "Drinks" section: `{ "drinks": { ... } }`.
class DrinksPatch extends SectionPatch {
  final DrinksPreferences drinks;

  const DrinksPatch(this.drinks);

  @override
  String get section => 'drinks';

  @override
  Map<String, dynamic> toJson() => {section: drinks.toJson()};
}

/// Replaces "The venue" section: `{ "venue": { ... } }`.
class VenuePatch extends SectionPatch {
  final VenuePreferences venue;

  const VenuePatch(this.venue);

  @override
  String get section => 'venue';

  @override
  Map<String, dynamic> toJson() => {section: venue.toJson()};
}
