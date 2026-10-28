import 'package:flutter/foundation.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';

/// One choice in an option list: the value the API uses and the text to show.
@immutable
class OptionValue {
  final String value;
  final String displayName;

  const OptionValue({required this.value, required this.displayName});

  factory OptionValue.fromJson(Map<String, dynamic> json) {
    return OptionValue(
      value: json['value'] as String,
      displayName: json['displayName'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'value': value, 'displayName': displayName};

  @override
  bool operator ==(Object other) =>
      other is OptionValue && other.value == value && other.displayName == displayName;

  @override
  int get hashCode => Object.hash(value, displayName);
}

/// A price band, with its symbol in the city's currency ("££").
@immutable
class PriceRangeOption {
  final String value;
  final String symbol;
  final String displayName;

  const PriceRangeOption({required this.value, required this.symbol, required this.displayName});

  factory PriceRangeOption.fromJson(Map<String, dynamic> json) {
    return PriceRangeOption(
      value: json['value'] as String,
      symbol: json['symbol'] as String,
      displayName: json['displayName'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'value': value, 'symbol': symbol, 'displayName': displayName};

  @override
  bool operator ==(Object other) =>
      other is PriceRangeOption &&
      other.value == value &&
      other.symbol == symbol &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(value, symbol, displayName);
}

/// A kind of date users can rate (Coffee, Drinks, Dinner, and later more).
@immutable
class DateActivityOption {
  final int activityId;
  final String name;
  final String category;

  /// `ACTIVE` or `COMING_SOON`. Users can rate either (RFC-005 D-7).
  final String status;

  final double tokenCost;
  final int durationMinutes;
  final String? description;
  final String? iconUrl;

  const DateActivityOption({
    required this.activityId,
    required this.name,
    required this.category,
    required this.status,
    required this.tokenCost,
    required this.durationMinutes,
    this.description,
    this.iconUrl,
  });

  factory DateActivityOption.fromJson(Map<String, dynamic> json) {
    return DateActivityOption(
      activityId: json['activityId'] as int,
      name: json['name'] as String,
      category: json['category'] as String,
      status: json['status'] as String,
      tokenCost: (json['tokenCost'] as num).toDouble(),
      durationMinutes: json['durationMinutes'] as int,
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'activityId': activityId,
        'name': name,
        'category': category,
        'status': status,
        'tokenCost': tokenCost,
        'durationMinutes': durationMinutes,
        'description': description,
        'iconUrl': iconUrl,
      };

  @override
  bool operator ==(Object other) =>
      other is DateActivityOption &&
      other.activityId == activityId &&
      other.name == name &&
      other.category == category &&
      other.status == status &&
      other.tokenCost == tokenCost &&
      other.durationMinutes == durationMinutes &&
      other.description == description &&
      other.iconUrl == iconUrl;

  @override
  int get hashCode => Object.hash(
      activityId, name, category, status, tokenCost, durationMinutes, description, iconUrl);
}

/// The city the options are for: its distance unit, currency and centre.
@immutable
class OptionsCity {
  final int cityId;

  /// `MI` or `KM`.
  final String distanceUnit;

  /// ISO 4217 code, such as `GBP`.
  final String currency;

  /// Where the map opens when the user hasn't placed a pin.
  final GeoPoint centre;

  const OptionsCity({
    required this.cityId,
    required this.distanceUnit,
    required this.currency,
    required this.centre,
  });

  factory OptionsCity.fromJson(Map<String, dynamic> json) {
    return OptionsCity(
      cityId: json['cityId'] as int,
      distanceUnit: json['distanceUnit'] as String,
      currency: json['currency'] as String,
      centre: GeoPoint.fromJson(json['centre'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'cityId': cityId,
        'distanceUnit': distanceUnit,
        'currency': currency,
        'centre': centre.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      other is OptionsCity &&
      other.cityId == cityId &&
      other.distanceUnit == distanceUnit &&
      other.currency == currency &&
      other.centre == centre;

  @override
  int get hashCode => Object.hash(cityId, distanceUnit, currency, centre);
}

/// One stop on the travel distance slider, labelled in the city's unit.
@immutable
class TravelStop {
  final String label;
  final int meters;

  const TravelStop({required this.label, required this.meters});

  factory TravelStop.fromJson(Map<String, dynamic> json) {
    return TravelStop(
      label: json['label'] as String,
      meters: json['meters'] as int,
    );
  }

  Map<String, dynamic> toJson() => {'label': label, 'meters': meters};

  @override
  bool operator ==(Object other) =>
      other is TravelStop && other.label == label && other.meters == meters;

  @override
  int get hashCode => Object.hash(label, meters);
}

/// How many cuisines a user can love or exclude.
@immutable
class OptionLimits {
  final int maxCuisinesLoved;
  final int maxCuisinesExcluded;

  const OptionLimits({required this.maxCuisinesLoved, required this.maxCuisinesExcluded});

  factory OptionLimits.fromJson(Map<String, dynamic> json) {
    return OptionLimits(
      maxCuisinesLoved: json['maxCuisinesLoved'] as int,
      maxCuisinesExcluded: json['maxCuisinesExcluded'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'maxCuisinesLoved': maxCuisinesLoved,
        'maxCuisinesExcluded': maxCuisinesExcluded,
      };

  @override
  bool operator ==(Object other) =>
      other is OptionLimits &&
      other.maxCuisinesLoved == maxCuisinesLoved &&
      other.maxCuisinesExcluded == maxCuisinesExcluded;

  @override
  int get hashCode => Object.hash(maxCuisinesLoved, maxCuisinesExcluded);
}

/// Everything the date preference screens render, from `GET /date-preferences/options`
/// (RFC-005 §5). The app hard-codes none of these lists (D-8).
@immutable
class DatePreferenceOptions {
  final List<DateActivityOption> activities;
  final List<OptionValue> cuisines;
  final List<OptionValue> dietaryOptions;
  final List<OptionValue> drinkStyles;
  final List<PriceRangeOption> priceRanges;
  final List<OptionValue> atmospheres;
  final List<OptionValue> settings;

  /// Null only if the server has no city to describe (no `cityId` and no dating city).
  final OptionsCity? city;

  final List<TravelStop> travelStops;
  final OptionLimits limits;

  DatePreferenceOptions({
    required List<DateActivityOption> activities,
    required List<OptionValue> cuisines,
    required List<OptionValue> dietaryOptions,
    required List<OptionValue> drinkStyles,
    required List<PriceRangeOption> priceRanges,
    required List<OptionValue> atmospheres,
    required List<OptionValue> settings,
    this.city,
    required List<TravelStop> travelStops,
    required this.limits,
  })  : activities = List.unmodifiable(activities),
        cuisines = List.unmodifiable(cuisines),
        dietaryOptions = List.unmodifiable(dietaryOptions),
        drinkStyles = List.unmodifiable(drinkStyles),
        priceRanges = List.unmodifiable(priceRanges),
        atmospheres = List.unmodifiable(atmospheres),
        settings = List.unmodifiable(settings),
        travelStops = List.unmodifiable(travelStops);

  factory DatePreferenceOptions.fromJson(Map<String, dynamic> json) {
    final city = json['city'] as Map<String, dynamic>?;
    return DatePreferenceOptions(
      activities: _list(json['activities'], DateActivityOption.fromJson),
      cuisines: _list(json['cuisines'], OptionValue.fromJson),
      dietaryOptions: _list(json['dietaryOptions'], OptionValue.fromJson),
      drinkStyles: _list(json['drinkStyles'], OptionValue.fromJson),
      priceRanges: _list(json['priceRanges'], PriceRangeOption.fromJson),
      atmospheres: _list(json['atmospheres'], OptionValue.fromJson),
      settings: _list(json['settings'], OptionValue.fromJson),
      city: city == null ? null : OptionsCity.fromJson(city),
      travelStops: _list(json['travelStops'], TravelStop.fromJson),
      limits: OptionLimits.fromJson(json['limits'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'activities': activities.map((a) => a.toJson()).toList(),
        'cuisines': cuisines.map((o) => o.toJson()).toList(),
        'dietaryOptions': dietaryOptions.map((o) => o.toJson()).toList(),
        'drinkStyles': drinkStyles.map((o) => o.toJson()).toList(),
        'priceRanges': priceRanges.map((o) => o.toJson()).toList(),
        'atmospheres': atmospheres.map((o) => o.toJson()).toList(),
        'settings': settings.map((o) => o.toJson()).toList(),
        'city': city?.toJson(),
        'travelStops': travelStops.map((s) => s.toJson()).toList(),
        'limits': limits.toJson(),
      };

  DatePreferenceOptions copyWith({
    List<DateActivityOption>? activities,
    List<OptionValue>? cuisines,
    List<OptionValue>? dietaryOptions,
    List<OptionValue>? drinkStyles,
    List<PriceRangeOption>? priceRanges,
    List<OptionValue>? atmospheres,
    List<OptionValue>? settings,
    OptionsCity? city,
    bool clearCity = false,
    List<TravelStop>? travelStops,
    OptionLimits? limits,
  }) {
    return DatePreferenceOptions(
      activities: activities ?? this.activities,
      cuisines: cuisines ?? this.cuisines,
      dietaryOptions: dietaryOptions ?? this.dietaryOptions,
      drinkStyles: drinkStyles ?? this.drinkStyles,
      priceRanges: priceRanges ?? this.priceRanges,
      atmospheres: atmospheres ?? this.atmospheres,
      settings: settings ?? this.settings,
      city: clearCity ? null : (city ?? this.city),
      travelStops: travelStops ?? this.travelStops,
      limits: limits ?? this.limits,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DatePreferenceOptions &&
      listEquals(other.activities, activities) &&
      listEquals(other.cuisines, cuisines) &&
      listEquals(other.dietaryOptions, dietaryOptions) &&
      listEquals(other.drinkStyles, drinkStyles) &&
      listEquals(other.priceRanges, priceRanges) &&
      listEquals(other.atmospheres, atmospheres) &&
      listEquals(other.settings, settings) &&
      other.city == city &&
      listEquals(other.travelStops, travelStops) &&
      other.limits == limits;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(activities),
        Object.hashAll(cuisines),
        Object.hashAll(dietaryOptions),
        Object.hashAll(drinkStyles),
        Object.hashAll(priceRanges),
        Object.hashAll(atmospheres),
        Object.hashAll(settings),
        city,
        Object.hashAll(travelStops),
        limits,
      );
}

List<T> _list<T>(Object? json, T Function(Map<String, dynamic>) fromJson) =>
    (json as List<dynamic>).map((e) => fromJson(e as Map<String, dynamic>)).toList();
