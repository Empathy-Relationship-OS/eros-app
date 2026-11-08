import 'package:eros_app/features/match_preferences/domain/models/match_filter.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preference_options.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preferences.dart';
import 'package:eros_app/features/profile/domain/enums/gender.dart';

/// Every string the summaries show.
abstract final class _Copy {
  static const openToAll = 'Open to all';
  static const everyone = 'Everyone';
  static const notSet = 'Not set yet';
  static const anywhere = 'Anywhere';
  static String upTo(String value) => 'Up to $value';
  static String orMore(String value) => '$value or more';
  static String fromNear(String distance, String district) => '$distance from near $district';

  /// Interested in reads as who the user wants to meet, so it uses plurals rather than the
  /// profile's "Female".
  static String gender(Gender gender) => switch (gender) {
        Gender.male => 'Men',
        Gender.female => 'Women',
        Gender.nonBinary => 'Non-binary people',
        Gender.other => 'Other genders',
      };
}

/// Whether [filter] is a dealbreaker in [preferences]. Interested in always is (RFC-007 D-4).
bool isMatchFilterDealbreaker(MatchFilter filter, MatchPreferences preferences) {
  return switch (filter) {
    MatchFilter.gender => preferences.gender.dealbreaker,
    MatchFilter.age => preferences.age.dealbreaker,
    MatchFilter.distance => preferences.distance.dealbreaker,
    MatchFilter.height => preferences.height.dealbreaker,
    MatchFilter.ethnicity => preferences.ethnicity.dealbreaker,
    MatchFilter.religion => preferences.religion.dealbreaker,
    MatchFilter.relationshipType => preferences.relationshipType.dealbreaker,
    MatchFilter.dateIntentions => preferences.dateIntentions.dealbreaker,
    MatchFilter.kidsPreference => preferences.kidsPreference.dealbreaker,
    MatchFilter.smokingStatus => preferences.smokingStatus.dealbreaker,
    MatchFilter.alcoholConsumption => preferences.alcoholConsumption.dealbreaker,
  };
}

/// [filter]'s value in plain words, for its row on the hub: "Women", "24–32",
/// "5 mi from near Clapham", "Open to all", "Never, Quitting".
///
/// Value filters use the labels the Edit profile screen uses (primer rule 16), in the profile
/// enum's order. Never a count of people (D-16).
String matchFilterSummary(
  MatchFilter filter,
  MatchPreferences preferences,
  MatchPreferenceOptions options,
) {
  return switch (filter) {
    MatchFilter.gender => _genderSummary(preferences.gender),
    MatchFilter.age => _ageSummary(preferences.age, options.age),
    MatchFilter.distance => _distanceSummary(preferences.distance, options.distance),
    MatchFilter.height => _heightSummary(preferences.height, options.height),
    MatchFilter.ethnicity => _valuesSummary(preferences.ethnicity, (v) => v.displayName),
    MatchFilter.religion => _valuesSummary(preferences.religion, (v) => v.displayName),
    MatchFilter.relationshipType =>
      _valuesSummary(preferences.relationshipType, (v) => v.displayName),
    MatchFilter.dateIntentions => _valuesSummary(preferences.dateIntentions, (v) => v.displayName),
    MatchFilter.kidsPreference => _valuesSummary(preferences.kidsPreference, (v) => v.displayName),
    MatchFilter.smokingStatus => _valuesSummary(preferences.smokingStatus, (v) => v.displayName),
    MatchFilter.alcoholConsumption =>
      _valuesSummary(preferences.alcoholConsumption, (v) => v.displayName),
  };
}

/// "Women, Non-binary people", or "Everyone" when every gender is ticked (saved as null). Empty
/// until the user has said who they're interested in (RFC-007 §4.9).
String _genderSummary(ValueFilter<Gender> gender) {
  final values = gender.values;
  if (values == null) return _Copy.everyone;
  if (values.isEmpty) return _Copy.notSet;
  if (values.toSet().length == Gender.values.length) return _Copy.everyone;
  return _inEnumOrder(values).map(_Copy.gender).join(', ');
}

/// "Never, Quitting", or "Open to all" for null. Every value ticked is saved as null, so this
/// doesn't need to spot it.
String _valuesSummary<T extends Enum>(ValueFilter<T> filter, String Function(T) labelOf) {
  final values = filter.values;
  if (values == null || values.isEmpty) return _Copy.openToAll;
  return _inEnumOrder(values).map(labelOf).join(', ');
}

List<T> _inEnumOrder<T extends Enum>(List<T> values) =>
    values.toSet().toList()..sort((a, b) => a.index.compareTo(b.index));

String _ageSummary(RangeFilter age, AgeOptions bounds) => formatAgeRange(age.min, age.max, bounds);

/// "24–32". The top of the slider means "99+".
String formatAgeRange(int min, int max, AgeOptions bounds) => '$min–${formatAge(max, bounds)}';

/// "32", or "99+" at the top of the slider.
String formatAge(int age, AgeOptions bounds) => age >= bounds.max ? '${bounds.max}+' : '$age';

/// "160–185 cm", "Up to 185 cm", "160 cm or more", or "Open to all". The slider's ends mean "or
/// less" and "or more" (RFC-007 §4.1). In centimetres, as the Edit profile screen shows height.
String _heightSummary(HeightFilter height, HeightOptions bounds) {
  final min = height.minCm;
  final max = height.maxCm;
  if (min == null || max == null) return _Copy.openToAll;
  final noMin = min <= bounds.minCm;
  final noMax = max >= bounds.maxCm;
  if (noMin && noMax) return _Copy.openToAll;
  if (noMin) return _Copy.upTo('$max cm');
  if (noMax) return _Copy.orMore('$min cm');
  return '$min–$max cm';
}

/// "5 mi from near Clapham", "Up to 5 mi" when the server names no district, or "Anywhere". In
/// the first dating city's unit.
String _distanceSummary(DistanceFilter distance, DistanceOptions options) {
  final meters = distance.maxMeters;
  if (meters == null) return _Copy.anywhere;
  final number = distanceInUnit(meters, options.unit);
  final value = isMiles(options.unit) ? '$number mi' : '$number km';
  final from = options.from;
  return from == null ? _Copy.upTo(value) : _Copy.fromNear(value, from);
}

/// True when [unit], the city's `DistanceUnit` from options, is `MI`. Anything else is `KM`.
bool isMiles(String unit) => unit == 'MI';

/// [meters] in [unit] (miles for `MI`, km otherwise), to one decimal place at most: "5", "2.5".
String distanceInUnit(int meters, String unit) =>
    _oneDecimal(isMiles(unit) ? meters / metersPerMile : meters / 1000);

/// Metres in a mile.
const metersPerMile = 1609.344;

String _oneDecimal(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble() ? rounded.toInt().toString() : rounded.toString();
}
