import 'package:flutter/foundation.dart';
import 'package:eros_app/features/match_preferences/domain/models/filter_values.dart';
import 'package:eros_app/features/profile/domain/enums/gender.dart';

/// An age range with no dealbreaker, such as the suggested default.
@immutable
class AgeRange {
  final int min;
  final int max;

  const AgeRange({required this.min, required this.max});

  factory AgeRange.fromJson(Map<String, dynamic> json) {
    return AgeRange(min: json['min'] as int, max: json['max'] as int);
  }

  Map<String, dynamic> toJson() => {'min': min, 'max': max};

  @override
  bool operator ==(Object other) => other is AgeRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);
}

/// The age slider's bounds (18 to 99, where 99 means "99+") and the user's default range.
@immutable
class AgeOptions {
  final int min;
  final int max;

  /// Own age −5 to +5, never under 18 (RFC-007 §4.1). Sent as `default`.
  final AgeRange defaultRange;

  const AgeOptions({required this.min, required this.max, required this.defaultRange});

  factory AgeOptions.fromJson(Map<String, dynamic> json) {
    return AgeOptions(
      min: json['min'] as int,
      max: json['max'] as int,
      defaultRange: AgeRange.fromJson(json['default'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {'min': min, 'max': max, 'default': defaultRange.toJson()};

  AgeOptions copyWith({int? min, int? max, AgeRange? defaultRange}) {
    return AgeOptions(
      min: min ?? this.min,
      max: max ?? this.max,
      defaultRange: defaultRange ?? this.defaultRange,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AgeOptions &&
      other.min == min &&
      other.max == max &&
      other.defaultRange == defaultRange;

  @override
  int get hashCode => Object.hash(min, max, defaultRange);
}

/// The height slider's bounds in centimetres (120 to 220; the ends mean "or less", "or more").
@immutable
class HeightOptions {
  final int minCm;
  final int maxCm;

  const HeightOptions({required this.minCm, required this.maxCm});

  factory HeightOptions.fromJson(Map<String, dynamic> json) {
    return HeightOptions(minCm: json['minCm'] as int, maxCm: json['maxCm'] as int);
  }

  Map<String, dynamic> toJson() => {'minCm': minCm, 'maxCm': maxCm};

  HeightOptions copyWith({int? minCm, int? maxCm}) {
    return HeightOptions(minCm: minCm ?? this.minCm, maxCm: maxCm ?? this.maxCm);
  }

  @override
  bool operator ==(Object other) =>
      other is HeightOptions && other.minCm == minCm && other.maxCm == maxCm;

  @override
  int get hashCode => Object.hash(minCm, maxCm);
}

/// The distance slider: its unit, its stops and where distance is measured from.
@immutable
class DistanceOptions {
  /// The first dating city's unit, passed through as the server sends it.
  final String unit;

  /// The stops, in metres, sorted: the union of the user's dating cities' travel stops.
  final List<int> stopsMeters;

  /// The district of the user's starting pin in their first dating city, such as "Clapham", or
  /// null. Never the pin itself.
  final String? from;

  DistanceOptions({required this.unit, required List<int> stopsMeters, this.from})
      : stopsMeters = List.unmodifiable(stopsMeters);

  factory DistanceOptions.fromJson(Map<String, dynamic> json) {
    return DistanceOptions(
      unit: json['unit'] as String,
      stopsMeters: (json['stopsMeters'] as List<dynamic>).cast<int>(),
      from: json['from'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {'unit': unit, 'stopsMeters': stopsMeters, 'from': from};

  DistanceOptions copyWith({
    String? unit,
    List<int>? stopsMeters,
    String? from,
    bool clearFrom = false,
  }) {
    return DistanceOptions(
      unit: unit ?? this.unit,
      stopsMeters: stopsMeters ?? this.stopsMeters,
      from: clearFrom ? null : (from ?? this.from),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DistanceOptions &&
      other.unit == unit &&
      listEquals(other.stopsMeters, stopsMeters) &&
      other.from == from;

  @override
  int get hashCode => Object.hash(unit, Object.hashAll(stopsMeters), from);
}

/// What the match preference screens can't know on their own, from
/// `GET /match-preferences/options` (RFC-007 §5).
///
/// The value lists aren't here: the screens use the profile enums (D-12).
@immutable
class MatchPreferenceOptions {
  final AgeOptions age;
  final HeightOptions height;
  final DistanceOptions distance;

  /// Who to pre-tick for Interested in, from the user's gender and orientation. Empty when there's
  /// no suggestion (RFC-007 §4.9).
  final List<Gender> suggestedGenders;

  MatchPreferenceOptions({
    required this.age,
    required this.height,
    required this.distance,
    required List<Gender> suggestedGenders,
  }) : suggestedGenders = List.unmodifiable(suggestedGenders);

  /// A suggested gender the app doesn't know is dropped and reported to [onDropped].
  factory MatchPreferenceOptions.fromJson(
    Map<String, dynamic> json, {
    OnDroppedValues? onDropped,
  }) {
    return MatchPreferenceOptions(
      age: AgeOptions.fromJson(json['age'] as Map<String, dynamic>),
      height: HeightOptions.fromJson(json['height'] as Map<String, dynamic>),
      distance: DistanceOptions.fromJson(json['distance'] as Map<String, dynamic>),
      suggestedGenders: FilterValues.gender
          .parseList(json['suggestedGenders'] as List<dynamic>, 'suggestedGenders', onDropped)!,
    );
  }

  Map<String, dynamic> toJson() => {
        'age': age.toJson(),
        'height': height.toJson(),
        'distance': distance.toJson(),
        'suggestedGenders': suggestedGenders.map(filterValueName).toList(),
      };

  MatchPreferenceOptions copyWith({
    AgeOptions? age,
    HeightOptions? height,
    DistanceOptions? distance,
    List<Gender>? suggestedGenders,
  }) {
    return MatchPreferenceOptions(
      age: age ?? this.age,
      height: height ?? this.height,
      distance: distance ?? this.distance,
      suggestedGenders: suggestedGenders ?? this.suggestedGenders,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MatchPreferenceOptions &&
      other.age == age &&
      other.height == height &&
      other.distance == distance &&
      listEquals(other.suggestedGenders, suggestedGenders);

  @override
  int get hashCode => Object.hash(age, height, distance, Object.hashAll(suggestedGenders));
}
