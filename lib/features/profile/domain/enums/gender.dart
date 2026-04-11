/// Gender identity options
enum Gender {
  male,
  female,
  nonBinary,
  other;

  String get displayName {
    switch (this) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.nonBinary:
        return 'Non-binary';
      case Gender.other:
        return 'Other';
    }
  }

  /// Convert to backend format (SCREAMING_SNAKE_CASE)
  String toBackend() {
    switch (this) {
      case Gender.male:
        return 'MALE';
      case Gender.female:
        return 'FEMALE';
      case Gender.nonBinary:
        return 'NON_BINARY';
      case Gender.other:
        return 'OTHER';
    }
  }

  /// Parse from backend format
  static Gender fromBackend(String value) {
    switch (value) {
      case 'MALE':
        return Gender.male;
      case 'FEMALE':
        return Gender.female;
      case 'NON_BINARY':
        return Gender.nonBinary;
      case 'OTHER':
        return Gender.other;
      default:
        throw ArgumentError('Invalid Gender value: $value');
    }
  }
}
