import 'package:eros_app/core/constants/profile_creation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the preferences steps run 1 to the total with no gap (political view removed, '
      'RFC-009 D-11)', () {
    const steps = [
      ProfileCreationConstants.preferencesStepDateIntentions,
      ProfileCreationConstants.preferencesStepKids,
      ProfileCreationConstants.preferencesStepAlcohol,
      ProfileCreationConstants.preferencesStepSmoking,
      ProfileCreationConstants.preferencesStepOccupation,
      ProfileCreationConstants.preferencesStepRelationshipType,
      ProfileCreationConstants.preferencesStepSexualOrientation,
      ProfileCreationConstants.preferencesStepBio,
      ProfileCreationConstants.preferencesStepPronouns,
      ProfileCreationConstants.preferencesStepReligion,
      ProfileCreationConstants.preferencesStepDiet,
    ];

    expect(ProfileCreationConstants.preferencesTotalSteps, 11);
    expect(steps, List.generate(11, (i) => i + 1));
  });
}
