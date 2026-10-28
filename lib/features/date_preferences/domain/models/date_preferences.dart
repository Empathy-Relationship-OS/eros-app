import 'package:flutter/foundation.dart';

/// How much a user wants one kind of date (RFC-005 §4.2, "Date types").
///
/// The only Dart enum in this feature: every other option value is a string from
/// `GET /date-preferences/options` (RFC-005 D-8).
enum PreferenceLevel {
  love('LOVE'),
  ok('OK'),
  no('NO');

  const PreferenceLevel(this.value);

  /// The value the API uses.
  final String value;

  /// Throws an [ArgumentError] for a value the app doesn't know.
  static PreferenceLevel fromValue(String value) {
    return PreferenceLevel.values.firstWhere(
      (level) => level.value == value,
      orElse: () => throw ArgumentError.value(value, 'level', 'Unknown preference level'),
    );
  }
}

/// A latitude and longitude, in degrees.
@immutable
class GeoPoint {
  final double latitude;
  final double longitude;

  const GeoPoint({required this.latitude, required this.longitude});

  factory GeoPoint.fromJson(Map<String, dynamic> json) {
    return GeoPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'latitude': latitude, 'longitude': longitude};

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  // Coordinates are private (RFC-005 §4.4), so they never reach a log through toString.
  @override
  String toString() => 'GeoPoint(<redacted>)';
}

/// The district a starting point falls in, as the server worked it out.
@immutable
class DistrictRef {
  final int districtId;
  final String name;

  const DistrictRef({required this.districtId, required this.name});

  factory DistrictRef.fromJson(Map<String, dynamic> json) {
    return DistrictRef(
      districtId: json['districtId'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'districtId': districtId, 'name': name};

  @override
  bool operator ==(Object other) =>
      other is DistrictRef && other.districtId == districtId && other.name == name;

  @override
  int get hashCode => Object.hash(districtId, name);
}

/// The pin a user starts their dates from in one city, rounded by the server to 3 decimal places.
@immutable
class StartPoint {
  final double latitude;
  final double longitude;

  /// Null only if the city has no districts yet.
  final DistrictRef? district;

  const StartPoint({required this.latitude, required this.longitude, this.district});

  factory StartPoint.fromJson(Map<String, dynamic> json) {
    final district = json['district'] as Map<String, dynamic>?;
    return StartPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      district: district == null ? null : DistrictRef.fromJson(district),
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'district': district?.toJson(),
      };

  GeoPoint get point => GeoPoint(latitude: latitude, longitude: longitude);

  StartPoint copyWith({
    double? latitude,
    double? longitude,
    DistrictRef? district,
    bool clearDistrict = false,
  }) {
    return StartPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      district: clearDistrict ? null : (district ?? this.district),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StartPoint &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.district == district;

  @override
  int get hashCode => Object.hash(latitude, longitude, district);

  @override
  String toString() => 'StartPoint(<redacted>, district: ${district?.districtId})';
}

/// One of the user's dating cities and their starting point in it.
@immutable
class DatingCityPreference {
  final int cityId;
  final String cityName;

  /// Null when the user hasn't placed a pin; the city centre is used.
  final StartPoint? start;

  const DatingCityPreference({required this.cityId, required this.cityName, this.start});

  factory DatingCityPreference.fromJson(Map<String, dynamic> json) {
    final start = json['start'] as Map<String, dynamic>?;
    return DatingCityPreference(
      cityId: json['cityId'] as int,
      cityName: json['cityName'] as String,
      start: start == null ? null : StartPoint.fromJson(start),
    );
  }

  Map<String, dynamic> toJson() => {
        'cityId': cityId,
        'cityName': cityName,
        'start': start?.toJson(),
      };

  DatingCityPreference copyWith({
    int? cityId,
    String? cityName,
    StartPoint? start,
    bool clearStart = false,
  }) {
    return DatingCityPreference(
      cityId: cityId ?? this.cityId,
      cityName: cityName ?? this.cityName,
      start: clearStart ? null : (start ?? this.start),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DatingCityPreference &&
      other.cityId == cityId &&
      other.cityName == cityName &&
      other.start == start;

  @override
  int get hashCode => Object.hash(cityId, cityName, start);
}

/// The "Where" section: dating cities, a starting point per city, and travel distance.
@immutable
class WherePreferences {
  final List<DatingCityPreference> cities;

  /// Null means "Anywhere". Always metres, whatever unit the user saw.
  final int? maxTravelMeters;

  WherePreferences({required List<DatingCityPreference> cities, this.maxTravelMeters})
      : cities = List.unmodifiable(cities);

  factory WherePreferences.fromJson(Map<String, dynamic> json) {
    return WherePreferences(
      cities: (json['cities'] as List<dynamic>)
          .map((c) => DatingCityPreference.fromJson(c as Map<String, dynamic>))
          .toList(),
      maxTravelMeters: json['maxTravelMeters'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'cities': cities.map((c) => c.toJson()).toList(),
        'maxTravelMeters': maxTravelMeters,
      };

  WherePreferences copyWith({
    List<DatingCityPreference>? cities,
    int? maxTravelMeters,
    bool clearMaxTravelMeters = false,
  }) {
    return WherePreferences(
      cities: cities ?? this.cities,
      maxTravelMeters: clearMaxTravelMeters ? null : (maxTravelMeters ?? this.maxTravelMeters),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WherePreferences &&
      listEquals(other.cities, cities) &&
      other.maxTravelMeters == maxTravelMeters;

  @override
  int get hashCode => Object.hash(Object.hashAll(cities), maxTravelMeters);
}

/// The user's level for one activity. Activities without a row are [PreferenceLevel.ok].
@immutable
class ActivityPreference {
  final int activityId;
  final PreferenceLevel level;

  const ActivityPreference({required this.activityId, required this.level});

  factory ActivityPreference.fromJson(Map<String, dynamic> json) {
    return ActivityPreference(
      activityId: json['activityId'] as int,
      level: PreferenceLevel.fromValue(json['level'] as String),
    );
  }

  Map<String, dynamic> toJson() => {'activityId': activityId, 'level': level.value};

  ActivityPreference copyWith({int? activityId, PreferenceLevel? level}) {
    return ActivityPreference(
      activityId: activityId ?? this.activityId,
      level: level ?? this.level,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ActivityPreference && other.activityId == activityId && other.level == level;

  @override
  int get hashCode => Object.hash(activityId, level);
}

/// The "Dinner" section. Values are `Cuisine` and `DietaryOption` names from the options list.
@immutable
class FoodPreferences {
  final List<String> cuisinesLoved;
  final List<String> cuisinesExcluded;
  final List<String> dietaryNeeds;

  FoodPreferences({
    List<String> cuisinesLoved = const [],
    List<String> cuisinesExcluded = const [],
    List<String> dietaryNeeds = const [],
  })  : cuisinesLoved = List.unmodifiable(cuisinesLoved),
        cuisinesExcluded = List.unmodifiable(cuisinesExcluded),
        dietaryNeeds = List.unmodifiable(dietaryNeeds);

  factory FoodPreferences.fromJson(Map<String, dynamic> json) {
    return FoodPreferences(
      cuisinesLoved: _strings(json['cuisinesLoved']),
      cuisinesExcluded: _strings(json['cuisinesExcluded']),
      dietaryNeeds: _strings(json['dietaryNeeds']),
    );
  }

  Map<String, dynamic> toJson() => {
        'cuisinesLoved': List<String>.of(cuisinesLoved),
        'cuisinesExcluded': List<String>.of(cuisinesExcluded),
        'dietaryNeeds': List<String>.of(dietaryNeeds),
      };

  FoodPreferences copyWith({
    List<String>? cuisinesLoved,
    List<String>? cuisinesExcluded,
    List<String>? dietaryNeeds,
  }) {
    return FoodPreferences(
      cuisinesLoved: cuisinesLoved ?? this.cuisinesLoved,
      cuisinesExcluded: cuisinesExcluded ?? this.cuisinesExcluded,
      dietaryNeeds: dietaryNeeds ?? this.dietaryNeeds,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FoodPreferences &&
      listEquals(other.cuisinesLoved, cuisinesLoved) &&
      listEquals(other.cuisinesExcluded, cuisinesExcluded) &&
      listEquals(other.dietaryNeeds, dietaryNeeds);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(cuisinesLoved),
        Object.hashAll(cuisinesExcluded),
        Object.hashAll(dietaryNeeds),
      );

  // Dietary needs and excluded cuisines can reveal religion, so they stay out of logs.
  @override
  String toString() => 'FoodPreferences(<redacted>)';
}

/// The "Drinks" section. Values are `DrinkStyle` names from the options list.
@immutable
class DrinksPreferences {
  final List<String> drinkStyles;
  final bool wantsAlcoholFree;

  DrinksPreferences({List<String> drinkStyles = const [], this.wantsAlcoholFree = false})
      : drinkStyles = List.unmodifiable(drinkStyles);

  factory DrinksPreferences.fromJson(Map<String, dynamic> json) {
    return DrinksPreferences(
      drinkStyles: _strings(json['drinkStyles']),
      wantsAlcoholFree: json['wantsAlcoholFree'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'drinkStyles': List<String>.of(drinkStyles),
        'wantsAlcoholFree': wantsAlcoholFree,
      };

  DrinksPreferences copyWith({List<String>? drinkStyles, bool? wantsAlcoholFree}) {
    return DrinksPreferences(
      drinkStyles: drinkStyles ?? this.drinkStyles,
      wantsAlcoholFree: wantsAlcoholFree ?? this.wantsAlcoholFree,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DrinksPreferences &&
      listEquals(other.drinkStyles, drinkStyles) &&
      other.wantsAlcoholFree == wantsAlcoholFree;

  @override
  int get hashCode => Object.hash(Object.hashAll(drinkStyles), wantsAlcoholFree);
}

/// "The venue" section. Values are `PriceRange`, atmosphere and setting names from the options
/// list.
@immutable
class VenuePreferences {
  final List<String> priceRanges;
  final String atmosphere;
  final String setting;
  final bool needsStepFree;

  VenuePreferences({
    required List<String> priceRanges,
    required this.atmosphere,
    required this.setting,
    required this.needsStepFree,
  }) : priceRanges = List.unmodifiable(priceRanges);

  factory VenuePreferences.fromJson(Map<String, dynamic> json) {
    return VenuePreferences(
      priceRanges: _strings(json['priceRanges']),
      atmosphere: json['atmosphere'] as String,
      setting: json['setting'] as String,
      needsStepFree: json['needsStepFree'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'priceRanges': List<String>.of(priceRanges),
        'atmosphere': atmosphere,
        'setting': setting,
        'needsStepFree': needsStepFree,
      };

  VenuePreferences copyWith({
    List<String>? priceRanges,
    String? atmosphere,
    String? setting,
    bool? needsStepFree,
  }) {
    return VenuePreferences(
      priceRanges: priceRanges ?? this.priceRanges,
      atmosphere: atmosphere ?? this.atmosphere,
      setting: setting ?? this.setting,
      needsStepFree: needsStepFree ?? this.needsStepFree,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VenuePreferences &&
      listEquals(other.priceRanges, priceRanges) &&
      other.atmosphere == atmosphere &&
      other.setting == setting &&
      other.needsStepFree == needsStepFree;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(priceRanges), atmosphere, setting, needsStepFree);

  // Step-free access can reveal a disability, so it stays out of logs.
  @override
  String toString() => 'VenuePreferences(<redacted>)';
}

/// A user's date preferences, from `GET /users/me/date-preferences` (RFC-005 §5).
///
/// Private to its owner. Never log its contents: the pin is close to home, and dietary needs,
/// excluded cuisines and step-free access can reveal religion or disability.
@immutable
class DatePreferences {
  /// False when the user has never saved; the sections then hold the defaults.
  final bool isSet;

  /// Null when the user has never saved.
  final DateTime? updatedAt;

  final WherePreferences where;

  /// Only the activities the user has set. Use [levelFor] to read one.
  final List<ActivityPreference> activities;

  final FoodPreferences food;
  final DrinksPreferences drinks;
  final VenuePreferences venue;

  DatePreferences({
    required this.isSet,
    this.updatedAt,
    required this.where,
    required List<ActivityPreference> activities,
    required this.food,
    required this.drinks,
    required this.venue,
  }) : activities = List.unmodifiable(activities);

  factory DatePreferences.fromJson(Map<String, dynamic> json) {
    final updatedAt = json['updatedAt'] as String?;
    return DatePreferences(
      isSet: json['isSet'] as bool,
      updatedAt: updatedAt == null ? null : DateTime.parse(updatedAt),
      where: WherePreferences.fromJson(json['where'] as Map<String, dynamic>),
      activities: (json['activities'] as List<dynamic>)
          .map((a) => ActivityPreference.fromJson(a as Map<String, dynamic>))
          .toList(),
      food: FoodPreferences.fromJson(json['food'] as Map<String, dynamic>),
      drinks: DrinksPreferences.fromJson(json['drinks'] as Map<String, dynamic>),
      venue: VenuePreferences.fromJson(json['venue'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'isSet': isSet,
        'updatedAt': updatedAt?.toUtc().toIso8601String().replaceFirst('.000Z', 'Z'),
        'where': where.toJson(),
        'activities': activities.map((a) => a.toJson()).toList(),
        'food': food.toJson(),
        'drinks': drinks.toJson(),
        'venue': venue.toJson(),
      };

  /// The user's level for [activityId]; [PreferenceLevel.ok] when they haven't set one.
  PreferenceLevel levelFor(int activityId) {
    for (final activity in activities) {
      if (activity.activityId == activityId) return activity.level;
    }
    return PreferenceLevel.ok;
  }

  DatePreferences copyWith({
    bool? isSet,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
    WherePreferences? where,
    List<ActivityPreference>? activities,
    FoodPreferences? food,
    DrinksPreferences? drinks,
    VenuePreferences? venue,
  }) {
    return DatePreferences(
      isSet: isSet ?? this.isSet,
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
      where: where ?? this.where,
      activities: activities ?? this.activities,
      food: food ?? this.food,
      drinks: drinks ?? this.drinks,
      venue: venue ?? this.venue,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DatePreferences &&
      other.isSet == isSet &&
      other.updatedAt == updatedAt &&
      other.where == where &&
      listEquals(other.activities, activities) &&
      other.food == food &&
      other.drinks == drinks &&
      other.venue == venue;

  @override
  int get hashCode => Object.hash(
        isSet,
        updatedAt,
        where,
        Object.hashAll(activities),
        food,
        drinks,
        venue,
      );

  @override
  String toString() => 'DatePreferences(isSet: $isSet, <redacted>)';
}

List<String> _strings(Object? json) => (json as List<dynamic>).cast<String>();
