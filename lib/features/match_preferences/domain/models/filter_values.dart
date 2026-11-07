import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';

/// Called when a response holds values the app doesn't know: the filter's key and how many were
/// dropped. The values themselves are never passed on, so they can't reach a log (RFC-007 D-9).
typedef OnDroppedValues = void Function(String filter, int count);

/// The name the match preference API uses for a profile enum value: the enum's name in
/// SCREAMING_SNAKE_CASE, as in RFC-007 §5 (`nonBinary` is `NON_BINARY`).
///
/// The profile API sends display names instead ("Non-Binary"), so this is not `toBackend()`.
String filterValueName(Enum value) =>
    value.name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}').toUpperCase();

/// The values one filter can hold: the profile enum's values except `preferNotToSay`, which is an
/// unknown answer and never a filter value (RFC-007 §4.1).
/// False for `preferNotToSay`, which is an unknown answer and never a filter value.
bool isFilterValue(Enum value) => value.name != 'preferNotToSay';

class FilterChoices<T extends Enum> {
  /// The values a user can tick, in the profile enum's order.
  final List<T> choices;

  FilterChoices(List<T> values)
      : choices = List.unmodifiable(values.where(isFilterValue));

  /// The value with this API name, or null if the app doesn't know it.
  T? parse(String name) {
    for (final choice in choices) {
      if (filterValueName(choice) == name) return choice;
    }
    return null;
  }

  /// Parses a list from the API, dropping values the app doesn't know and reporting how many to
  /// [onDropped] under [filter]. Null stays null (open to all).
  List<T>? parseList(Object? json, String filter, OnDroppedValues? onDropped) {
    if (json == null) return null;
    final names = (json as List<dynamic>).cast<String>();
    final parsed = <T>[];
    for (final name in names) {
      final value = parse(name);
      if (value != null) parsed.add(value);
    }
    if (parsed.length < names.length) onDropped?.call(filter, names.length - parsed.length);
    return parsed;
  }
}

/// The choices for each value filter, from the app's profile enums (RFC-007 D-12).
abstract final class FilterValues {
  static final gender = FilterChoices<Gender>(Gender.values);
  static final ethnicity = FilterChoices<Ethnicity>(Ethnicity.values);
  static final religion = FilterChoices<Religion>(Religion.values);
  static final relationshipType = FilterChoices<RelationshipType>(RelationshipType.values);
  static final dateIntentions = FilterChoices<DateIntentions>(DateIntentions.values);
  static final kidsPreference = FilterChoices<KidsPreference>(KidsPreference.values);
  static final smokingStatus = FilterChoices<SmokingStatus>(SmokingStatus.values);
  static final alcoholConsumption = FilterChoices<AlcoholConsumption>(AlcoholConsumption.values);
}
