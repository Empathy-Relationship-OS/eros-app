import 'package:eros_app/features/date_preferences/domain/models/date_preference_options.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/domain/models/my_profile.dart';

/// Suggestions from the profile (RFC-005 §4.2, §6.2): what the Dinner and Drinks editors tick
/// the first time they open, before the user has saved any date preferences. Nothing here is
/// saved; the editor saves only when the user taps Save.

/// The dietary needs the profile's diet suggests, kept only if [dietaryOptions] lists them.
///
/// Vegetarian, vegan, halal and kosher map one to one. Any other diet, or none, suggests
/// nothing.
List<String> suggestedDietaryNeeds(MyProfile profile, List<OptionValue> dietaryOptions) {
  final need = switch (profile.diet.field) {
    Diet.vegetarian => 'VEGETARIAN',
    Diet.vegan => 'VEGAN',
    Diet.halal => 'HALAL',
    Diet.kosher => 'KOSHER',
    _ => null,
  };
  if (need == null || !dietaryOptions.any((o) => o.value == need)) return const [];
  return [need];
}

/// True when the profile's alcohol answer is "Never", which suggests "Good alcohol-free options
/// matter to me".
bool suggestsAlcoholFree(MyProfile profile) =>
    profile.alcoholConsumption.field == AlcoholConsumption.never;
