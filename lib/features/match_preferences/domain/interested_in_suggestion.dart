import 'package:eros_app/features/match_preferences/domain/models/filter_values.dart';
import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';

/// Who to pre-tick for Interested in, from the user's gender and sexual orientation (RFC-007
/// §4.9). The same mapping as `suggestedGenders` in `GET /match-preferences/options` (MP-B3):
///
/// - straight: the opposite of male or female, and nothing for anyone else;
/// - gay man: men; lesbian: women; bisexual: men and women; pansexual: everyone;
/// - anything else, or no orientation yet: nothing.
///
/// Onboarding uses this because options need the user to exist. Once they do, the server's
/// suggestion is the one to use.
List<Gender> suggestedInterestedIn(Gender? gender, SexualOrientation? orientation) {
  return switch (orientation) {
    SexualOrientation.straight => switch (gender) {
        Gender.male => [Gender.female],
        Gender.female => [Gender.male],
        _ => [],
      },
    SexualOrientation.gay => gender == Gender.male ? [Gender.male] : [],
    SexualOrientation.lesbian => [Gender.female],
    SexualOrientation.bisexual => [Gender.male, Gender.female],
    SexualOrientation.pansexual => FilterValues.gender.choices,
    _ => [],
  };
}
