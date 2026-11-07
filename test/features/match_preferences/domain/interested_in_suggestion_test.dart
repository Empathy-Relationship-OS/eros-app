import 'package:eros_app/features/match_preferences/domain/interested_in_suggestion.dart';
import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('suggestedInterestedIn', () {
    const male = Gender.male;
    const female = Gender.female;
    const nonBinary = Gender.nonBinary;
    const other = Gender.other;

    // Every gender against every orientation, as MP-B3's `suggestedGenders` maps them.
    final expected = <SexualOrientation, Map<Gender, List<Gender>>>{
      SexualOrientation.straight: {male: [female], female: [male], nonBinary: [], other: []},
      SexualOrientation.gay: {male: [male], female: [female], nonBinary: [], other: []},
      SexualOrientation.lesbian: {for (final g in Gender.values) g: [female]},
      SexualOrientation.bisexual: {
        for (final g in Gender.values) g: [male, female],
      },
      SexualOrientation.pansexual: {
        for (final g in Gender.values) g: [male, female, nonBinary, other],
      },
      SexualOrientation.asexual: {for (final g in Gender.values) g: []},
      SexualOrientation.questioning: {for (final g in Gender.values) g: []},
      SexualOrientation.other: {for (final g in Gender.values) g: []},
      SexualOrientation.preferNotToSay: {for (final g in Gender.values) g: []},
    };

    for (final orientation in SexualOrientation.values) {
      for (final gender in Gender.values) {
        test('${gender.name} and ${orientation.name}', () {
          expect(suggestedInterestedIn(gender, orientation), expected[orientation]![gender]);
        });
      }
    }

    test('suggests nothing before orientation is known', () {
      for (final gender in Gender.values) {
        expect(suggestedInterestedIn(gender, null), isEmpty);
      }
    });

    test('suggests nothing for straight or gay without a gender', () {
      expect(suggestedInterestedIn(null, SexualOrientation.straight), isEmpty);
      expect(suggestedInterestedIn(null, SexualOrientation.gay), isEmpty);
    });
  });
}
