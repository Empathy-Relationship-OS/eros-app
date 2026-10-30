import 'package:eros_app/features/date_preferences/domain/models/date_preference_options.dart';
import 'package:eros_app/features/date_preferences/domain/profile_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../profile_fixture.dart';

const _allDietaryOptions = [
  OptionValue(value: 'VEGETARIAN', displayName: 'Vegetarian'),
  OptionValue(value: 'VEGAN', displayName: 'Vegan'),
  OptionValue(value: 'HALAL', displayName: 'Halal'),
  OptionValue(value: 'KOSHER', displayName: 'Kosher'),
  OptionValue(value: 'GLUTEN_FREE', displayName: 'Gluten-free'),
  OptionValue(value: 'DAIRY_FREE', displayName: 'Dairy-free'),
];

void main() {
  group('suggestedDietaryNeeds', () {
    test('maps vegetarian, vegan, halal and kosher one to one', () {
      expect(suggestedDietaryNeeds(profileWith(diet: 'Vegetarian'), _allDietaryOptions),
          ['VEGETARIAN']);
      expect(suggestedDietaryNeeds(profileWith(diet: 'Vegan'), _allDietaryOptions), ['VEGAN']);
      expect(suggestedDietaryNeeds(profileWith(diet: 'Halal'), _allDietaryOptions), ['HALAL']);
      expect(suggestedDietaryNeeds(profileWith(diet: 'Kosher'), _allDietaryOptions), ['KOSHER']);
    });

    test('suggests nothing for any other diet, or none', () {
      for (final diet in ['Omnivore', 'Flexitarian', 'Pescatarian', 'Other', 'Prefer not to say']) {
        expect(suggestedDietaryNeeds(profileWith(diet: diet), _allDietaryOptions), isEmpty,
            reason: diet);
      }
      expect(suggestedDietaryNeeds(profileWith(diet: null), _allDietaryOptions), isEmpty);
    });

    test('suggests nothing the options don\'t list', () {
      const withoutKosher = [OptionValue(value: 'VEGAN', displayName: 'Vegan')];
      expect(suggestedDietaryNeeds(profileWith(diet: 'Kosher'), withoutKosher), isEmpty);
    });
  });

  group('suggestsAlcoholFree', () {
    test('is true only when the profile\'s alcohol answer is "Never"', () {
      expect(suggestsAlcoholFree(profileWith(alcohol: 'Never')), isTrue);
      expect(suggestsAlcoholFree(profileWith(alcohol: 'Sometimes')), isFalse);
      expect(suggestsAlcoholFree(profileWith(alcohol: 'Regularly')), isFalse);
      expect(suggestsAlcoholFree(profileWith(alcohol: 'Prefer not to say')), isFalse);
      expect(suggestsAlcoholFree(profileWith(alcohol: null)), isFalse);
    });
  });
}
