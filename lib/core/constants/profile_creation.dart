/// Constants for the profile creation flow
class ProfileCreationConstants {
  ProfileCreationConstants._(); // Private constructor to prevent instantiation

  // ==================== Basic Info Section ====================

  /// Total number of steps in the basic info section
  static const int basicInfoTotalSteps = 11;

  /// Basic info step numbers
  static const int basicInfoStepName = 1;
  static const int basicInfoStepLocation = 2;
  static const int basicInfoStepDatingCities = 3;
  static const int basicInfoStepGender = 4;
  static const int basicInfoStepDateOfBirth = 5;
  static const int basicInfoStepLanguages = 6;
  static const int basicInfoStepHeight = 8;
  static const int basicInfoStepEducation = 9;
  static const int basicInfoStepPhoneNumber = 10; // Same step as basicInfoStepEmail
  static const int basicInfoStepEmail = 10;
  static const int basicInfoStepTerms = 11;

  // ==================== Preferences Section ====================

  /// Total number of steps in the preferences section
  static const int preferencesTotalSteps = 7;

  /// Preference step numbers
  static const int preferencesStepDateIntentions = 1;
  static const int preferencesStepKids = 2;
  static const int preferencesStepAlcohol = 3;
  static const int preferencesStepSmoking = 4;
  static const int preferencesStepOccupation = 5;
  static const int preferencesStepRelationshipType = 6;
  static const int preferencesStepSexualOrientation = 7;
}
