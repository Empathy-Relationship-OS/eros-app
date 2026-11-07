import 'package:flutter/foundation.dart';
import 'package:eros_app/features/match_preferences/domain/models/filter_values.dart';
import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';

/// A filter on a list of profile values, such as religion: `{ "values": [...], "dealbreaker": ... }`.
///
/// Preferences are private, so [toString] never shows the values.
@immutable
class ValueFilter<T extends Enum> {
  /// Null means open to all. Ticking every value is saved as null too (RFC-007 §4.1). Never
  /// holds `preferNotToSay`, which the server rejects: the constructor drops it.
  final List<T>? values;

  /// True: never show anyone outside [values]. False: show people who fit first.
  final bool dealbreaker;

  ValueFilter({required List<T>? values, required this.dealbreaker})
      : values = values == null ? null : List.unmodifiable(values.where(isFilterValue));

  /// Open to all, as a preference: every value filter's default.
  const ValueFilter.openToAll()
      : values = null,
        dealbreaker = false;

  /// Parses `json`, keeping the values [choices] knows. Unknown ones are dropped and reported to
  /// [onDropped] under [filter].
  factory ValueFilter.fromJson(
    Map<String, dynamic> json,
    FilterChoices<T> choices,
    String filter, [
    OnDroppedValues? onDropped,
  ]) {
    return ValueFilter(
      values: choices.parseList(json['values'], filter, onDropped),
      dealbreaker: json['dealbreaker'] as bool,
    );
  }

  bool get isOpenToAll => values == null;

  Map<String, dynamic> toJson() => {
        'values': values?.map(filterValueName).toList(),
        'dealbreaker': dealbreaker,
      };

  ValueFilter<T> copyWith({List<T>? values, bool clearValues = false, bool? dealbreaker}) {
    return ValueFilter(
      values: clearValues ? null : (values ?? this.values),
      dealbreaker: dealbreaker ?? this.dealbreaker,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ValueFilter<T> &&
      listEquals(other.values, values) &&
      other.dealbreaker == dealbreaker;

  @override
  int get hashCode => Object.hash(values == null ? null : Object.hashAll(values!), dealbreaker);

  @override
  String toString() => 'ValueFilter<$T>(<redacted>, dealbreaker: $dealbreaker)';
}

/// The age range: `{ "min": 24, "max": 32, "dealbreaker": true }`. 99 means "99+".
@immutable
class RangeFilter {
  final int min;
  final int max;
  final bool dealbreaker;

  const RangeFilter({required this.min, required this.max, required this.dealbreaker});

  factory RangeFilter.fromJson(Map<String, dynamic> json) {
    return RangeFilter(
      min: json['min'] as int,
      max: json['max'] as int,
      dealbreaker: json['dealbreaker'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {'min': min, 'max': max, 'dealbreaker': dealbreaker};

  RangeFilter copyWith({int? min, int? max, bool? dealbreaker}) {
    return RangeFilter(
      min: min ?? this.min,
      max: max ?? this.max,
      dealbreaker: dealbreaker ?? this.dealbreaker,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RangeFilter &&
      other.min == min &&
      other.max == max &&
      other.dealbreaker == dealbreaker;

  @override
  int get hashCode => Object.hash(min, max, dealbreaker);

  @override
  String toString() => 'RangeFilter(<redacted>, dealbreaker: $dealbreaker)';
}

/// The height range in centimetres: `{ "minCm": ..., "maxCm": ..., "dealbreaker": ... }`.
///
/// Both ends are null (open to all) or both are set, from 120 to 220; the ends mean "or less" and
/// "or more".
@immutable
class HeightFilter {
  final int? minCm;
  final int? maxCm;
  final bool dealbreaker;

  const HeightFilter({required this.minCm, required this.maxCm, required this.dealbreaker});

  /// Open to all, as a preference: the default.
  const HeightFilter.openToAll()
      : minCm = null,
        maxCm = null,
        dealbreaker = false;

  factory HeightFilter.fromJson(Map<String, dynamic> json) {
    return HeightFilter(
      minCm: json['minCm'] as int?,
      maxCm: json['maxCm'] as int?,
      dealbreaker: json['dealbreaker'] as bool,
    );
  }

  bool get isOpenToAll => minCm == null && maxCm == null;

  Map<String, dynamic> toJson() => {'minCm': minCm, 'maxCm': maxCm, 'dealbreaker': dealbreaker};

  HeightFilter copyWith({int? minCm, int? maxCm, bool clearRange = false, bool? dealbreaker}) {
    return HeightFilter(
      minCm: clearRange ? null : (minCm ?? this.minCm),
      maxCm: clearRange ? null : (maxCm ?? this.maxCm),
      dealbreaker: dealbreaker ?? this.dealbreaker,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HeightFilter &&
      other.minCm == minCm &&
      other.maxCm == maxCm &&
      other.dealbreaker == dealbreaker;

  @override
  int get hashCode => Object.hash(minCm, maxCm, dealbreaker);

  @override
  String toString() => 'HeightFilter(<redacted>, dealbreaker: $dealbreaker)';
}

/// How far away people can be: `{ "maxMeters": 8047, "dealbreaker": false }`.
@immutable
class DistanceFilter {
  /// Null means anywhere in a shared dating city. Always metres, whatever unit the user saw.
  final int? maxMeters;
  final bool dealbreaker;

  const DistanceFilter({required this.maxMeters, required this.dealbreaker});

  /// Anywhere, as a preference: the default.
  const DistanceFilter.anywhere()
      : maxMeters = null,
        dealbreaker = false;

  factory DistanceFilter.fromJson(Map<String, dynamic> json) {
    return DistanceFilter(
      maxMeters: json['maxMeters'] as int?,
      dealbreaker: json['dealbreaker'] as bool,
    );
  }

  bool get isAnywhere => maxMeters == null;

  Map<String, dynamic> toJson() => {'maxMeters': maxMeters, 'dealbreaker': dealbreaker};

  DistanceFilter copyWith({int? maxMeters, bool clearMaxMeters = false, bool? dealbreaker}) {
    return DistanceFilter(
      maxMeters: clearMaxMeters ? null : (maxMeters ?? this.maxMeters),
      dealbreaker: dealbreaker ?? this.dealbreaker,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DistanceFilter && other.maxMeters == maxMeters && other.dealbreaker == dealbreaker;

  @override
  int get hashCode => Object.hash(maxMeters, dealbreaker);

  @override
  String toString() => 'DistanceFilter(<redacted>, dealbreaker: $dealbreaker)';
}

/// Who the user would like to meet, from `GET /users/me/match-preferences` (RFC-007 §5).
///
/// Keys are the profile field names. Private to the user: never shown to anyone else, and
/// [toString] shows no values.
@immutable
class MatchPreferences {
  /// False until the user has said who they're interested in. The other filters are then the
  /// defaults and [gender] has no values (RFC-007 §4.9).
  final bool isSet;

  /// Interested in. Always a dealbreaker; never open to all once set.
  final ValueFilter<Gender> gender;
  final RangeFilter age;
  final HeightFilter height;
  final DistanceFilter distance;
  final ValueFilter<Ethnicity> ethnicity;
  final ValueFilter<Religion> religion;
  final ValueFilter<RelationshipType> relationshipType;
  final ValueFilter<DateIntentions> dateIntentions;
  final ValueFilter<KidsPreference> kidsPreference;
  final ValueFilter<SmokingStatus> smokingStatus;
  final ValueFilter<AlcoholConsumption> alcoholConsumption;

  const MatchPreferences({
    required this.isSet,
    required this.gender,
    required this.age,
    required this.height,
    required this.distance,
    required this.ethnicity,
    required this.religion,
    required this.relationshipType,
    required this.dateIntentions,
    required this.kidsPreference,
    required this.smokingStatus,
    required this.alcoholConsumption,
  });

  /// Parses the `GET` and `PATCH` body. A value the app doesn't know is dropped and reported to
  /// [onDropped] with its filter's key, so a new server value can't break the screen.
  factory MatchPreferences.fromJson(Map<String, dynamic> json, {OnDroppedValues? onDropped}) {
    ValueFilter<T> values<T extends Enum>(String key, FilterChoices<T> choices) =>
        ValueFilter.fromJson(json[key] as Map<String, dynamic>, choices, key, onDropped);

    return MatchPreferences(
      isSet: json['isSet'] as bool,
      gender: values('gender', FilterValues.gender),
      age: RangeFilter.fromJson(json['age'] as Map<String, dynamic>),
      height: HeightFilter.fromJson(json['height'] as Map<String, dynamic>),
      distance: DistanceFilter.fromJson(json['distance'] as Map<String, dynamic>),
      ethnicity: values('ethnicity', FilterValues.ethnicity),
      religion: values('religion', FilterValues.religion),
      relationshipType: values('relationshipType', FilterValues.relationshipType),
      dateIntentions: values('dateIntentions', FilterValues.dateIntentions),
      kidsPreference: values('kidsPreference', FilterValues.kidsPreference),
      smokingStatus: values('smokingStatus', FilterValues.smokingStatus),
      alcoholConsumption: values('alcoholConsumption', FilterValues.alcoholConsumption),
    );
  }

  Map<String, dynamic> toJson() => {
        'isSet': isSet,
        'gender': gender.toJson(),
        'age': age.toJson(),
        'height': height.toJson(),
        'distance': distance.toJson(),
        'ethnicity': ethnicity.toJson(),
        'religion': religion.toJson(),
        'relationshipType': relationshipType.toJson(),
        'dateIntentions': dateIntentions.toJson(),
        'kidsPreference': kidsPreference.toJson(),
        'smokingStatus': smokingStatus.toJson(),
        'alcoholConsumption': alcoholConsumption.toJson(),
      };

  MatchPreferences copyWith({
    bool? isSet,
    ValueFilter<Gender>? gender,
    RangeFilter? age,
    HeightFilter? height,
    DistanceFilter? distance,
    ValueFilter<Ethnicity>? ethnicity,
    ValueFilter<Religion>? religion,
    ValueFilter<RelationshipType>? relationshipType,
    ValueFilter<DateIntentions>? dateIntentions,
    ValueFilter<KidsPreference>? kidsPreference,
    ValueFilter<SmokingStatus>? smokingStatus,
    ValueFilter<AlcoholConsumption>? alcoholConsumption,
  }) {
    return MatchPreferences(
      isSet: isSet ?? this.isSet,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      height: height ?? this.height,
      distance: distance ?? this.distance,
      ethnicity: ethnicity ?? this.ethnicity,
      religion: religion ?? this.religion,
      relationshipType: relationshipType ?? this.relationshipType,
      dateIntentions: dateIntentions ?? this.dateIntentions,
      kidsPreference: kidsPreference ?? this.kidsPreference,
      smokingStatus: smokingStatus ?? this.smokingStatus,
      alcoholConsumption: alcoholConsumption ?? this.alcoholConsumption,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MatchPreferences &&
      other.isSet == isSet &&
      other.gender == gender &&
      other.age == age &&
      other.height == height &&
      other.distance == distance &&
      other.ethnicity == ethnicity &&
      other.religion == religion &&
      other.relationshipType == relationshipType &&
      other.dateIntentions == dateIntentions &&
      other.kidsPreference == kidsPreference &&
      other.smokingStatus == smokingStatus &&
      other.alcoholConsumption == alcoholConsumption;

  @override
  int get hashCode => Object.hash(isSet, gender, age, height, distance, ethnicity, religion,
      relationshipType, dateIntentions, kidsPreference, smokingStatus, alcoholConsumption);

  @override
  String toString() => 'MatchPreferences(isSet: $isSet, <redacted>)';
}
