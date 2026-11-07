import 'package:flutter/foundation.dart';
import 'package:eros_app/features/match_preferences/domain/models/filter_values.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preferences.dart';
import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';

/// A `PATCH /users/me/match-preferences` body holding exactly one filter (primer rule 17).
///
/// The filter sent replaces the server's copy whole; filters left out are unchanged.
/// [toString] names the filter only, so a patch can be logged without its values.
@immutable
sealed class FilterPatch {
  const FilterPatch();

  /// The filter's key in the request body: the profile field name it reads.
  String get filter;

  /// The filter's JSON, sent under [filter].
  Map<String, dynamic> filterJson();

  Map<String, dynamic> toJson() => {filter: filterJson()};

  @override
  String toString() => '$runtimeType($filter)';
}

/// Replaces Interested in: `{ "gender": { "values": [...], "dealbreaker": true } }`.
///
/// Always a dealbreaker (RFC-007 D-4), so there is no switch to send. The first save must be this
/// one.
final class GenderPatch extends FilterPatch {
  final List<Gender> values;

  GenderPatch(List<Gender> values) : values = List.unmodifiable(values);

  @override
  String get filter => 'gender';

  @override
  Map<String, dynamic> filterJson() =>
      {'values': values.map(filterValueName).toList(), 'dealbreaker': true};
}

/// Replaces the age range: `{ "age": { "min": ..., "max": ..., "dealbreaker": ... } }`.
final class AgePatch extends FilterPatch {
  final RangeFilter age;

  const AgePatch(this.age);

  @override
  String get filter => 'age';

  @override
  Map<String, dynamic> filterJson() => age.toJson();
}

/// Replaces the height range: `{ "height": { "minCm": ..., "maxCm": ..., "dealbreaker": ... } }`.
final class HeightPatch extends FilterPatch {
  final HeightFilter height;

  const HeightPatch(this.height);

  @override
  String get filter => 'height';

  @override
  Map<String, dynamic> filterJson() => height.toJson();
}

/// Replaces the distance: `{ "distance": { "maxMeters": ..., "dealbreaker": ... } }`.
final class DistancePatch extends FilterPatch {
  final DistanceFilter distance;

  const DistancePatch(this.distance);

  @override
  String get filter => 'distance';

  @override
  Map<String, dynamic> filterJson() => distance.toJson();
}

/// Replaces one value filter: `{ "<filter>": { "values": [...] or null, "dealbreaker": ... } }`.
sealed class ValueFilterPatch<T extends Enum> extends FilterPatch {
  final ValueFilter<T> value;

  const ValueFilterPatch(this.value);

  @override
  Map<String, dynamic> filterJson() => value.toJson();
}

final class EthnicityPatch extends ValueFilterPatch<Ethnicity> {
  const EthnicityPatch(super.value);

  @override
  String get filter => 'ethnicity';
}

final class ReligionPatch extends ValueFilterPatch<Religion> {
  const ReligionPatch(super.value);

  @override
  String get filter => 'religion';
}

final class RelationshipTypePatch extends ValueFilterPatch<RelationshipType> {
  const RelationshipTypePatch(super.value);

  @override
  String get filter => 'relationshipType';
}

final class DateIntentionsPatch extends ValueFilterPatch<DateIntentions> {
  const DateIntentionsPatch(super.value);

  @override
  String get filter => 'dateIntentions';
}

final class KidsPreferencePatch extends ValueFilterPatch<KidsPreference> {
  const KidsPreferencePatch(super.value);

  @override
  String get filter => 'kidsPreference';
}

final class SmokingStatusPatch extends ValueFilterPatch<SmokingStatus> {
  const SmokingStatusPatch(super.value);

  @override
  String get filter => 'smokingStatus';
}

final class AlcoholConsumptionPatch extends ValueFilterPatch<AlcoholConsumption> {
  const AlcoholConsumptionPatch(super.value);

  @override
  String get filter => 'alcoholConsumption';
}
