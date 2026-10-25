/// Maximum lengths of user free text, in Unicode code points (RFC-004 D-16).
///
/// Mirrors the backend's `UserTextLimits` exactly, which match the database columns. Change
/// them together.
class UserTextLimits {
  UserTextLimits._();

  /// First and last name.
  static const int name = 100;

  /// Home city.
  static const int city = 100;

  static const int occupation = 100;
  static const int bio = 300;

  /// The brain and body descriptions (RFC-004 D-11).
  static const int description = 100;

  static const int qaAnswer = 200;
  static const int cancellationReason = 150;
}
