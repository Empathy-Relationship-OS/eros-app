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

  /// Convert to backend format (display name)
  String toBackend() => displayName;

  /// Parse from backend format (display name)
  static Gender fromBackend(String value) {
    return Gender.values.firstWhere(
      (e) => e.displayName == value,
      orElse: () => throw ArgumentError(
        'Invalid Gender value: $value. Expected one of: ${Gender.values.map((e) => e.displayName).join(", ")}',
      ),
    );
  }
}
